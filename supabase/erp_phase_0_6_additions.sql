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