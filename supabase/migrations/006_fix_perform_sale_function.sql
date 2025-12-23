-- Fix the perform_sale function to write totals and status correctly
create or replace function public.perform_sale(
  p_shop_id        uuid,
  p_items          jsonb,     -- [ { "product_id": "...", "qty": 2, "unit_price_cents": 1500 }, ... ]
  p_channel        text default 'in_store',
  p_customer_id    uuid default null,
  p_payment_method text default 'cash',
  p_amount_cents   integer default 0
)
returns table(order_id uuid, total_cents integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id uuid := gen_random_uuid();
  v_subtotal integer := 0;
  v_item jsonb;
  v_product_id uuid;
  v_qty numeric;
  v_unit_price integer;
  v_on_hand integer;
  v_inv_exists integer;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Verify membership (adjust to your policy helper)
  if not public.is_member(p_shop_id) then
    raise exception 'Not a member of this shop';
  end if;

  -- Insert order header with safe defaults
  insert into public.orders (
    id, shop_id, channel, customer_id, payment_method,
    amount_cents, amount_paid_cents,
    subtotal_cents, tax_cents, discount_cents, total_cents,
    status, payment_status,
    created_by
  )
  values (
    v_order_id, p_shop_id, coalesce(p_channel, 'in_store'), p_customer_id, coalesce(p_payment_method,'cash'),
    coalesce(p_amount_cents,0), coalesce(p_amount_cents,0),
    0, 0, 0, 0,
    'completed',               -- important for reports
    'paid',                    -- important for reports
    v_uid
  );

  -- Loop items
  for v_item in
    select * from jsonb_array_elements(p_items)
  loop
    v_product_id  := (v_item->>'product_id')::uuid;
    v_qty         := (v_item->>'qty')::numeric;
    v_unit_price  := coalesce((v_item->>'unit_price_cents')::int, 0);

    -- Product must belong to the same shop
    perform 1 from public.products p
      where p.id = v_product_id and p.shop_id = p_shop_id and p.deleted_at is null;
    if not found then
      raise exception 'Product % not found for this shop', v_product_id;
    end if;

    -- Ensure inventory row exists
    select count(*) into v_inv_exists
      from public.inventory i
      where i.product_id = v_product_id and i.shop_id = p_shop_id;
    if v_inv_exists = 0 then
      insert into public.inventory (product_id, shop_id, on_hand_qty, on_reserved_qty, created_by)
      values (v_product_id, p_shop_id, 0, 0, v_uid)
      on conflict (product_id) do nothing;
    end if;

    -- Check stock & decrement
    select on_hand_qty into v_on_hand from public.inventory
      where product_id = v_product_id and shop_id = p_shop_id
      for update;

    if v_on_hand < v_qty then
      raise exception 'Insufficient stock for product % (have %, need %)', v_product_id, v_on_hand, v_qty;
    end if;

    update public.inventory
      set on_hand_qty = on_hand_qty - v_qty::int,
          updated_by  = v_uid,
          updated_at  = now()
      where product_id = v_product_id and shop_id = p_shop_id;

    -- Add order item (NOTE: no shop_id column here)
    insert into public.order_items (
      order_id, product_id, qty, unit_price_cents, total_cents, created_by
    )
    values (
      v_order_id, v_product_id, v_qty::int, v_unit_price, (v_qty::int * v_unit_price), v_uid
    );

    -- Log stock movement
    insert into public.stock_movements (
      shop_id, product_id, type, qty_delta, reason, linked_order_id, created_by
    ) values (
      p_shop_id, v_product_id, 'sale', -(v_qty::int), 'sale', v_order_id, v_uid
    );

    v_subtotal := v_subtotal + (v_qty::int * v_unit_price);
  end loop;

  -- Finalize order totals
  update public.orders
    set subtotal_cents = v_subtotal,
        tax_cents      = 0,
        discount_cents = 0,
        total_cents    = v_subtotal,
        updated_at     = now(),
        updated_by     = v_uid
    where id = v_order_id;

  return query select v_order_id, v_subtotal;
end;
$$;

-- Grant execute permission
grant execute on function public.perform_sale(uuid, jsonb, text, uuid, text, integer) to authenticated;
