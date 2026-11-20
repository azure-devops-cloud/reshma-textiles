create or replace function public.post_goods_receipt(p_receipt_id uuid)
returns void
language plpgsql
set search_path='public'
as $$
declare
  r public.goods_receipts%rowtype;
  po public.purchase_orders%rowtype;
  i record;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  select * into r from public.goods_receipts where id=p_receipt_id for update;
  if not found then raise exception 'Goods receipt not found'; end if;
  if r.status<>'draft' then raise exception 'Only draft receipts can be posted'; end if;
  if not exists(select 1 from public.goods_receipt_items where goods_receipt_id=p_receipt_id and received_quantity>0) then
    raise exception 'Add received quantities before posting';
  end if;
  if r.purchase_order_id is not null then
    select * into po from public.purchase_orders where id=r.purchase_order_id for update;
    if not found or po.status not in ('approved','part_received') then raise exception 'Purchase order is not open for receipt'; end if;
    if po.supplier_id<>r.supplier_id then raise exception 'Receipt supplier does not match the purchase order'; end if;
  end if;
  for i in select * from public.goods_receipt_items where goods_receipt_id=p_receipt_id and accepted_quantity>0 loop
    if r.purchase_order_id is not null then
      update public.purchase_order_items
      set received_quantity=received_quantity+i.accepted_quantity
      where purchase_order_id=r.purchase_order_id
        and material_id=i.material_id
        and received_quantity+i.accepted_quantity<=quantity;
      if not found then raise exception 'Accepted quantity exceeds the remaining purchase order quantity for this material'; end if;
    end if;
    update public.raw_materials
    set current_stock=current_stock+i.accepted_quantity,unit_cost=i.unit_cost
    where id=i.material_id;
    insert into public.raw_material_movements(material_id,quantity_change,unit_cost,movement_type,reference_type,reference_id,created_by)
    values(i.material_id,i.accepted_quantity,i.unit_cost,'purchase_receipt','goods_receipt',p_receipt_id,auth.uid());
  end loop;
  update public.goods_receipts set status='posted',posted_at=now() where id=p_receipt_id;
  if r.purchase_order_id is not null then
    update public.purchase_orders
    set status=case when exists(select 1 from public.purchase_order_items where purchase_order_id=r.purchase_order_id and received_quantity<quantity) then 'part_received' else 'received' end,
        updated_at=now()
    where id=r.purchase_order_id;
  end if;
end;
$$;
revoke all on function public.post_goods_receipt(uuid) from public, anon;
grant execute on function public.post_goods_receipt(uuid) to authenticated;