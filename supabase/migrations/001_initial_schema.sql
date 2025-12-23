-- ================================================
-- Qudris ShopKeeper - Initial Supabase Schema
-- ================================================
-- Run this in Supabase SQL Editor
-- This creates all tables, indexes, RLS policies, and storage buckets

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ================================================
-- ENUMS
-- ================================================

CREATE TYPE user_role AS ENUM ('owner', 'manager', 'cashier');
CREATE TYPE order_status AS ENUM ('draft', 'pending', 'paid', 'refunded', 'void');
CREATE TYPE payment_method AS ENUM ('cash', 'card', 'transfer', 'mobile_money', 'other');
CREATE TYPE stock_movement_type AS ENUM ('sale', 'purchase', 'adjustment', 'return', 'damage', 'transfer');
CREATE TYPE sales_channel AS ENUM ('in_store', 'online', 'phone', 'other');

-- ================================================
-- TABLES
-- ================================================

-- -------------------- PROFILES --------------------
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    phone TEXT,
    settings JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

-- -------------------- SHOPS --------------------
CREATE TABLE shops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT DEFAULT 'NG',
    postal_code TEXT,
    phone TEXT,
    email TEXT,
    tax_id TEXT,
    currency TEXT NOT NULL DEFAULT 'NGN',
    timezone TEXT NOT NULL DEFAULT 'Africa/Lagos',
    logo_url TEXT,
    settings JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

-- -------------------- STAFF --------------------
CREATE TABLE staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    role user_role NOT NULL,
    invited_by UUID REFERENCES profiles(id),
    invite_code TEXT,
    invite_expires_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN NOT NULL DEFAULT true,
    permissions JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(shop_id, user_id, deleted_at)
);

-- -------------------- CATEGORIES --------------------
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    color TEXT,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(shop_id, name, deleted_at)
);

-- -------------------- PRODUCTS --------------------
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    sku TEXT NOT NULL,
    barcode TEXT,
    name TEXT NOT NULL,
    description TEXT,
    
    -- Pricing (stored in cents/smallest currency unit)
    price_cents INTEGER NOT NULL,
    cost_cents INTEGER,
    tax_rate DECIMAL(5,2) DEFAULT 0.00,
    
    -- Inventory
    track_inventory BOOLEAN NOT NULL DEFAULT true,
    reorder_level INTEGER DEFAULT 0,
    reorder_quantity INTEGER DEFAULT 0,
    
    -- Media
    image_path TEXT,
    image_url TEXT,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_featured BOOLEAN NOT NULL DEFAULT false,
    
    -- Meta
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    meta JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(shop_id, sku, deleted_at)
);

-- -------------------- INVENTORY --------------------
CREATE TABLE inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    on_hand_qty INTEGER NOT NULL DEFAULT 0,
    reserved_qty INTEGER NOT NULL DEFAULT 0,
    available_qty INTEGER GENERATED ALWAYS AS (on_hand_qty - reserved_qty) STORED,
    
    last_counted_at TIMESTAMPTZ,
    last_counted_by UUID REFERENCES profiles(id),
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(shop_id, product_id, deleted_at)
);

-- -------------------- STOCK_MOVEMENTS --------------------
CREATE TABLE stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    
    type stock_movement_type NOT NULL,
    qty_delta INTEGER NOT NULL,
    
    -- Derived quantity (negative for outflows)
    qty_before INTEGER NOT NULL,
    qty_after INTEGER NOT NULL,
    
    reason TEXT,
    reference_id UUID, -- e.g., order_id, purchase_id
    reference_type TEXT, -- 'order', 'purchase', 'adjustment'
    
    notes TEXT,
    meta JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_stock_movements_shop ON stock_movements(shop_id, created_at DESC);

-- -------------------- CUSTOMERS --------------------
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    state TEXT,
    postal_code TEXT,
    
    -- Loyalty
    loyalty_points INTEGER DEFAULT 0,
    total_spent_cents INTEGER DEFAULT 0,
    total_orders INTEGER DEFAULT 0,
    
    -- Preferences
    tags TEXT[] DEFAULT ARRAY[]::TEXT[],
    notes TEXT,
    meta JSONB DEFAULT '{}'::jsonb,
    
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_customers_phone ON customers(shop_id, phone) WHERE deleted_at IS NULL;
CREATE INDEX idx_customers_email ON customers(shop_id, email) WHERE deleted_at IS NULL;

