-- Reshma Textiles grants and Row Level Security policies.
-- Run after schema.sql. Every table in the exposed public schema must retain RLS.
grant select on public.categories, public.products, public.product_variants to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert on public.wholesale_applications to authenticated;
grant select, insert, update, delete on public.addresses to authenticated;
grant select on public.orders, public.order_items, public.payments, public.shipments to authenticated;
grant select, insert, update, delete on public.categories, public.products, public.product_variants,
  public.inventory_movements, public.raw_materials, public.production_batches,
  public.material_consumption, public.quality_checks, public.shipments, public.orders,
  public.order_items, public.payments, public.wholesale_applications to authenticated;

create policy "Public can view active categories" on public.categories for select to anon, authenticated using (is_active = true or (select private.is_admin()));
create policy "Public can view active products" on public.products for select to anon, authenticated using (is_active = true or (select private.is_admin()));
create policy "Public can view active variants" on public.product_variants for select to anon, authenticated using (is_active = true or (select private.is_admin()));

create policy "Users view own profile" on public.profiles for select to authenticated using (id = (select auth.uid()) or (select private.is_admin()));
create policy "Users update own basic profile" on public.profiles for update to authenticated using (id = (select auth.uid()) or (select private.is_admin())) with check (id = (select auth.uid()) or (select private.is_admin()));
revoke update on public.profiles from authenticated;
grant update (full_name, phone, updated_at) on public.profiles to authenticated;

create policy "Users view own wholesale applications" on public.wholesale_applications for select to authenticated using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy "Users submit wholesale applications" on public.wholesale_applications for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Admins manage wholesale applications" on public.wholesale_applications for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Users manage own addresses" on public.addresses for all to authenticated using (user_id = (select auth.uid()) or (select private.is_admin())) with check (user_id = (select auth.uid()) or (select private.is_admin()));

create policy "Users view own orders" on public.orders for select to authenticated using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy "Users view items for own orders" on public.order_items for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = (select auth.uid()) or (select private.is_admin()))));
create policy "Users view payments for own orders" on public.payments for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = (select auth.uid()) or (select private.is_admin()))));
create policy "Users view shipments for own orders" on public.shipments for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = (select auth.uid()) or (select private.is_admin()))));

create policy "Admins manage categories" on public.categories for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage products" on public.products for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage variants" on public.product_variants for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage orders" on public.orders for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage order items" on public.order_items for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage payments" on public.payments for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage inventory" on public.inventory_movements for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage raw materials" on public.raw_materials for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage production" on public.production_batches for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage consumption" on public.material_consumption for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage quality checks" on public.quality_checks for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins manage shipments" on public.shipments for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
