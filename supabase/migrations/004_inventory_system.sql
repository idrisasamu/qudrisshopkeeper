-- =====================================================
-- INVENTORY SYSTEM - Products, Inventory, Stock Movements
-- =====================================================
-- This migration creates a complete inventory management system
-- with proper RLS policies for multi-tenant access control.

-- =====================================================
-- TABLES
-- =====================================================

-- Products table (catalog items)
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  sku text,
  name text not null,
  price_cents integer not null default 0,
  cost_cents integer,
  tax_rate numeric(6,3) default 0.000,
  barcode text,
  image_path text,
  is_active boolean not null default true,
  reorder_level integer default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_modified timestamptz not null default now(),
  deleted_at timestamptz,
  version int not null default 1,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  unique (shop_id, sku)
);

create index if not exists idx_products_shop on public.products(shop_id);
create index if not exists idx_products_lastmod on public.products(last_modified);
create index if not exists idx_products_barcode on public.products(barcode) where barcode is not null;
create index if not exists idx_products_active on public.products(is_active, shop_id);

comment on table public.products is 'Product catalog items for each shop';
comment on column public.products.price_cents is 'Selling price in cents';
comment on column public.products.cost_cents is 'Cost price in cents';
comment on column public.products.reorder_level is 'Minimum quantity before reorder alert';

-- Inventory table (stock levels per product)
create table if not exists public.inventory (
  product_id uuid primary key references public.products(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  on_hand_qty integer not null default 0,
  on_reserved_qty integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_modified timestamptz not null default now(),
  deleted_at timestamptz,
  version int not null default 1,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id),
  constraint inventory_qty_non_negative check (on_hand_qty >= 0 and on_reserved_qty >= 0)
);

create index if not exists idx_inventory_shop on public.inventory(shop_id);
create index if not exists idx_inventory_low_stock on public.inventory(shop_id, on_hand_qty);

comment on table public.inventory is 'Current inventory levels for products';
comment on column public.inventory.on_hand_qty is 'Available quantity in stock';
comment on column public.inventory.on_reserved_qty is 'Quantity reserved for pending orders';

-- Stock movements table (audit trail of all inventory changes)
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  type text not null check (type in ('sale','purchase','adjustment','return')),
  qty_delta integer not null,
  reason text,
  linked_order_id uuid references public.orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_modified timestamptz not null default now(),
  deleted_at timestamptz,
  version int not null default 1,
  created_by uuid references auth.users(id),
  updated_by uuid references auth.users(id)
);

create index if not exists idx_stock_movements_shop on public.stock_movements(shop_id);
create index if not exists idx_stock_movements_product on public.stock_movements(product_id);
create index if not exists idx_stock_movements_lastmod on public.stock_movements(last_modified);
create index if not exists idx_stock_movements_created on public.stock_movements(created_at desc);

comment on table public.stock_movements is 'Audit trail of all inventory changes';
comment on column public.stock_movements.type is 'Type of movement: sale, purchase, adjustment, return';
comment on column public.stock_movements.qty_delta is 'Quantity change (positive for additions, negative for subtractions)';

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Touch trigger (updates version and timestamps)
create or replace function public.tg_touch_row()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.last_modified := now();
  new.version := coalesce(old.version, 0) + 1;
  new.updated_by := auth.uid();
  return new;
end; $$;

drop trigger if exists tg_touch_products on public.products;
create trigger tg_touch_products before update on public.products
for each row execute function public.tg_touch_row();

drop trigger if exists tg_touch_inventory on public.inventory;
create trigger tg_touch_inventory before update on public.inventory
for each row execute function public.tg_touch_row();

drop trigger if exists tg_touch_stock_movements on public.stock_movements;
create trigger tg_touch_stock_movements before update on public.stock_movements
for each row execute function public.tg_touch_row();

-- =====================================================
-- RLS HELPER FUNCTIONS
-- =====================================================