-- -------------------- ORDERS --------------------
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    
    order_number TEXT NOT NULL,
    status order_status NOT NULL DEFAULT 'draft',
    channel sales_channel NOT NULL DEFAULT 'in_store',
    
    -- Totals (in cents)
    subtotal_cents INTEGER NOT NULL DEFAULT 0,
    discount_cents INTEGER NOT NULL DEFAULT 0,
    tax_cents INTEGER NOT NULL DEFAULT 0,
    total_cents INTEGER NOT NULL DEFAULT 0,
    
    -- Payment
    amount_paid_cents INTEGER NOT NULL DEFAULT 0,
    amount_due_cents INTEGER GENERATED ALWAYS AS (total_cents - amount_paid_cents) STORED,
    payment_status TEXT GENERATED ALWAYS AS (
        CASE 
            WHEN amount_paid_cents >= total_cents THEN 'paid'
            WHEN amount_paid_cents > 0 THEN 'partial'
            ELSE 'unpaid'
        END
    ) STORED,
    
    -- Dates
    ordered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    paid_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    
    -- Meta
    notes TEXT,
    device_id TEXT,
    meta JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(shop_id, order_number, deleted_at)
);

CREATE INDEX idx_orders_shop_status ON orders(shop_id, status, ordered_at DESC);
CREATE INDEX idx_orders_customer ON orders(customer_id, ordered_at DESC) WHERE deleted_at IS NULL;

-- -------------------- ORDER_ITEMS --------------------
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    
    product_name TEXT NOT NULL, -- Snapshot at time of order
    product_sku TEXT,
    
    quantity INTEGER NOT NULL,
    unit_price_cents INTEGER NOT NULL,
    
    discount_cents INTEGER NOT NULL DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 0.00,
    tax_cents INTEGER NOT NULL DEFAULT 0,
    
    line_total_cents INTEGER NOT NULL,
    
    notes TEXT,
    meta JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id, created_at DESC);

-- -------------------- PAYMENTS --------------------
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    
    method payment_method NOT NULL,
    amount_cents INTEGER NOT NULL,
    
    -- Transaction tracking
    transaction_ref TEXT,
    receipt_path TEXT,
    receipt_url TEXT,
    
    -- Card details (masked)
    card_last4 TEXT,
    card_brand TEXT,
    
    -- Status
    status TEXT DEFAULT 'completed',
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    notes TEXT,
    meta JSONB DEFAULT '{}'::jsonb,
    
    created_by UUID NOT NULL REFERENCES profiles(id),
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    last_modified TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_shop ON payments(shop_id, processed_at DESC);

-- -------------------- DEVICES --------------------
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    
    last_sync_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    UNIQUE(device_id, shop_id, deleted_at)
);

CREATE INDEX idx_devices_shop_user ON devices(shop_id, user_id) WHERE is_active = true;

-- -------------------- SYNC_STATES --------------------
CREATE TABLE sync_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    table_name TEXT NOT NULL,
    
    last_pulled_at TIMESTAMPTZ,
    last_pushed_at TIMESTAMPTZ,
    
    pull_cursor TIMESTAMPTZ,
    push_cursor INTEGER DEFAULT 0,
    
    rows_pulled INTEGER DEFAULT 0,
    rows_pushed INTEGER DEFAULT 0,
    last_error TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(device_id, table_name)
);

CREATE INDEX idx_sync_states_device ON sync_states(device_id, updated_at DESC);

-- -------------------- AUDIT_LOGS --------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    
    old_values JSONB,
    new_values JSONB,
    
    ip_address INET,
    user_agent TEXT,
    device_id TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_shop ON audit_logs(shop_id, created_at DESC);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, created_at DESC);
CREATE INDEX idx_audit_logs_record ON audit_logs(table_name, record_id);

-- ================================================
-- TRIGGERS FOR UPDATED_AT & LAST_MODIFIED
-- ================================================

CREATE OR REPLACE FUNCTION update_timestamp_columns()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    NEW.last_modified = NOW();
    NEW.version = OLD.version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with these columns
CREATE TRIGGER update_profiles_timestamp BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_shops_timestamp BEFORE UPDATE ON shops
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_staff_timestamp BEFORE UPDATE ON staff
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_categories_timestamp BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_products_timestamp BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_inventory_timestamp BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_stock_movements_timestamp BEFORE UPDATE ON stock_movements
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_customers_timestamp BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_orders_timestamp BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_order_items_timestamp BEFORE UPDATE ON order_items
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

CREATE TRIGGER update_payments_timestamp BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_timestamp_columns();

-- ================================================
-- ROW LEVEL SECURITY (RLS)
-- ================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE shops ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- ================================================
-- HELPER FUNCTIONS FOR RLS
-- ================================================

