-- ================================================
-- Qudris ShopKeeper - Storage Buckets & Policies
-- ================================================
-- Run this AFTER the initial schema migration

-- ================================================
-- CREATE STORAGE BUCKETS
-- ================================================

-- Product images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product_images',
    'product_images',
    true, -- Public read via signed URLs
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Receipt scans bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'receipts',
    'receipts',
    false, -- Private, access via signed URLs
    10485760, -- 10MB limit
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Exports bucket (CSV/JSON)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'exports',
    'exports',
    false, -- Private
    52428800, -- 50MB limit
    ARRAY['text/csv', 'application/json', 'application/zip']
)
ON CONFLICT (id) DO NOTHING;

-- ================================================
-- HELPER FUNCTIONS FOR STORAGE RLS
-- ================================================

-- Extract shop_id from storage path (format: {shop_id}/...)
CREATE OR REPLACE FUNCTION storage.get_shop_id_from_path(path TEXT)
RETURNS UUID AS $$
BEGIN
    RETURN (string_to_array(path, '/'))[1]::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has access to shop in storage path
CREATE OR REPLACE FUNCTION storage.has_shop_access(path TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    path_shop_id UUID;
BEGIN
    path_shop_id := storage.get_shop_id_from_path(path);
    
    IF path_shop_id IS NULL THEN
        RETURN false;
    END IF;
    
    RETURN EXISTS (
        SELECT 1 FROM public.staff
        WHERE shop_id = path_shop_id
        AND user_id = auth.uid()
        AND deleted_at IS NULL
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's role from storage path
CREATE OR REPLACE FUNCTION storage.get_role_from_path(path TEXT)
RETURNS public.user_role AS $$
DECLARE
    path_shop_id UUID;
    user_role public.user_role;
BEGIN
    path_shop_id := storage.get_shop_id_from_path(path);
    
    IF path_shop_id IS NULL THEN
        RETURN NULL;
    END IF;
    
    SELECT role INTO user_role
    FROM public.staff
    WHERE shop_id = path_shop_id
    AND user_id = auth.uid()
    AND deleted_at IS NULL
    AND is_active = true;
    
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================
-- STORAGE POLICIES: product_images
-- ================================================

-- Public can view product images (for web/mobile display)
CREATE POLICY "Product images are publicly viewable"
ON storage.objects FOR SELECT
USING (bucket_id = 'product_images');

-- Staff can upload product images to their shop
CREATE POLICY "Staff can upload product images"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'product_images'
    AND storage.has_shop_access(name)
);

-- Managers can update product images
CREATE POLICY "Managers can update product images"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'product_images'
    AND storage.get_role_from_path(name) IN ('owner', 'manager')
);

-- Managers can delete product images
CREATE POLICY "Managers can delete product images"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'product_images'
    AND storage.get_role_from_path(name) IN ('owner', 'manager')
);

-- ================================================
-- STORAGE POLICIES: receipts
-- ================================================

-- Staff can view receipts from their shop
CREATE POLICY "Staff can view receipts"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'receipts'
    AND storage.has_shop_access(name)
);

-- Staff can upload receipts
CREATE POLICY "Staff can upload receipts"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'receipts'
    AND storage.has_shop_access(name)
);

-- Managers can delete receipts
CREATE POLICY "Managers can delete receipts"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'receipts'
    AND storage.get_role_from_path(name) IN ('owner', 'manager')
);

-- ================================================
-- STORAGE POLICIES: exports
-- ================================================

-- Staff can view exports from their shop
CREATE POLICY "Staff can view exports"
ON storage.objects FOR SELECT
USING (
    bucket_id = 'exports'
    AND storage.has_shop_access(name)
);

-- Managers can create exports
CREATE POLICY "Managers can create exports"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'exports'
    AND storage.get_role_from_path(name) IN ('owner', 'manager')
);

-- Managers can delete exports
CREATE POLICY "Managers can delete exports"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'exports'
    AND storage.get_role_from_path(name) IN ('owner', 'manager')
);

-- ================================================
-- PATH NAMING CONVENTIONS (DOCUMENTATION)
-- ================================================

-- product_images: {shop_id}/{product_id}/{filename}
-- Example: 123e4567-e89b-12d3-a456-426614174000/prod-abc-123/image.jpg

-- receipts: {shop_id}/{year}/{month}/{order_id}/{filename}
-- Example: 123e4567-e89b-12d3-a456-426614174000/2025/10/order-xyz/receipt.pdf

-- exports: {shop_id}/exports/{timestamp}_{type}.{extension}
-- Example: 123e4567-e89b-12d3-a456-426614174000/exports/20251008_products.csv

-- ================================================
-- DONE
-- ================================================

SELECT 
    'Storage buckets and policies configured!' as message,
    COUNT(*) as bucket_count
FROM storage.buckets
WHERE name IN ('product_images', 'receipts', 'exports');

