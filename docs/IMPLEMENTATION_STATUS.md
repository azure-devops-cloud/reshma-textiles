# ERP Implementation Status

## Baseline inspected
- Existing static HTML/CSS/JavaScript storefront and admin workspace.
- Existing Supabase project is active and contains core commerce, procurement, manufacturing, quality, invoice and ledger tables.
- Existing RPCs: `post_goods_receipt`, `issue_production_material`, `complete_production_batch`, `post_sales_invoice`, `record_invoice_payment`.
- Existing public website is reachable and the latest Vercel production deployment is READY.
- Current ERP workspace code was being loaded twice from `app.js` and `business-ops.js`; branch `erp-phase-0-6` removes the duplicate module include.

## Data state observed (read-only inspection)
- One profile exists.
- Three raw-material master rows exist (names currently look like test placeholders); preserve them until the owner confirms whether they are test or real.
- No supplier, purchase order, production batch, finished-goods invoice or product records were present at inspection.
- Business settings indicate GST registered, but legal name, GSTIN, registered address and state code are not configured. Final tax invoice issuance must remain blocked until actual verified values are entered.

## Known gaps to close
- Login issue reported by owner is not yet diagnosed; credentials are not available to test a real sign-in. Need the exact on-screen error if it persists after the duplicate module fix.
- Purchase order and goods receipt UI currently use multiple client requests; consolidate document creation/posting into atomic database functions.
- Add job-work operation routing, supplier bills/payables, expenses, dispatch against invoices, audit events and finance/reporting screens.
- Review every RLS policy and RPC grant after schema additions.
- Add automated checks for duplicate submission, stock reconciliation, invoice blocking and payment limits.

## Deployment discipline
- Work on `erp-phase-0-6` first; do not change the production storefront until branch verification is complete.
- No sample business transactions, fake legal/tax identifiers or paid-plan upgrades.
- Promote to production only after owner review and successful smoke tests.