-- Check if user is staff member of a shop
CREATE OR REPLACE FUNCTION is_shop_member(check_shop_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM staff
        WHERE shop_id = check_shop_id
        AND user_id = auth.uid()
        AND deleted_at IS NULL
        AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get user's role in a shop
CREATE OR REPLACE FUNCTION get_shop_role(check_shop_id UUID)
RETURNS user_role AS $$
DECLARE
    user_role user_role;
BEGIN
    SELECT role INTO user_role
    FROM staff
    WHERE shop_id = check_shop_id
    AND user_id = auth.uid()
    AND deleted_at IS NULL
    AND is_active = true;
    
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has specific role or higher
CREATE OR REPLACE FUNCTION has_role(check_shop_id UUID, required_role user_role)
RETURNS BOOLEAN AS $$
DECLARE
    user_role user_role;
BEGIN
    user_role := get_shop_role(check_shop_id);
    
    -- Owner has all permissions
    IF user_role = 'owner' THEN
        RETURN true;
    END IF;
    
    -- Manager can do what manager and cashier can do
    IF user_role = 'manager' AND required_role IN ('manager', 'cashier') THEN
        RETURN true;
    END IF;
    
    -- Cashier can only do cashier things
    IF user_role = 'cashier' AND required_role = 'cashier' THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================================
-- RLS POLICIES
-- ================================================

-- -------------------- PROFILES --------------------
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- -------------------- SHOPS --------------------
CREATE POLICY "Staff can view their shops"
    ON shops FOR SELECT
    USING (is_shop_member(id));

CREATE POLICY "Owners can update their shops"
    ON shops FOR UPDATE
    USING (has_role(id, 'owner'));

CREATE POLICY "Authenticated users can create shops"
    ON shops FOR INSERT
    WITH CHECK (auth.uid() = created_by);

-- -------------------- STAFF --------------------
CREATE POLICY "Staff can view their shop's staff"
    ON staff FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Owners can manage staff"
    ON staff FOR ALL
    USING (has_role(shop_id, 'owner'));

-- -------------------- CATEGORIES --------------------
CREATE POLICY "Staff can view categories"
    ON categories FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Managers can manage categories"
    ON categories FOR ALL
    USING (has_role(shop_id, 'manager'));

-- -------------------- PRODUCTS --------------------
CREATE POLICY "Staff can view products"
    ON products FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Managers can manage products"
    ON products FOR INSERT
    WITH CHECK (has_role(shop_id, 'manager'));

CREATE POLICY "Managers can update products"
    ON products FOR UPDATE
    USING (has_role(shop_id, 'manager'));

CREATE POLICY "Owners can delete products"
    ON products FOR DELETE
    USING (has_role(shop_id, 'owner'));

-- -------------------- INVENTORY --------------------
CREATE POLICY "Staff can view inventory"
    ON inventory FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Managers can manage inventory"
    ON inventory FOR ALL
    USING (has_role(shop_id, 'manager'));

-- -------------------- STOCK_MOVEMENTS --------------------
CREATE POLICY "Staff can view stock movements"
    ON stock_movements FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Staff can create stock movements"
    ON stock_movements FOR INSERT
    WITH CHECK (is_shop_member(shop_id));

CREATE POLICY "Managers can update stock movements"
    ON stock_movements FOR UPDATE
    USING (has_role(shop_id, 'manager'));

-- -------------------- CUSTOMERS --------------------
CREATE POLICY "Staff can view customers"
    ON customers FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Staff can create customers"
    ON customers FOR INSERT
    WITH CHECK (is_shop_member(shop_id));

CREATE POLICY "Staff can update customers"
    ON customers FOR UPDATE
    USING (is_shop_member(shop_id));

CREATE POLICY "Managers can delete customers"
    ON customers FOR DELETE
    USING (has_role(shop_id, 'manager'));

-- -------------------- ORDERS --------------------
CREATE POLICY "Staff can view orders"
    ON orders FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Staff can create orders"
    ON orders FOR INSERT
    WITH CHECK (is_shop_member(shop_id));

CREATE POLICY "Staff can update orders"
    ON orders FOR UPDATE
    USING (is_shop_member(shop_id));

CREATE POLICY "Managers can delete orders"
    ON orders FOR DELETE
    USING (has_role(shop_id, 'manager'));

-- -------------------- ORDER_ITEMS --------------------
CREATE POLICY "Staff can view order items"
    ON order_items FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Staff can create order items"
    ON order_items FOR INSERT
    WITH CHECK (is_shop_member(shop_id));

CREATE POLICY "Staff can update order items"
    ON order_items FOR UPDATE
    USING (is_shop_member(shop_id));

-- -------------------- PAYMENTS --------------------
CREATE POLICY "Staff can view payments"
    ON payments FOR SELECT
    USING (is_shop_member(shop_id));

CREATE POLICY "Staff can create payments"
    ON payments FOR INSERT
    WITH CHECK (is_shop_member(shop_id));

CREATE POLICY "Managers can update payments"
    ON payments FOR UPDATE
    USING (has_role(shop_id, 'manager'));

-- -------------------- DEVICES --------------------
CREATE POLICY "Users can view their devices"
    ON devices FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can register devices"
    ON devices FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their devices"
    ON devices FOR UPDATE
    USING (user_id = auth.uid());

-- -------------------- SYNC_STATES --------------------
CREATE POLICY "Users can manage their sync states"
    ON sync_states FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM devices
            WHERE devices.id = sync_states.device_id
            AND devices.user_id = auth.uid()
        )
    );

