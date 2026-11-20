# Reshma Textiles

Reshma Textiles is an own-brand lungi business. This repository contains the public storefront and an authenticated ERP workspace.

## Stack
- Static HTML, CSS and JavaScript (no build step)
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
- index.html — storefront, account dialog and ERP screens
- styles.css — responsive brand and ERP styling
- app.js — Supabase authentication, storefront, admin and ERP workflows
- supabase/schema.sql — original database foundation
- supabase/policies.sql — original grants and row-level security policies
- supabase/erp_phase_0_6_additions.sql — additive ERP schema and database functions
- docs/ERP_BLUEPRINT.md — requirements and workflows for phases 0–6
- docs/IMPLEMENTATION_STATUS.md — implementation and verification record

## Supabase configuration
The browser uses only the project's public publishable key. Never place a Supabase secret or service-role key in client code.

The current project URL and publishable key are configured in index.html. For a different Supabase project, update window.RESHMA_CONFIG with that project's URL and publishable key.

To bootstrap the first trusted administrator:
1. Create the account using the website Account dialog.
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
