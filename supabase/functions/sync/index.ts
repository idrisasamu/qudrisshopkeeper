// ================================================
// Qudris ShopKeeper - Sync Edge Function
// ================================================
// Handles bi-directional sync between mobile app and Supabase
// Deploy: supabase functions deploy sync

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface SyncRequest {
  device_id: string;
  shop_id: string;
  tables: TableSyncRequest[];
}

interface TableSyncRequest {
  table_name: string;
  last_pulled_at?: string; // ISO timestamp
  push_data?: any[]; // Rows to push to server
}

interface SyncResponse {
  success: boolean;
  results: TableSyncResult[];
  errors?: string[];
}

interface TableSyncResult {
  table_name: string;
  pulled_count: number;
  pushed_count: number;
  conflicts_count: number;
  pulled_data: any[];
  deleted_data: any[]; // Soft-deleted rows (tombstones)
  conflicts?: ConflictResolution[];
}

interface ConflictResolution {
  client_id: string;
  server_id: string;
  resolution: "server_wins" | "client_wins";
  server_version: number;
  client_version: number;
}

const SYNCABLE_TABLES = [
  "products",
  "categories",
  "inventory",
  "stock_movements",
  "customers",
  "orders",
  "order_items",
  "payments",
  "staff",
];

const BATCH_SIZE = 500;

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
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse request
    const syncRequest: SyncRequest = await req.json();
    const { device_id, shop_id, tables } = syncRequest;

    // Validate request
    if (!device_id || !shop_id || !tables || tables.length === 0) {
      return new Response(
        JSON.stringify({ error: "Invalid request: device_id, shop_id, and tables required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify user has access to shop
    const { data: staffMembership, error: staffError } = await supabaseClient
      .from("staff")
      .select("role")
      .eq("shop_id", shop_id)
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .eq("is_active", true)
      .single();

    if (staffError || !staffMembership) {
      return new Response(
        JSON.stringify({ error: "User is not a member of this shop" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Register/update device
    await supabaseClient
      .from("devices")
      .upsert({
        device_id,
        shop_id,
        user_id: user.id,
        last_sync_at: new Date().toISOString(),
        is_active: true,
      }, {
        onConflict: "device_id,shop_id",
        ignoreDuplicates: false,
      });

    // Process each table
    const results: TableSyncResult[] = [];
    const errors: string[] = [];

    for (const tableRequest of tables) {
      const { table_name, last_pulled_at, push_data } = tableRequest;

      // Validate table is syncable
      if (!SYNCABLE_TABLES.includes(table_name)) {
        errors.push(`Table ${table_name} is not syncable`);
        continue;
      }

      try {
        const result = await syncTable(
          supabaseClient,
          user.id,
          shop_id,
          table_name,
          last_pulled_at,
          push_data || [],
          staffMembership.role
        );
        results.push(result);
      } catch (error) {
        console.error(`Error syncing table ${table_name}:`, error);
        errors.push(`Error syncing ${table_name}: ${error.message}`);
      }
    }

    const response: SyncResponse = {
      success: errors.length === 0,
      results,
      errors: errors.length > 0 ? errors : undefined,
    };

    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

async function syncTable(
  client: any,
  userId: string,
  shopId: string,
  tableName: string,
  lastPulledAt: string | undefined,
  pushData: any[],
  userRole: string
): Promise<TableSyncResult> {
  const result: TableSyncResult = {
    table_name: tableName,
    pulled_count: 0,
    pushed_count: 0,
    conflicts_count: 0,
    pulled_data: [],
    deleted_data: [],
    conflicts: [],
  };

  // ================================================
  // PUSH: Client → Server
  // ================================================
  if (pushData && pushData.length > 0) {
    for (const row of pushData) {
      try {
        // Check if row exists on server
        const { data: existingRow } = await client
          .from(tableName)
          .select("id, version, updated_at")
          .eq("id", row.id)
          .eq("shop_id", shopId)
          .single();

        if (existingRow) {
          // Row exists - check for conflict
          const serverUpdatedAt = new Date(existingRow.updated_at).getTime();
          const clientUpdatedAt = new Date(row.updated_at).getTime();

          if (serverUpdatedAt > clientUpdatedAt) {
            // Server is newer - conflict (server wins)
            result.conflicts_count++;
            result.conflicts!.push({
              client_id: row.id,
              server_id: existingRow.id,
              resolution: "server_wins",
              server_version: existingRow.version,
              client_version: row.version || 1,
            });

            // Log conflict
            await logAudit(client, shopId, userId, "conflict", tableName, row.id, row, existingRow);

            // Don't update - return server version to client
            continue;
          } else {
            // Client is newer or same - accept client update
            const { error: updateError } = await client
              .from(tableName)
              .update({
                ...row,
                updated_by: userId,
                updated_at: new Date().toISOString(),
                last_modified: new Date().toISOString(),
              })
              .eq("id", row.id)
              .eq("shop_id", shopId);

            if (updateError) {
              throw updateError;
            }

            result.pushed_count++;
          }
        } else {
          // Row doesn't exist - insert
          const { error: insertError } = await client
            .from(tableName)
            .insert({
              ...row,
              shop_id: shopId,
              created_by: userId,
              updated_by: userId,
              created_at: row.created_at || new Date().toISOString(),
              updated_at: new Date().toISOString(),
              last_modified: new Date().toISOString(),
            });

          if (insertError) {
            throw insertError;
          }

          result.pushed_count++;
        }
      } catch (error) {
        console.error(`Error pushing row ${row.id} to ${tableName}:`, error);
        // Continue with next row
      }
    }
  }

  // ================================================
  // PULL: Server → Client
  // ================================================
  let query = client
    .from(tableName)
    .select("*")
    .eq("shop_id", shopId)
    .order("last_modified", { ascending: true })
    .limit(BATCH_SIZE);

  // Delta sync: only pull changes since last sync
  if (lastPulledAt) {
    query = query.gt("last_modified", lastPulledAt);
  }

  // Fetch changed rows (not deleted)
  const { data: changedRows, error: pullError } = await query.is("deleted_at", null);

  if (pullError) {
    throw pullError;
  }

  result.pulled_data = changedRows || [];
  result.pulled_count = result.pulled_data.length;

  // Fetch deleted rows (tombstones)
  let deletedQuery = client
    .from(tableName)
    .select("id, deleted_at, last_modified")
    .eq("shop_id", shopId)
    .not("deleted_at", "is", null)
    .order("last_modified", { ascending: true })
    .limit(BATCH_SIZE);

  if (lastPulledAt) {
    deletedQuery = deletedQuery.gt("last_modified", lastPulledAt);
  }

  const { data: deletedRows, error: deletedError } = await deletedQuery;

  if (!deletedError && deletedRows) {
    result.deleted_data = deletedRows;
  }

  return result;
}

async function logAudit(
  client: any,
  shopId: string,
  userId: string,
  action: string,
  tableName: string,
  recordId: string,
  oldValues: any,
  newValues: any
) {
  try {
    await client.from("audit_logs").insert({
      shop_id: shopId,
      user_id: userId,
      action,
      table_name: tableName,
      record_id: recordId,
      old_values: oldValues,
      new_values: newValues,
    });
  } catch (error) {
    console.error("Error logging audit:", error);
    // Don't throw - audit logging shouldn't break sync
  }
}

