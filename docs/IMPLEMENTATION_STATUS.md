# ERP Implementation Status

## Implemented on branch erp-phase-0-6
- ERP-only application shell: public storefront is no longer the entry experience; root route shows owner sign-in and authenticated ERP navigation.
- Installable PWA foundation: manifest, branded SVG app icon, service worker shell caching, responsive mobile/desktop layout and install prompt.
- Owner-only sign-in: sign-in only, no in-app account creation; application checks the authenticated user's admin profile before showing the ERP workspace.
- Removed anonymous RLS policies for public product/category/variant reads and public enquiry submission. Verified no remaining public-role policies in the public schema.
- Phase 0: business workflow blueprint and acceptance checklist documented in docs/ERP_BLUEPRINT.md.
- Phase 1: existing Supabase Auth/admin foundation retained; storefront and authenticated ERP remain separate; duplicate module loading and JavaScript parse error fixed.
- Phase 2: supplier, PO and GRN workflows; PO creation and GRN posting now use atomic database functions; PO line received quantities and partial/full receipt states are tracked.
- Phase 3: production batches, material issues, cost capture and configurable in-house/job-work operation routing with stage status updates.
- Phase 4: existing quality-check completion flow remains; accepted output only is added to finished stock.
- Phase 5: customers, quotations, invoice drafts/issue, payments and invoice dispatch tracking.
- Phase 6: expense register, supplier bills/payments, receivables/payables, finance summaries and audit history.
- Added database-side audit events for key procurement, inventory, production, sales and finance records. Audit events are read-only to application users.
- New exposed tables have RLS enabled and admin-only policies. New payment/posting RPCs explicitly check admin access.

## Verification performed
- Supabase schema inspection confirms RLS enabled on all 8 new tables.
- Rollback-only database integration test passed: PO creation, partial receipt, full receipt, over-receipt rejection, stock movement, audit trigger and PO status transitions. Test data was rolled back; no supplier/PO/GRN/expense/audit rows were left behind.
- Rollback-only supplier payment test passed: payment balance updated and overpayment rejected. Test data was rolled back.
- Rollback-only invoice validation test passed: final invoice issue is blocked when the business is GST-registered but verified seller legal name/GSTIN/address/state code are missing; no stock was deducted. Test data was rolled back.
- JavaScript module syntax check passed.
- Static HTML check: 149 IDs, no duplicate IDs, no missing static selector targets, and only one module script (app.js) is loaded.
- Vercel generated a READY preview deployment for the branch. Vercel SSO protection prevents unauthenticated external inspection of the preview; production has not been changed.

## Existing live data preserved
- One admin profile.
- Three existing raw-material master records named Abc, Def, and Eee were left untouched; owner should confirm whether these are test labels or actual materials.
- No supplier, purchase order, production batch, product, quotation, invoice or supplier-bill test data was retained.
- Business settings show GST registered, but legal name, GSTIN, registered address and state code are blank. Final tax invoice issuance remains blocked until verified details are entered.

## Remaining work before production approval
- Owner must test sign-in with their real account. A real password was not available for automated login testing. The original JavaScript parse error that prevented the module from loading is fixed on this branch.
- Initial ERP permissions remain admin-only. Configure staff roles and module-level permissions only after the actual staff list and responsibilities are known.
- Add complete sales order/returns workflow, richer supplier-bill line matching, bank/cash ledger reconciliation, statutory accounting reports and payroll if required.
- Review the existing Supabase security advisor warning: leaked-password protection is disabled. Enable it in Supabase Auth settings.
- Existing database performance advisor still reports some pre-existing unindexed foreign keys and multiple permissive policies; new ERP foreign-key indexes have been added, but the remaining legacy findings should be reviewed before scale-up.
- AI assistants are not yet connected to live business actions. Future AI remains recommendation-only until explicitly approved and separately permissioned.

## Deployment discipline
- Work remains on erp-phase-0-6; production storefront and main branch have not been changed.
- No sample business transactions, fake legal/tax identifiers or paid-plan upgrades were added.
- Merge/deploy only after owner review of the preview and confirmation of the three raw-material labels and actual factory process.


## Owner-only PWA milestone verification (2026-11-20)
- Root route now serves an owner sign-in experience and app-style ERP shell; the previous public storefront is hidden from the user experience and page metadata is noindex.
- The ERP shell uses the existing business workspace and module tabs; navigation is adapted for mobile and desktop.
- PWA manifest, SVG icon and service worker are committed. The service worker caches the static shell only; authenticated database workflows require connectivity.
- Owner login checks the authenticated user's `profiles.role` and only admits `admin`. The application no longer offers account registration.
- Removed anonymous policies for public product, category and variant reads and anonymous customer enquiry inserts. A fresh `pg_policies` query confirmed no remaining policies granted to the `anon` role in the public schema.
- Supabase security advisor still warns that leaked-password protection is disabled. Performance advisor reports 16 unindexed foreign keys and existing multiple-permissive-policy findings; these are tracked for a separate database tuning pass.
- Vercel status checks for the latest ERP branch commit report success for both connected project checks. The preview has not yet been visually inspected with the owner's authenticated session.
- Real owner sign-in remains untested because the owner's password is not available to the development process. No production merge or production deployment was requested or performed.
