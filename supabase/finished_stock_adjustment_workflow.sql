create or replace function public.record_finished_stock_adjustment(
  p_variant_id uuid,
  p_quantity_change integer,
  p_reason text,
  p_reference text default null
) returns integer
language plpgsql
set search_path = 'public'
as $$
declare
  v_variant public.product_variants%rowtype;
  v_new_stock integer;
  v_reason text := lower(btrim(coalesce(p_reason, '')));
begin
  if not (select private.is_admin()) then
    raise exception 'Admin access required';
  end if;
  if p_variant_id is null then raise exception 'Select a finished-goods SKU'; end if;
  if p_quantity_change is null or p_quantity_change = 0 then
    raise exception 'Stock change must be a non-zero whole number';
  end if;
  if v_reason not in ('opening_balance','stock_adjustment','stock_damage','sales_return') then
    raise exception 'Choose a valid stock movement reason';
  end if;
  if v_reason = 'opening_balance' and p_quantity_change < 0 then
    raise exception 'Opening stock must be a positive quantity';
  end if;
  select * into v_variant
  from public.product_variants
  where id = p_variant_id
  for update;
  if not found then raise exception 'Finished-goods SKU not found'; end if;
  v_new_stock := v_variant.stock_qty + p_quantity_change;
  if v_new_stock < 0 then
    raise exception 'Insufficient stock. Available: % pieces', v_variant.stock_qty;
  end if;
  update public.product_variants
  set stock_qty = v_new_stock
  where id = p_variant_id;
  insert into public.inventory_movements(
    variant_id, quantity_change, reason, reference, created_by
  ) values (
    p_variant_id, p_quantity_change, v_reason,
    nullif(btrim(p_reference), ''), auth.uid()
  );
  return v_new_stock;
end;
$$;
revoke all on function public.record_finished_stock_adjustment(uuid,integer,text,text) from public, anon;
grant execute on function public.record_finished_stock_adjustment(uuid,integer,text,text) to authenticated;
