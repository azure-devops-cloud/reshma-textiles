# Reshma Textiles

Initial storefront foundation for Reshma Textiles, a lungi manufacturer serving retail and wholesale customers across India.

## Stack
- Static HTML, CSS and JavaScript (no build step)
- Supabase PostgreSQL, Auth and Row Level Security
- Deployable to a static host after checking current commercial-use terms

## Files
- `index.html` — storefront and account/enquiry UI
- `styles.css` — responsive brand styling
- `app.js` — live product catalogue and email/password authentication
- `supabase/schema.sql` — database schema source

## Supabase configuration
1. Open https://supabase.com/dashboard/project/nxsebszsdqcjrrhlkoqc
2. Go to Project Settings → API Keys.
3. Copy the Project URL and **publishable** key. Never use a secret/service-role key in browser code.
4. Replace the empty values in `window.RESHEMA_CONFIG` near the end of `index.html`.
5. Configure the Auth Site URL and allowed redirect URLs for the eventual website origin.
6. To promote the first trusted admin, use the SQL editor with the exact Auth user UUID: `update public.profiles set role = 'admin' where id = '<AUTH_USER_UUID>';`

The database schema and RLS policies have already been applied to the new Supabase project. The current site is an initial catalogue and enquiry foundation, not a completed commerce system. Cart checkout, payment processing, invoices, shipment integration and full admin screens remain to be built and tested.

Before launch: replace the placeholder WhatsApp contact flow with the official business number; add real product photos, variants, SKU and verified prices; test customer/admin access; and configure a secure order-creation workflow. Never commit secrets or customer data.

Vercel Hobby is not suitable for this commercial business website. Verify a host's current commercial-use and free-tier terms before deployment.