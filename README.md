# Reshma Textiles

Reshma Textiles is an own-brand lungi business. This repository contains a private, owner-authenticated ERP application. The public storefront is out of scope and the root route opens the ERP sign-in screen.

## Stack
- Installable Progressive Web App (PWA), static HTML/CSS/JavaScript (no build step)
- Supabase PostgreSQL, Auth and Row Level Security
- Vercel deployment (commercial-use terms must be checked before production use)

## ERP modules
- Product, category, SKU/variant and business settings
- Suppliers, purchase orders and goods receipt notes
- Raw-material movement ledger and reorder levels
- Production batches, material issue, manufacturing costs and configurable in-house/job-work operations
- Quality checks and accepted finished-goods stock
- Business customers, quotations, GST invoice drafts/issue, payment receipts and dispatch tracking
- Supplier bills/payables, expenses, finance summaries and audit trail

## Repository layout
- index.html — private ERP sign-in and application shell
- styles.css — responsive ERP application styling
- app.js — owner authentication, PWA navigation and ERP workflows
- supabase/schema.sql — original database foundation
- supabase/policies.sql — original grants and row-level security policies
- supabase/erp_phase_0_6_additions.sql — additive ERP schema and database functions
- docs/ERP_BLUEPRINT.md — requirements and workflows for phases 0–6
- docs/IMPLEMENTATION_STATUS.md — implementation and verification record

## Supabase configuration
The browser uses only the project's public publishable key. Never place a Supabase secret or service-role key in client code.

The current project URL and publishable key are configured in index.html. The browser uses only the publishable key; never place a secret or service-role key in client code.

To bootstrap the first trusted administrator:
1. The owner account is provisioned separately in Supabase Auth; the app exposes sign-in only and does not offer public account creation.
2. In Supabase SQL Editor, set the exact Auth user UUID to admin:
   `update public.profiles set role = 'admin' where id = '<AUTH_USER_UUID>';`
3. Sign in again to refresh the session and load the private ERP workspace.

All business tables are protected by RLS. ERP operations are currently admin-only until actual staff roles and responsibilities are confirmed. Do not assign admin to ordinary staff.

## Tax and finance safety
- Business GST registration is configured as enabled, but final invoice issue remains blocked until the verified legal name, GSTIN, registered address, state code, HSN and applicable tax rates are entered.
- Do not use dummy GSTINs, HSNs or fabricated business records.
- Draft invoices and quotations do not post stock. Stock changes only through database posting functions.
- Supplier bill payments cannot exceed the outstanding balance.
- Audit events are append-only for application users.

## Development and deployment
- Active ERP work is being developed on branch erp-phase-0-6.
- Production main branch has not been changed as part of this implementation.
- Preview deployments may be protected by Vercel SSO.
- Before production launch, verify the hosting plan's commercial-use terms. Vercel Hobby is intended for personal/non-commercial use.


## Owner-only ERP app
- The root route opens the owner sign-in page; there is no public catalogue, shopping cart or public enquiry workflow.
- The first authorized account must have `profiles.role = 'admin'`. The UI rejects other signed-in accounts.
- Suppliers, customers and employees are business records only. They do not receive login access in the initial release.
- Navigation is app-style and responsive; the manifest and service worker provide install support on compatible Android and desktop browsers.
- The service worker caches only the static app shell. Live ERP data and sign-in still require a network connection.
- Public anonymous policies for product/catalogue reads and customer enquiry submissions were removed. ERP business tables remain protected by admin-only RLS.
- Existing Supabase/Vercel hosting plans and commercial-use terms must be reviewed before commercial production use.
