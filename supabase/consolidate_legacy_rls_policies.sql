drop policy if exists "Admins manage order items" on public.order_items;
drop policy if exists "Users view items for own orders" on public.order_items;
create policy "Users and admins view order items" on public.order_items for select to authenticated
using (exists(select 1 from public.orders o where o.id=order_items.order_id and (o.user_id=(select auth.uid()) or (select private.is_admin()))));
create policy "Admins insert order items" on public.order_items for insert to authenticated with check ((select private.is_admin()));
create policy "Admins update order items" on public.order_items for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins delete order items" on public.order_items for delete to authenticated using ((select private.is_admin()));

drop policy if exists "Admins manage orders" on public.orders;
drop policy if exists "Users view own orders" on public.orders;
create policy "Users and admins view orders" on public.orders for select to authenticated
using (user_id=(select auth.uid()) or (select private.is_admin()));
create policy "Admins insert orders" on public.orders for insert to authenticated with check ((select private.is_admin()));
create policy "Admins update orders" on public.orders for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins delete orders" on public.orders for delete to authenticated using ((select private.is_admin()));

drop policy if exists "Admins manage payments" on public.payments;
drop policy if exists "Users view payments for own orders" on public.payments;
create policy "Users and admins view payments" on public.payments for select to authenticated
using (exists(select 1 from public.orders o where o.id=payments.order_id and (o.user_id=(select auth.uid()) or (select private.is_admin()))));
create policy "Admins insert payments" on public.payments for insert to authenticated with check ((select private.is_admin()));
create policy "Admins update payments" on public.payments for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins delete payments" on public.payments for delete to authenticated using ((select private.is_admin()));

drop policy if exists "Admins manage shipments" on public.shipments;
drop policy if exists "Users view shipments for own orders" on public.shipments;
create policy "Users and admins view shipments" on public.shipments for select to authenticated
using (exists(select 1 from public.orders o where o.id=shipments.order_id and (o.user_id=(select auth.uid()) or (select private.is_admin()))));
create policy "Admins insert shipments" on public.shipments for insert to authenticated with check ((select private.is_admin()));
create policy "Admins update shipments" on public.shipments for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins delete shipments" on public.shipments for delete to authenticated using ((select private.is_admin()));

drop policy if exists "Admins manage wholesale applications" on public.wholesale_applications;
drop policy if exists "Users submit wholesale applications" on public.wholesale_applications;
drop policy if exists "Users view own wholesale applications" on public.wholesale_applications;
create policy "Users and admins view wholesale applications" on public.wholesale_applications for select to authenticated
using (user_id=(select auth.uid()) or (select private.is_admin()));
create policy "Users and admins submit wholesale applications" on public.wholesale_applications for insert to authenticated
with check (user_id=(select auth.uid()) or (select private.is_admin()));
create policy "Admins update wholesale applications" on public.wholesale_applications for update to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "Admins delete wholesale applications" on public.wholesale_applications for delete to authenticated
using ((select private.is_admin()));