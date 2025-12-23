-- =====================================================
-- PERFORM_SALE FUNCTION
-- =====================================================
-- This function atomically creates an order with items and decrements inventory
-- Called from the app when completing a sale

create or replace function public.perform_sale(
  p_shop_id uuid,
  p_items jsonb,
  p_channel text default 'in_store',
  p_customer_id uuid default null,
  p_payment_method text default 'cash',
  p_amount_cents integer default 0
)
returns jsonb language plpgsql security definer set search_path=public as $$
declare 
  uid uuid := auth.uid();
  v_order_id uuid;
  v_total_cents integer := 0;
  v_item jsonb;
  v_product_id uuid;
  v_qty numeric;
  v_unit_price_cents integer;
  v_line_total integer;
begin
  -- Check permissions (all staff can process sales)
  if not public.is_member(p_shop_id) then
    raise exception 'User is not a member of this shop';
  end if;

  -- Validate items array
  if jsonb_array_length(p_items) = 0 then
    raise exception 'Sale must have at least one item';
  end if;

  -- Create order
  insert into public.orders (
    shop_id,
    customer_id,
    channel,
    status,
    payment_method,
    total_cents,
    created_by,
    updated_by
  )
  values (
    p_shop_id,
    p_customer_id,
    p_channel,
    'completed',
    p_payment_method,
    0, -- will update after calculating total
    uid,
    uid
  )
  returning id into v_order_id;

  -- Process each item
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    -- Extract values from JSON with explicit casting
    v_product_id := (v_item->>'product_id')::uuid;
    v_qty := (v_item->>'qty')::numeric;
    v_unit_price_cents := (v_item->>'unit_price_cents')::integer;
    v_line_total := (v_unit_price_cents * v_qty)::integer;
    v_total_cents := v_total_cents + v_line_total;

    -- Validate product belongs to shop
    if not exists (
      select 1 
      from public.products p
      where p.id = v_product_id 
        and p.shop_id = p_shop_id
        and p.deleted_at is null
    ) then
      raise exception 'Product % does not belong to this shop', v_product_id;
    end if;

    -- Check inventory availability
    if exists (
      select 1 
      from public.inventory inv
      where inv.product_id = v_product_id 
        and inv.shop_id = p_shop_id
        and inv.on_hand_qty < v_qty
    ) then
      raise exception 'Insufficient stock for product %', v_product_id;
    end if;

    -- Insert order item
    insert into public.order_items (
      order_id,
      product_id,
      qty,
      unit_price_cents,
      total_cents,
      created_by,
      updated_by
    )
    values (
      v_order_id,
      v_product_id,
      v_qty,
      v_unit_price_cents,
      v_line_total,
      uid,
      uid
    );

    -- Decrement inventory
    update public.inventory inv
    set on_hand_qty = greatest(0, inv.on_hand_qty - v_qty),
        updated_by = uid,
        updated_at = now(),
        last_modified = now(),
        version = inv.version + 1
    where inv.product_id = v_product_id
      and inv.shop_id = p_shop_id;

    -- If no inventory record exists, create one with 0 (shouldn't happen)
    if not found then
      insert into public.inventory (
        product_id,
        shop_id,
        on_hand_qty,
        on_reserved_qty,
        created_by,
        updated_by
      )
      values (
        v_product_id,
        p_shop_id,
        0,
        0,
        uid,
        uid
      );
    end if;

    -- Record stock movement
    insert into public.stock_movements (
      shop_id,
      product_id,
      type,
      qty_delta,
      reason,
      linked_order_id,
      created_by,
      updated_by
    )
    values (
      p_shop_id,
      v_product_id,
      'sale',
      -v_qty,
      'Sale order ' || v_order_id::text,
      v_order_id,
      uid,
      uid
    );
  end loop;

  -- Update order total
  update public.orders o
  set total_cents = v_total_cents,
      updated_at = now(),
      last_modified = now(),
      version = o.version + 1
  where o.id = v_order_id;

  -- Return order details
  return jsonb_build_object(
    'order_id', v_order_id,
    'total_cents', v_total_cents
  );
end; $$;

-- Grant execute permission
grant execute on function public.perform_sale(uuid, jsonb, text, uuid, text, integer) to authenticated;

-- Notify PostgREST to reload schema
select pg_notify('pgrst', 'reload schema');

