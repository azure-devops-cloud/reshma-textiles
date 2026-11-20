# Reshma Textiles ERP — Business Blueprint (Phase 0–6)

**Status:** Implementation baseline; validate against actual factory practices before live transactions.  
**Business model:** Own-manufacturing lungi business.  
**Architecture:** Existing storefront remains separate from the authenticated ERP workspace. PostgreSQL/Supabase is the system of record.

## 1. Operating principles
- One source of truth for products, variants, stock, production, customers, invoices and payments.
- No demo transactions or fabricated supplier/customer/product/tax records.
- Stock changes only through posted receipts, material issues, accepted production output, dispatch/sales and authorised adjustments.
- Posted documents are not silently overwritten; corrections use reversals/credit notes or controlled adjustments.
- Every sensitive action is attributable to an authenticated user and timestamp.
- GST identifiers, HSN codes, rates, legal names and addresses must be verified business data. Placeholder values must never permit tax invoice issuance.
- AI is advisory by default. It cannot post stock, issue invoices, approve payments or change master data without explicit human confirmation.

## 2. End-to-end workflow
1. Product/design master → category, design, fabric, colour/size/length variants, SKU, HSN/GST metadata.
2. Procurement → supplier → purchase order → goods receipt → accepted/rejected quantities → raw-material ledger.
3. Production → work order/batch → configurable operations (in-house or job-work) → material issue → labour/processing/overhead costs.
4. Quality → checked, accepted, rejected and rework quantities → approved output.
5. Finished goods → variant-level stock ledger and batch traceability.
6. Sales → customer → quotation/order → invoice draft → tax/stock validation → issue → payment → dispatch.
7. Finance → supplier bills/payments, expenses, customer receivables, supplier payables and management reports.

## 3. Module requirements

### Phase 1 — Foundation
- Secure sign-in, session handling, admin bootstrap and role/permission model.
- Business settings, product/category/variant masters, supplier/customer masters.
- Dashboard with empty-state-safe metrics.
- Audit trail for privileged business actions.

### Phase 2 — Procurement and inventory
- Supplier master and payment terms.
- Purchase orders with line items, ordered/received/balance quantities and statuses.
- Goods receipt notes with accepted/rejected quantities; posting is atomic and idempotent.
- Raw-material movement ledger, reorder levels and stock valuation.
- No direct manual balance edits in ordinary workflows.

### Phase 3 — Manufacturing
- Production batches/work orders with planned and actual output.
- Configurable operation routing; each operation can be in-house or assigned to a job-work supplier.
- Material issue linked to a batch and raw-material movement.
- Labour, processing, electricity, packaging and overhead cost capture.
- Batch-level actual cost and cost per accepted unit.

### Phase 4 — Quality and finished goods
- Quality checks with checked, accepted, rejected and rework quantities.
- Only accepted quantity enters finished-goods stock.
- Finished stock by SKU/variant and traceability to the originating batch.
- Rework remains a tracked operation, not silently counted as accepted output.

### Phase 5 — Sales and invoicing
- Retail/wholesale customer register and pricing.
- Quotation/order capture, invoice draft, payment receipts and dispatch details.
- Invoice issue is a controlled transaction: validates seller/customer/tax data, HSN, supply type, tax split and stock before assigning a number and posting stock.
- GST particulars remain blocked until verified; no fake GSTIN or HSN values.

### Phase 6 — Finance and reporting
- Expense register and supporting references.
- Supplier bills, supplier payments and outstanding payables.
- Customer invoices, receipts and outstanding receivables.
- Inventory valuation, production cost, gross margin, sales, expenses and cash movement reports.
- Reports distinguish posted transactions from drafts.

## 4. Roles and permissions
Initial production access remains restricted to the trusted administrator until named staff and responsibilities are confirmed. Target roles:
- Owner/Admin: all modules, settings, user access and approvals.
- Manager: operational oversight and approvals.
- Procurement/Stores: suppliers, POs, GRNs and stock.
- Production: work orders, material issues and operation updates.
- Quality: inspections and accepted/rejected quantities.
- Sales: customers, quotations, orders and dispatch.
- Accounts: invoices, payments, supplier bills, expenses and reports.
- Read-only: approved reports only.

Least privilege is required. Do not infer permissions from user-editable profile metadata.

## 5. Data integrity and controls
- PostgreSQL constraints and row-level security on every exposed table.
- Transactional database functions for posting receipts, issuing materials, completing batches, issuing invoices and recording payments.
- Row locks on balances during posting; prevent negative stock and overpayments.
- Immutable stock movement and audit records.
- Unique document numbers with transaction-safe sequence allocation.
- Server-side validation is authoritative; browser checks are convenience only.
- Backups/export and migration scripts are maintained in source control.

## 6. AI-ready design
Future assistant capabilities: reorder forecasting, purchase suggestions, production scheduling, batch yield/cost analysis, receivables follow-up drafts and anomaly detection. AI receives scoped read access and proposes actions. Human approval is required before any write or external communication.

## 7. Decisions intentionally configurable
The precise in-house vs outsourced stages, stage sequence, job-work partners, costing method, employee/payroll scope, payment approval limits and invoice policy are configurable rather than hard-coded. The ERP must not assume that weaving, dyeing, printing or finishing are all performed internally.

## 8. Acceptance checklist
- Admin login survives refresh and logout invalidates the UI session.
- Non-admin users cannot access ERP records or privileged RPCs.
- Failed or repeated posting cannot double-change stock.
- GRN accepted quantity increases stock once; material issue decreases it once.
- Production completion adds accepted units only.
- Invoice issue fails safely when seller tax details are missing or stock is insufficient.
- Payment cannot exceed the outstanding amount.
- Drafts do not affect stock or financial reports.
- Reports reconcile to posted ledgers.
- Empty database states render clearly without invented records.


## Application access model
The application is a private ERP PWA, not a public storefront. The root route presents owner sign-in. The initial account is the owner/admin; supplier, customer and employee records do not imply login accounts. Future staff roles are a separate phase after workflows and permissions are agreed. No public catalogue, shopping cart or public enquiry intake is in scope.
