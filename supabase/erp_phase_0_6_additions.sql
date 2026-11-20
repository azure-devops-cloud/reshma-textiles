begin;

create table if not exists public.production_batch_operations (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references public.production_batches(id) on delete cascade,
  sequence_no integer not null default 1 check (sequence_no > 0),
  operation_name text not null,
  execution_mode text not null default 'in_house' check (execution_mode in ('in_house','job_work')),
  supplier_id uuid references public.suppliers(id) on delete set null,
  status text not null default 'planned' check (status in ('planned','in_progress','completed','cancelled')),
  planned_quantity numeric(12,3) not null default 0 check (planned_quantity >= 0),
  completed_quantity numeric(12,3) not null default 0 check (completed_quantity >= 0),
  agreed_cost numeric(14,2) not null default 0 check (agreed_cost >= 0),
  actual_cost numeric(14,2) not null default 0 check (actual_cost >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint job_work_supplier_required check (execution_mode <> 'job_work' or supplier_id is not null)
);
create index if not exists production_batch_operations_batch_idx on public.production_batch_operations(batch_id, sequence_no);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  expense_number text unique,
  expense_date date not null default current_date,
  category text not null check (category in ('materials','wages','electricity','rent','transport','maintenance','packaging','administration','other')),
  description text not null,
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null check (payment_method in ('cash','upi','bank_transfer','card','cheque','other')),
  paid_to text,
  supplier_id uuid references public.suppliers(id) on delete set null,
  batch_id uuid references public.production_batches(id) on delete set null,
  reference_number text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists expenses_date_idx on public.expenses(expense_date desc);

create table if not exists public.supplier_bills (
  id uuid primary key default gen_random_uuid(),
  bill_number text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  supplier_invoice_number text,
  bill_date date not null default current_date,
  due_date date,
  purchase_order_id uuid references public.purchase_orders(id),
  goods_receipt_id uuid references public.goods_receipts(id),
  status text not null default 'draft' check (status in ('draft','posted','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0 and amount_paid <= total_amount),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','part_paid','paid')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists supplier_bills_supplier_due_idx on public.supplier_bills(supplier_id, due_date);

create table if not exists public.supplier_bill_payments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.supplier_bills(id),
  payment_date date not null default current_date,
  amount numeric(14,2) not null check (amount > 0),
  method text not null check (method in ('cash','upi','bank_transfer','card','cheque','other')),
  reference_number text,
  notes text,
  paid_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists supplier_bill_payments_bill_idx on public.supplier_bill_payments(bill_id, payment_date);

create table if not exists public.invoice_dispatches (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null unique references public.sales_invoices(id),
  dispatch_date date,
  carrier text,
  tracking_number text,
  tracking_url text,
  status text not null default 'pending' check (status in ('pending','dispatched','in_transit','delivered','returned')),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sales_quotations (
  id uuid primary key default gen_random_uuid(),
  quotation_number text not null unique,
  customer_id uuid references public.business_customers(id) on delete set null,
  customer_name text not null,
  quotation_date date not null default current_date,
  valid_until date,
  status text not null default 'draft' check (status in ('draft','sent','accepted','rejected','expired','converted')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  grand_total numeric(14,2) not null default 0 check (grand_total >= 0),
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.sales_quotation_items (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references public.sales_quotations(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,
  product_name text not null,
  sku text,
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  gst_rate numeric(5,2) not null default 0 check (gst_rate between 0 and 100),
  line_total numeric(14,2) not null check (line_total >= 0)
);

create table if not exists public.erp_audit_events (
  id bigint generated always as identity primary key,
  event_type text not null check (event_type in ('insert','update','delete')),
  entity_name text not null,
  entity_id uuid,
  actor_id uuid references auth.users(id) on delete set null,
  changed_fields text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists erp_audit_events_entity_idx on public.erp_audit_events(entity_name, entity_id, created_at desc);
create index if not exists erp_audit_events_actor_idx on public.erp_audit_events(actor_id, created_at desc);

create or replace function private.audit_business_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new jsonb;
  v_old jsonb;
  v_id uuid;
  v_fields text[];
begin
  if tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_new := null;
    v_id := (v_old ->> 'id')::uuid;
    select coalesce(array_agg(key order by key), '{}') into v_fields from jsonb_object_keys(v_old) as key;
  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_old := null;
    v_id := (v_new ->> 'id')::uuid;
    select coalesce(array_agg(key order by key), '{}') into v_fields from jsonb_object_keys(v_new) as key;
  else
    v_new := to_jsonb(new);
    v_old := to_jsonb(old);
    v_id := (v_new ->> 'id')::uuid;
    select coalesce(array_agg(e.key order by e.key), '{}') into v_fields
      from jsonb_each(v_new) e
      where v_old -> e.key is distinct from e.value;
  end if;

  insert into public.erp_audit_events(event_type, entity_name, entity_id, actor_id, changed_fields)
  values (lower(tg_op), tg_table_name, v_id, auth.uid(), v_fields);

  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
revoke all on function private.audit_business_row() from public, anon, authenticated;

drop trigger if exists audit_expenses on public.expenses;
create trigger audit_expenses after insert or update or delete on public.expenses for each row execute function private.audit_business_row();
drop trigger if exists audit_supplier_bills on public.supplier_bills;
create trigger audit_supplier_bills after insert or update or delete on public.supplier_bills for each row execute function private.audit_business_row();
drop trigger if exists audit_supplier_bill_payments on public.supplier_bill_payments;
create trigger audit_supplier_bill_payments after insert or update or delete on public.supplier_bill_payments for each row execute function private.audit_business_row();
drop trigger if exists audit_production_batch_operations on public.production_batch_operations;
create trigger audit_production_batch_operations after insert or update or delete on public.production_batch_operations for each row execute function private.audit_business_row();
drop trigger if exists audit_invoice_dispatches on public.invoice_dispatches;
create trigger audit_invoice_dispatches after insert or update or delete on public.invoice_dispatches for each row execute function private.audit_business_row();
drop trigger if exists audit_sales_quotations on public.sales_quotations;
create trigger audit_sales_quotations after insert or update or delete on public.sales_quotations for each row execute function private.audit_business_row();

do $$
declare t text;
begin
  foreach t in array array['production_batch_operations','expenses','supplier_bills','supplier_bill_payments','invoice_dispatches','sales_quotations','sales_quotation_items','erp_audit_events'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy %I on public.%I for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()))', 'Admins manage '||t, t);
  end loop;
end $$;

create or replace function public.record_supplier_bill_payment(
  p_bill_id uuid,
  p_amount numeric,
  p_method text,
  p_reference text default null,
  p_payment_date date default current_date
) returns void
language plpgsql
set search_path = 'public'
as $$
declare b public.supplier_bills%rowtype;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Payment must be greater than zero'; end if;
  select * into b from public.supplier_bills where id = p_bill_id for update;
  if not found or b.status <> 'posted' then raise exception 'Only posted supplier bills can receive payments'; end if;
  if p_amount > b.total_amount - b.amount_paid then raise exception 'Payment exceeds outstanding balance'; end if;
  insert into public.supplier_bill_payments(bill_id, payment_date, amount, method, reference_number, paid_by)
  values (p_bill_id, p_payment_date, p_amount, p_method, p_reference, auth.uid());
  update public.supplier_bills
  set amount_paid = amount_paid + p_amount,
      payment_status = case when amount_paid + p_amount >= total_amount then 'paid' else 'part_paid' end,
      updated_at = now()
  where id = p_bill_id;
end;
$$;
revoke all on function public.record_supplier_bill_payment(uuid,numeric,text,text,date) from public, anon;
grant execute on function public.record_supplier_bill_payment(uuid,numeric,text,text,date) to authenticated;

create or replace view public.v_erp_finance_summary with (security_invoker = true) as
select
  coalesce((select sum(grand_total) from public.sales_invoices where status = 'issued'),0) as invoiced_sales,
  coalesce((select sum(balance_due) from public.sales_invoices where status = 'issued'),0) as receivables,
  coalesce((select sum(total_amount - amount_paid) from public.supplier_bills where status = 'posted'),0) as payables,
  coalesce((select sum(amount) from public.expenses),0) as recorded_expenses,
  coalesce((select sum(total_amount) from public.supplier_bills where status = 'posted'),0) as supplier_bills_total;
grant select on public.v_erp_finance_summary to authenticated;

commit;

-- Security hardening: audit records are read-only for application users.
create or replace function private.audit_business_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new jsonb;
  v_old jsonb;
  v_id uuid;
  v_fields text[];
begin
  if tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_id := (v_old ->> 'id')::uuid;
    select coalesce(array_agg(k.field order by k.field), '{}') into v_fields from jsonb_object_keys(v_old) as k(field);
  elsif tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_id := (v_new ->> 'id')::uuid;
    select coalesce(array_agg(k.field order by k.field), '{}') into v_fields from jsonb_object_keys(v_new) as k(field);
  else
    v_new := to_jsonb(new);
    v_old := to_jsonb(old);
    v_id := (v_new ->> 'id')::uuid;
    select coalesce(array_agg(e.key order by e.key), '{}') into v_fields
      from jsonb_each(v_new) e
      where v_old -> e.key is distinct from e.value;
  end if;
  insert into public.erp_audit_events(event_type, entity_name, entity_id, actor_id, changed_fields)
  values (lower(tg_op), tg_table_name, v_id, auth.uid(), v_fields);
  if tg_op = 'DELETE' then return old; else return new; end if;
end;
$$;
drop policy if exists "Admins manage erp_audit_events" on public.erp_audit_events;
create policy "Admins view audit events" on public.erp_audit_events for select to authenticated using ((select private.is_admin()));
revoke insert, update, delete on public.erp_audit_events from authenticated, anon;
grant select on public.erp_audit_events to authenticated;

drop trigger if exists audit_purchase_orders on public.purchase_orders;
create trigger audit_purchase_orders after insert or update or delete on public.purchase_orders for each row execute function private.audit_business_row();
drop trigger if exists audit_goods_receipts on public.goods_receipts;
create trigger audit_goods_receipts after insert or update or delete on public.goods_receipts for each row execute function private.audit_business_row();
drop trigger if exists audit_production_batches on public.production_batches;
create trigger audit_production_batches after insert or update or delete on public.production_batches for each row execute function private.audit_business_row();
drop trigger if exists audit_sales_invoices on public.sales_invoices;
create trigger audit_sales_invoices after insert or update or delete on public.sales_invoices for each row execute function private.audit_business_row();
drop trigger if exists audit_sales_invoice_payments on public.sales_invoice_payments;
create trigger audit_sales_invoice_payments after insert or update or delete on public.sales_invoice_payments for each row execute function private.audit_business_row();
drop trigger if exists audit_raw_material_movements on public.raw_material_movements;
create trigger audit_raw_material_movements after insert or update or delete on public.raw_material_movements for each row execute function private.audit_business_row();
drop trigger if exists audit_inventory_movements on public.inventory_movements;
create trigger audit_inventory_movements after insert or update or delete on public.inventory_movements for each row execute function private.audit_business_row();

-- Phase 2 controls: receipt quantities are tracked against each PO line.
alter table public.purchase_order_items add column if not exists received_quantity numeric(12,3) not null default 0;
create unique index if not exists purchase_order_items_po_material_uq on public.purchase_order_items(purchase_order_id, material_id);
do $$
begin
  if not exists(select 1 from pg_constraint where conname='purchase_order_items_received_quantity_check' and conrelid='public.purchase_order_items'::regclass) then
    alter table public.purchase_order_items add constraint purchase_order_items_received_quantity_check check(received_quantity >= 0 and received_quantity <= quantity);
  end if;
  if not exists(select 1 from pg_constraint where conname='production_batch_operations_completed_quantity_check' and conrelid='public.production_batch_operations'::regclass) then
    alter table public.production_batch_operations add constraint production_batch_operations_completed_quantity_check check(completed_quantity <= planned_quantity);
  end if;
  if not exists(select 1 from pg_constraint where conname='supplier_bills_total_matches_components' and conrelid='public.supplier_bills'::regclass) then
    alter table public.supplier_bills add constraint supplier_bills_total_matches_components check(abs(total_amount - subtotal - tax_amount) <= 0.01);
  end if;
  if not exists(select 1 from pg_constraint where conname='goods_receipt_items_rejected_within_received' and conrelid='public.goods_receipt_items'::regclass) then
    alter table public.goods_receipt_items add constraint goods_receipt_items_rejected_within_received check(rejected_quantity <= received_quantity and accepted_quantity + rejected_quantity = received_quantity);
  end if;
end $$;

create or replace function public.create_purchase_order(
  p_supplier_id uuid,
  p_po_number text,
  p_order_date date,
  p_expected_date date,
  p_material_id uuid,
  p_quantity numeric,
  p_unit text,
  p_unit_cost numeric,
  p_tax_rate numeric default 0,
  p_notes text default null
) returns uuid
language plpgsql
set search_path='public'
as $$
declare v_id uuid; v_user uuid; v_taxable numeric; v_tax numeric; v_number text;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_quantity is null or p_quantity <= 0 or p_unit_cost is null or p_unit_cost < 0 or coalesce(p_tax_rate,0) not between 0 and 100 then
    raise exception 'Check quantity, unit cost and tax rate';
  end if;
  if not exists(select 1 from public.suppliers where id=p_supplier_id and is_active=true) then raise exception 'Select an active supplier'; end if;
  if not exists(select 1 from public.raw_materials where id=p_material_id) then raise exception 'Select a valid raw material'; end if;
  v_user:=auth.uid(); v_taxable:=p_quantity*p_unit_cost; v_tax:=v_taxable*coalesce(p_tax_rate,0)/100;
  v_number:=coalesce(nullif(btrim(p_po_number),''),'PO-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(gen_random_uuid()::text,1,4));
  insert into public.purchase_orders(po_number,supplier_id,order_date,expected_date,status,subtotal,tax_amount,total_amount,notes,created_by)
  values(v_number,p_supplier_id,coalesce(p_order_date,current_date),p_expected_date,'approved',v_taxable,v_tax,v_taxable+v_tax,p_notes,v_user)
  returning id into v_id;
  insert into public.purchase_order_items(purchase_order_id,material_id,quantity,unit,unit_cost,tax_rate,taxable_value,tax_amount,line_total)
  values(v_id,p_material_id,p_quantity,p_unit,p_unit_cost,coalesce(p_tax_rate,0),v_taxable,v_tax,v_taxable+v_tax);
  return v_id;
end;
$$;
revoke all on function public.create_purchase_order(uuid,text,date,date,uuid,numeric,text,numeric,numeric,text) from public, anon;
grant execute on function public.create_purchase_order(uuid,text,date,date,uuid,numeric,text,numeric,numeric,text) to authenticated;

create or replace function public.post_goods_receipt(p_receipt_id uuid)
returns void
language plpgsql
set search_path='public'
as $$
declare r public.goods_receipts%rowtype; po public.purchase_orders%rowtype; i record;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  select * into r from public.goods_receipts where id=p_receipt_id for update;
  if not found then raise exception 'Goods receipt not found'; end if;
  if r.status <> 'draft' then raise exception 'Only draft receipts can be posted'; end if;
  if not exists(select 1 from public.goods_receipt_items where goods_receipt_id=p_receipt_id and accepted_quantity>0) then raise exception 'Add accepted material quantities before posting'; end if;
  if r.purchase_order_id is not null then
    select * into po from public.purchase_orders where id=r.purchase_order_id for update;
    if not found or po.status not in ('approved','part_received') then raise exception 'Purchase order is not open for receipt'; end if;
    if po.supplier_id <> r.supplier_id then raise exception 'Receipt supplier does not match the purchase order'; end if;
  end if;
  for i in select * from public.goods_receipt_items where goods_receipt_id=p_receipt_id and accepted_quantity>0 loop
    if r.purchase_order_id is not null then
      update public.purchase_order_items
      set received_quantity=received_quantity+i.accepted_quantity
      where purchase_order_id=r.purchase_order_id and material_id=i.material_id and received_quantity+i.accepted_quantity<=quantity;
      if not found then raise exception 'Accepted quantity exceeds the remaining purchase order quantity for this material'; end if;
    end if;
    update public.raw_materials set current_stock=current_stock+i.accepted_quantity,unit_cost=i.unit_cost where id=i.material_id;
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

create or replace function public.create_and_post_goods_receipt(
  p_supplier_id uuid,
  p_purchase_order_id uuid,
  p_material_id uuid,
  p_supplier_invoice_number text,
  p_received_quantity numeric,
  p_accepted_quantity numeric,
  p_unit_cost numeric,
  p_notes text default null
) returns uuid
language plpgsql
set search_path='public'
as $$
declare v_id uuid;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_received_quantity is null or p_received_quantity<=0 or p_accepted_quantity is null or p_accepted_quantity<0 or p_accepted_quantity>p_received_quantity or p_unit_cost is null or p_unit_cost<0 then
    raise exception 'Check received quantity, accepted quantity and unit cost';
  end if;
  insert into public.goods_receipts(grn_number,purchase_order_id,supplier_id,receipt_date,supplier_invoice_number,status,notes,created_by)
  values('GRN-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(gen_random_uuid()::text,1,4),p_purchase_order_id,p_supplier_id,current_date,nullif(btrim(p_supplier_invoice_number),''),'draft',p_notes,auth.uid())
  returning id into v_id;
  insert into public.goods_receipt_items(goods_receipt_id,material_id,received_quantity,accepted_quantity,rejected_quantity,unit_cost)
  values(v_id,p_material_id,p_received_quantity,p_accepted_quantity,p_received_quantity-p_accepted_quantity,p_unit_cost);
  perform public.post_goods_receipt(v_id);
  return v_id;
end;
$$;
revoke all on function public.create_and_post_goods_receipt(uuid,uuid,uuid,text,numeric,numeric,numeric,text) from public, anon;
grant execute on function public.create_and_post_goods_receipt(uuid,uuid,uuid,text,numeric,numeric,numeric,text) to authenticated;
create or replace function public.create_purchase_order(
  p_supplier_id uuid,
  p_po_number text,
  p_order_date date,
  p_expected_date date,
  p_material_id uuid,
  p_quantity numeric,
  p_unit text,
  p_unit_cost numeric,
  p_tax_rate numeric default 0,
  p_notes text default null
) returns uuid
language plpgsql
set search_path='public'
as $$
declare v_id uuid; v_user uuid; v_taxable numeric; v_tax numeric; v_number text; v_material public.raw_materials%rowtype;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_quantity is null or p_quantity <= 0 or p_unit_cost is null or p_unit_cost < 0 or coalesce(p_tax_rate,0) not between 0 and 100 then
    raise exception 'Check quantity, unit cost and tax rate';
  end if;
  if not exists(select 1 from public.suppliers where id=p_supplier_id and is_active=true) then raise exception 'Select an active supplier'; end if;
  select * into v_material from public.raw_materials where id=p_material_id;
  if not found then raise exception 'Select a valid raw material'; end if;
  v_user:=auth.uid(); v_taxable:=p_quantity*p_unit_cost; v_tax:=v_taxable*coalesce(p_tax_rate,0)/100;
  v_number:=coalesce(nullif(btrim(p_po_number),''),'PO-'||to_char(clock_timestamp(),'YYYYMMDDHH24MISSMS')||'-'||substr(gen_random_uuid()::text,1,4));
  insert into public.purchase_orders(po_number,supplier_id,order_date,expected_date,status,subtotal,tax_amount,total_amount,notes,created_by)
  values(v_number,p_supplier_id,coalesce(p_order_date,current_date),p_expected_date,'approved',v_taxable,v_tax,v_taxable+v_tax,p_notes,v_user)
  returning id into v_id;
  insert into public.purchase_order_items(purchase_order_id,material_id,item_description,quantity,unit,unit_cost,tax_rate,taxable_value,tax_amount,line_total)
  values(v_id,p_material_id,v_material.name,p_quantity,coalesce(nullif(btrim(p_unit),''),v_material.unit),p_unit_cost,coalesce(p_tax_rate,0),v_taxable,v_tax,v_taxable+v_tax);
  return v_id;
end;
$$;
revoke all on function public.create_purchase_order(uuid,text,date,date,uuid,numeric,text,numeric,numeric,text) from public, anon;
grant execute on function public.create_purchase_order(uuid,text,date,date,uuid,numeric,text,numeric,numeric,text) to authenticated;
