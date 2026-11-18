-- Reshma Textiles initial database schema (already applied to Supabase project nxsebszsdqcjrrhlkoqc).
-- All tables in public have RLS enabled. Admin role is assigned only by a trusted project owner.
create extension if not exists pgcrypto;
create schema if not exists private;
create type public.app_role as enum ('customer','wholesale_pending','wholesale','admin');
create type public.order_status as enum ('pending','confirmed','processing','packed','shipped','delivered','cancelled');
create type public.payment_status as enum ('unpaid','pending_verification','paid','refunded');
create type public.production_status as enum ('planned','in_progress','quality_check','completed','cancelled');

create table public.profiles(id uuid primary key references auth.users(id) on delete cascade, full_name text, phone text, role public.app_role not null default 'customer', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.categories(id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique, description text, is_active boolean not null default true, sort_order int not null default 0, created_at timestamptz not null default now());
create table public.products(id uuid primary key default gen_random_uuid(), category_id uuid references public.categories(id) on delete set null, name text not null, slug text not null unique, sku text unique, description text, fabric text, design text, image_url text, retail_price numeric(12,2) not null default 0 check(retail_price>=0), wholesale_price numeric(12,2) not null default 0 check(wholesale_price>=0), min_wholesale_qty int not null default 10 check(min_wholesale_qty>0), is_active boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.product_variants(id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade, sku text unique, color text, size text, length text, retail_price numeric(12,2) check(retail_price>=0), wholesale_price numeric(12,2) check(wholesale_price>=0), stock_qty int not null default 0 check(stock_qty>=0), is_active boolean not null default true, created_at timestamptz not null default now());
create table public.wholesale_applications(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, business_name text not null, gstin text, phone text not null, address text, expected_monthly_qty int, status text not null default 'pending' check(status in ('pending','approved','rejected')), created_at timestamptz not null default now());
create table public.addresses(id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, label text default 'Home', recipient_name text not null, phone text not null, line1 text not null, line2 text, city text not null, state text not null, postal_code text not null, is_default boolean not null default false, created_at timestamptz not null default now());
create table public.orders(id uuid primary key default gen_random_uuid(), order_number text not null unique, user_id uuid not null references auth.users(id), status public.order_status not null default 'pending', payment_status public.payment_status not null default 'unpaid', subtotal numeric(12,2) not null check(subtotal>=0), shipping_amount numeric(12,2) not null default 0 check(shipping_amount>=0), total_amount numeric(12,2) not null check(total_amount>=0), shipping_address jsonb not null, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.order_items(id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade, product_id uuid references public.products(id) on delete set null, variant_id uuid references public.product_variants(id) on delete set null, product_name text not null, sku text, quantity int not null check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0), line_total numeric(12,2) not null check(line_total>=0));
create table public.payments(id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade, method text not null check(method in ('upi','cod','bank_transfer','other')), amount numeric(12,2) not null check(amount>=0), status public.payment_status not null default 'pending_verification', reference_number text, proof_url text, verified_at timestamptz, created_at timestamptz not null default now());
create table public.inventory_movements(id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.product_variants(id), quantity_change int not null check(quantity_change<>0), reason text not null, reference text, created_by uuid references auth.users(id), created_at timestamptz not null default now());
create table public.raw_materials(id uuid primary key default gen_random_uuid(), name text not null, unit text not null default 'kg', current_stock numeric(12,3) not null default 0 check(current_stock>=0), reorder_level numeric(12,3) not null default 0 check(reorder_level>=0), unit_cost numeric(12,2) not null default 0 check(unit_cost>=0), created_at timestamptz not null default now());
create table public.production_batches(id uuid primary key default gen_random_uuid(), batch_number text not null unique, product_id uuid not null references public.products(id), planned_quantity int not null check(planned_quantity>0), produced_quantity int not null default 0 check(produced_quantity>=0), status public.production_status not null default 'planned', start_date date, completion_date date, notes text, created_at timestamptz not null default now());
create table public.material_consumption(id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.production_batches(id) on delete cascade, material_id uuid not null references public.raw_materials(id), quantity_used numeric(12,3) not null check(quantity_used>0), created_at timestamptz not null default now());
create table public.quality_checks(id uuid primary key default gen_random_uuid(), batch_id uuid not null references public.production_batches(id) on delete cascade, checked_quantity int not null default 0, passed_quantity int not null default 0, rejected_quantity int not null default 0, notes text, checked_at timestamptz not null default now(), check(passed_quantity+rejected_quantity<=checked_quantity));
create table public.shipments(id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id) on delete cascade, carrier text, tracking_number text, tracking_url text, shipped_at timestamptz, delivered_at timestamptz, created_at timestamptz not null default now());

create or replace function private.is_admin() returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.profiles where id=(select auth.uid()) and role='admin'::public.app_role); $$;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;
create or replace function private.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name')); return new; end; $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure private.handle_new_user();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.wholesale_applications enable row level security;
alter table public.addresses enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.raw_materials enable row level security;
alter table public.production_batches enable row level security;
alter table public.material_consumption enable row level security;
alter table public.quality_checks enable row level security;
alter table public.shipments enable row level security;

-- Policies and grants are provisioned in the live project. See README for the admin bootstrap procedure.
