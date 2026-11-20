-- Owner-only ERP hardening: remove public storefront and enquiry policies.
-- Applied to the Reshma Textiles Supabase project on 2026-11-20.
drop policy if exists "Public can view active categories" on public.categories;
drop policy if exists "Public can view active variants" on public.product_variants;
drop policy if exists "Public can view active products" on public.products;
drop policy if exists "Anyone can submit customer enquiries" on public.customer_enquiries;