-- Check if user is a member of the shop (any role)
create or replace function public.is_member(p_shop_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare 
  uid uuid := auth.uid(); 
begin
  if uid is null then return false; end if;
  return exists (
    select 1 from public.staff s 
    where s.shop_id = p_shop_id 
      and s.user_id = uid 
      and coalesce(s.is_active, true)
  );
end; $$;

-- Check if user has specific role(s) in the shop
create or replace function public.has_role(p_shop_id uuid, p_roles text[])
returns boolean language plpgsql security definer set search_path = public as $$
declare 
  uid uuid := auth.uid(); 
begin
  if uid is null then return false; end if;
  return exists (
    select 1 from public.staff s 
    where s.shop_id = p_shop_id 
      and s.user_id = uid 
      and s.role::text = any(p_roles) 
      and coalesce(s.is_active, true)
  );
end; $$;

grant execute on function public.is_member(uuid) to authenticated;
grant execute on function public.has_role(uuid, text[]) to authenticated;

-- =====================================================
-- RLS POLICIES
-- =====================================================

-- Enable RLS
alter table public.products enable row level security;
alter table public.inventory enable row level security;
alter table public.stock_movements enable row level security;

-- PRODUCTS - All members can read, only owner/manager can write
drop policy if exists "products read by members" on public.products;
create policy "products read by members" on public.products
for select to authenticated 
using (public.is_member(shop_id));

drop policy if exists "products write by owner_manager" on public.products;
create policy "products write by owner_manager" on public.products
for all to authenticated
using (public.has_role(shop_id, array['owner','manager']::text[]))
with check (public.has_role(shop_id, array['owner','manager']::text[]));

-- INVENTORY - All members can read, only owner/manager can write
drop policy if exists "inventory read by members" on public.inventory;
create policy "inventory read by members" on public.inventory
for select to authenticated 
using (public.is_member(shop_id));

drop policy if exists "inventory write by owner_manager" on public.inventory;
create policy "inventory write by owner_manager" on public.inventory
for all to authenticated
using (public.has_role(shop_id, array['owner','manager']::text[]))
with check (public.has_role(shop_id, array['owner','manager']::text[]));

-- STOCK MOVEMENTS - All members can read, only owner/manager can write
drop policy if exists "movements read by members" on public.stock_movements;
create policy "movements read by members" on public.stock_movements
for select to authenticated 
using (public.is_member(shop_id));

drop policy if exists "movements write by owner_manager" on public.stock_movements;
create policy "movements write by owner_manager" on public.stock_movements
for all to authenticated
using (public.has_role(shop_id, array['owner','manager']::text[]))
with check (public.has_role(shop_id, array['owner','manager']::text[]));

-- =====================================================
-- STORED PROCEDURES
-- =====================================================

-- Perform stock movement (atomic inventory update)
create or replace function public.perform_stock_movement(
  p_shop_id uuid,
  p_product_id uuid,
  p_type text,
  p_qty_delta integer,
  p_reason text default null,
  p_linked_order_id uuid default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare 
  uid uuid := auth.uid();
  movement_id uuid;
begin
  -- Check permissions (owner/manager can adjust)
  if not public.has_role(p_shop_id, array['owner','manager']::text[]) then
    raise exception 'Only owner or manager can perform stock movements';
  end if;

  -- Validate product belongs to shop
  if not exists (select 1 from public.products where id = p_product_id and shop_id = p_shop_id) then
    raise exception 'Product does not belong to this shop';
  end if;

  -- Insert stock movement
  insert into public.stock_movements (
    shop_id, product_id, type, qty_delta, reason, linked_order_id, created_by, updated_by
  )
  values (
    p_shop_id, p_product_id, p_type, p_qty_delta, p_reason, p_linked_order_id, uid, uid
  )
  returning id into movement_id;

  -- Upsert inventory (atomic update)
  insert into public.inventory (
    product_id, shop_id, on_hand_qty, on_reserved_qty, created_by, updated_by
  )
  values (
    p_product_id, p_shop_id, greatest(0, p_qty_delta), 0, uid, uid
  )
  on conflict (product_id) do update
    set on_hand_qty = greatest(0, public.inventory.on_hand_qty + p_qty_delta),
        updated_by = uid,
        updated_at = now(),
        last_modified = now(),
        version = public.inventory.version + 1;

  return movement_id;
end; $$;

grant execute on function public.perform_stock_movement(uuid, uuid, text, integer, text, uuid) to authenticated;

-- Perform sale (decrement inventory, allow cashiers)
create or replace function public.perform_sale_inventory_adjustment(
  p_shop_id uuid,
  p_product_id uuid,
  p_qty_sold integer,
  p_order_id uuid default null
)
returns uuid language plpgsql security definer set search_path=public as $$
declare 
  uid uuid := auth.uid();
  movement_id uuid;
begin
  -- Check permissions (all staff can process sales)
  if not public.is_member(p_shop_id) then
    raise exception 'User is not a member of this shop';
  end if;

  -- Validate product belongs to shop
  if not exists (select 1 from public.products where id = p_product_id and shop_id = p_shop_id) then
    raise exception 'Product does not belong to this shop';
  end if;

  -- Validate quantity is positive
  if p_qty_sold <= 0 then
    raise exception 'Sale quantity must be positive';
  end if;

  -- Insert stock movement (negative for sale)
  insert into public.stock_movements (
    shop_id, product_id, type, qty_delta, reason, linked_order_id, created_by, updated_by
  )
  values (
    p_shop_id, p_product_id, 'sale', -p_qty_sold, 'Sale transaction', p_order_id, uid, uid
  )
  returning id into movement_id;

  -- Update inventory (decrement)
  update public.inventory
  set on_hand_qty = greatest(0, on_hand_qty - p_qty_sold),
      updated_by = uid,
      updated_at = now(),
      last_modified = now(),
      version = version + 1
  where product_id = p_product_id;

  -- If no inventory record exists, create one with 0 (shouldn't happen in normal flow)
  if not found then
    insert into public.inventory (product_id, shop_id, on_hand_qty, on_reserved_qty, created_by, updated_by)
    values (p_product_id, p_shop_id, 0, 0, uid, uid);
  end if;

  return movement_id;
end; $$;

grant execute on function public.perform_sale_inventory_adjustment(uuid, uuid, integer, uuid) to authenticated;

-- =====================================================
-- GRANTS
-- =====================================================

grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.inventory to authenticated;
grant select, insert, update, delete on public.stock_movements to authenticated;

-- =====================================================
-- NOTIFY POSTGREST TO RELOAD SCHEMA
-- =====================================================

select pg_notify('pgrst', 'reload schema');