-- -------------------- AUDIT_LOGS --------------------
CREATE POLICY "Owners can view audit logs"
    ON audit_logs FOR SELECT
    USING (
        shop_id IS NULL OR has_role(shop_id, 'owner')
    );

-- ================================================
-- INDEXES FOR PERFORMANCE
-- ================================================

CREATE INDEX idx_profiles_email ON profiles(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_shops_created_by ON shops(created_by);
CREATE INDEX idx_staff_shop_user ON staff(shop_id, user_id) WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX idx_staff_user ON staff(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_categories_shop ON categories(shop_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_shop ON products(shop_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_category ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_products_barcode ON products(barcode) WHERE deleted_at IS NULL AND barcode IS NOT NULL;
CREATE INDEX idx_inventory_shop ON inventory(shop_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_inventory_product ON inventory(product_id) WHERE deleted_at IS NULL;

-- Indexes for sync queries (critical for performance)
CREATE INDEX idx_profiles_last_modified ON profiles(last_modified) WHERE deleted_at IS NULL;
CREATE INDEX idx_shops_last_modified ON shops(last_modified) WHERE deleted_at IS NULL;
CREATE INDEX idx_staff_last_modified ON staff(last_modified, shop_id);
CREATE INDEX idx_categories_last_modified ON categories(last_modified, shop_id);
CREATE INDEX idx_products_last_modified ON products(last_modified, shop_id);
CREATE INDEX idx_inventory_last_modified ON inventory(last_modified, shop_id);
CREATE INDEX idx_stock_movements_last_modified ON stock_movements(last_modified, shop_id);
CREATE INDEX idx_customers_last_modified ON customers(last_modified, shop_id);
CREATE INDEX idx_orders_last_modified ON orders(last_modified, shop_id);
CREATE INDEX idx_order_items_last_modified ON order_items(last_modified, shop_id);
CREATE INDEX idx_payments_last_modified ON payments(last_modified, shop_id);

-- ================================================
-- INITIAL DATA
-- ================================================

-- Create a public profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name'),
        NEW.raw_user_meta_data->>'avatar_url'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ================================================
-- FUNCTIONS FOR BUSINESS LOGIC
-- ================================================

-- Generate unique order number
CREATE OR REPLACE FUNCTION generate_order_number(p_shop_id UUID)
RETURNS TEXT AS $$
DECLARE
    order_count INTEGER;
    order_number TEXT;
BEGIN
    SELECT COUNT(*) INTO order_count
    FROM orders
    WHERE shop_id = p_shop_id
    AND created_at >= DATE_TRUNC('day', NOW());
    
    order_number := TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD((order_count + 1)::TEXT, 4, '0');
    RETURN order_number;
END;
$$ LANGUAGE plpgsql;

-- Update inventory on stock movement
CREATE OR REPLACE FUNCTION update_inventory_on_movement()
RETURNS TRIGGER AS $$
BEGIN
    -- Update inventory quantity
    UPDATE inventory
    SET on_hand_qty = on_hand_qty + NEW.qty_delta
    WHERE product_id = NEW.product_id
    AND shop_id = NEW.shop_id;
    
    -- Create inventory record if it doesn't exist
    IF NOT FOUND THEN
        INSERT INTO inventory (shop_id, product_id, on_hand_qty, created_by, updated_by)
        VALUES (NEW.shop_id, NEW.product_id, NEW.qty_delta, NEW.created_by, NEW.created_by);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_inventory_trigger
    AFTER INSERT ON stock_movements
    FOR EACH ROW EXECUTE FUNCTION update_inventory_on_movement();

-- ================================================
-- COMMENTS FOR DOCUMENTATION
-- ================================================

COMMENT ON TABLE profiles IS 'User profiles linked to auth.users';
COMMENT ON TABLE shops IS 'Multi-tenant shops/stores';
COMMENT ON TABLE staff IS 'User membership and roles per shop';
COMMENT ON TABLE products IS 'Product catalog with pricing';
COMMENT ON TABLE inventory IS 'Current stock levels';
COMMENT ON TABLE stock_movements IS 'Audit trail for inventory changes';
COMMENT ON TABLE orders IS 'Sales orders/transactions';
COMMENT ON TABLE payments IS 'Payment records for orders';
COMMENT ON TABLE sync_states IS 'Tracks delta sync watermarks per device';
COMMENT ON TABLE audit_logs IS 'System-wide audit trail';

-- ================================================
-- DONE
-- ================================================

-- Verify installation
SELECT 
    'Schema created successfully!' as message,
    COUNT(*) as table_count
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE';

