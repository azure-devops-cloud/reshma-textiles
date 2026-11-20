create index if not exists addresses_user_id_idx on public.addresses(user_id);
create index if not exists inventory_movements_created_by_idx on public.inventory_movements(created_by);
create index if not exists inventory_movements_variant_id_idx on public.inventory_movements(variant_id);
create index if not exists material_consumption_batch_id_idx on public.material_consumption(batch_id);
create index if not exists material_consumption_material_id_idx on public.material_consumption(material_id);
create index if not exists order_items_order_id_idx on public.order_items(order_id);
create index if not exists order_items_product_id_idx on public.order_items(product_id);
create index if not exists order_items_variant_id_idx on public.order_items(variant_id);
create index if not exists orders_user_id_idx on public.orders(user_id);
create index if not exists payments_order_id_idx on public.payments(order_id);
create index if not exists product_variants_product_id_idx on public.product_variants(product_id);
create index if not exists production_batches_product_id_idx on public.production_batches(product_id);
create index if not exists products_category_id_idx on public.products(category_id);
create index if not exists quality_checks_batch_id_idx on public.quality_checks(batch_id);
create index if not exists sales_invoice_payments_invoice_id_idx on public.sales_invoice_payments(invoice_id);
create index if not exists wholesale_applications_user_id_idx on public.wholesale_applications(user_id);

create or replace function public.complete_production_batch(
  p_batch_id uuid,
  p_accepted integer,
  p_rejected integer,
  p_notes text default null
) returns void
language plpgsql
set search_path='public'
as $$
declare
  b public.production_batches%rowtype;
  v public.product_variants%rowtype;
  total_cost numeric;
  extra_cost numeric;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_accepted is null or p_rejected is null or p_accepted<0 or p_rejected<0 then
    raise exception 'Accepted and rejected quantities must be zero or greater';
  end if;
  if p_accepted+p_rejected=0 then
    raise exception 'A batch cannot be completed with zero inspected pieces';
  end if;
  select * into b from public.production_batches where id=p_batch_id for update;
  if not found or b.status not in ('planned','in_progress','quality_check') then raise exception 'Batch cannot be completed'; end if;
  if b.output_variant_id is null then raise exception 'Select the finished-goods variant for this batch'; end if;
  if p_accepted+p_rejected>b.planned_quantity then raise exception 'Accepted plus rejected quantity exceeds planned quantity'; end if;
  select * into v from public.product_variants where id=b.output_variant_id for update;
  if not found or v.product_id<>b.product_id then raise exception 'Selected variant does not belong to this product'; end if;
  select coalesce(sum(amount),0) into extra_cost from public.manufacturing_costs where batch_id=p_batch_id;
  total_cost:=b.total_material_cost+b.labour_cost+b.overhead_cost+extra_cost;
  insert into public.quality_checks(batch_id,checked_quantity,passed_quantity,rejected_quantity,notes)
  values(p_batch_id,p_accepted+p_rejected,p_accepted,p_rejected,p_notes);
  if p_accepted>0 then
    update public.product_variants set stock_qty=stock_qty+p_accepted where id=b.output_variant_id;
    insert into public.inventory_movements(variant_id,quantity_change,reason,reference,created_by)
    values(b.output_variant_id,p_accepted,'production_output','batch:'||p_batch_id::text,auth.uid());
  end if;
  update public.production_batches
  set produced_quantity=p_accepted+p_rejected,
      accepted_quantity=p_accepted,
      rejected_quantity=p_rejected,
      status='completed',
      completion_date=current_date,
      overhead_cost=overhead_cost+extra_cost,
      cost_per_accepted_unit=case when p_accepted>0 then total_cost/p_accepted else null end,
      notes=coalesce(p_notes,notes)
  where id=p_batch_id;
end;
$$;
revoke all on function public.complete_production_batch(uuid,integer,integer,text) from public, anon;
grant execute on function public.complete_production_batch(uuid,integer,integer,text) to authenticated;