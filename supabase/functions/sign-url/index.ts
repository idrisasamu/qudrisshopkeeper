// ================================================
// Qudris ShopKeeper - Signed URL Edge Function
// ================================================
// Generates time-limited signed URLs for Storage access
// Deploy: supabase functions deploy sign-url

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface SignUrlRequest {
  bucket: string;
  path: string;
  expiresIn?: number; // seconds, default 3600 (1 hour)
  operation?: "read" | "upload"; // default "read"
}

interface SignUrlResponse {
  success: boolean;
  signedUrl?: string;
  expiresAt?: string;
  error?: string;
}

const ALLOWED_BUCKETS = ["product_images", "receipts", "exports"];
const MAX_EXPIRY = 604800; // 7 days in seconds
const DEFAULT_EXPIRY = 3600; // 1 hour

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: {
          headers: { Authorization: req.headers.get("Authorization")! },
        },
      }
    );

    // Verify authentication
    const {
      data: { user },
      error: authError,
    } = await supabaseClient.auth.getUser();

    if (authError || !user) {
      return new Response(
        JSON.stringify({ success: false, error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request
    const signRequest: SignUrlRequest = await req.json();
    const { bucket, path, expiresIn = DEFAULT_EXPIRY, operation = "read" } = signRequest;

    // Validate request
    if (!bucket || !path) {
      return new Response(
        JSON.stringify({ success: false, error: "bucket and path are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate bucket
    if (!ALLOWED_BUCKETS.includes(bucket)) {
      return new Response(
        JSON.stringify({ success: false, error: `Bucket ${bucket} is not allowed` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Validate expiry
    const expiry = Math.min(expiresIn, MAX_EXPIRY);

    // Extract shop_id from path (format: {shop_id}/...)
    const shopId = extractShopIdFromPath(path);
    if (!shopId) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid path format - must start with shop_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify user has access to shop
    const { data: staffMembership, error: staffError } = await supabaseClient
      .from("staff")
      .select("role")
      .eq("shop_id", shopId)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .eq("is_active", true)
      .single();

    if (staffError || !staffMembership) {
      return new Response(
        JSON.stringify({ success: false, error: "User does not have access to this shop" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check role permissions for uploads
    if (operation === "upload") {
      // Only managers and owners can upload to exports bucket
      if (bucket === "exports" && !["owner", "manager"].includes(staffMembership.role)) {
        return new Response(
          JSON.stringify({ success: false, error: "Only managers and owners can create exports" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Generate signed URL
    let signedUrl: string;
    
    if (operation === "upload") {
      // Create signed upload URL
      const { data, error } = await supabaseClient.storage
        .from(bucket)
        .createSignedUploadUrl(path);

      if (error) {
        throw error;
      }

      signedUrl = data.signedUrl;
    } else {
      // Create signed download URL
      const { data, error } = await supabaseClient.storage
        .from(bucket)
        .createSignedUrl(path, expiry);

      if (error) {
        throw error;
      }

      signedUrl = data.signedUrl;
    }

    // Calculate expiry timestamp
    const expiresAt = new Date(Date.now() + expiry * 1000).toISOString();

    // Log access for audit
    await supabaseClient.from("audit_logs").insert({
      shop_id: shopId,
      user_id: user.id,
      action: `storage_${operation}`,
      table_name: "storage",
      record_id: path,
      new_values: { bucket, path, operation, expiresIn: expiry },
    });

    const response: SignUrlResponse = {
      success: true,
      signedUrl,
      expiresAt,
    };

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Sign URL error:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function extractShopIdFromPath(path: string): string | null {
  try {
    const parts = path.split("/");
    if (parts.length < 1) {
      return null;
    }
    
    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(parts[0])) {
      return null;
    }
    
    return parts[0];
  } catch {
    return null;
  }
}

