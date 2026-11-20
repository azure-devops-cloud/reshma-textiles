-- Reshma Textiles ERP — remove the isolated DEMO dataset only.
-- Review the IDs before running. This does not touch live business records.
begin;

delete from public.sales_invoice_payments
where invoice_id = 'ecc6fa49-5727-488e-b994-a11e271eb481';

delete from public.sales_invoice_items
where invoice_id = 'ecc6fa49-5727-488e-b994-a11e271eb481';

delete from public.sales_invoices
where id = 'ecc6fa49-5727-488e-b994-a11e271eb481'
  and notes like 'DEMO ONLY%';

delete from public.supplier_bill_payments
where bill_id = 'd0000000-0000-4000-8000-000000000012';

delete from public.supplier_bills
where id = 'd0000000-0000-4000-8000-000000000012'
  and notes like 'DEMO ONLY%';

delete from public.manufacturing_costs
where batch_id = 'd0000000-0000-4000-8000-000000000009'
  and description like '[DEMO]%';

delete from public.production_batch_operations
where batch_id = 'd0000000-0000-4000-8000-000000000009'
  and notes like 'DEMO ONLY%';

delete from public.material_consumption
where batch_id = 'd0000000-0000-4000-8000-000000000009';

delete from public.quality_checks
where batch_id = 'd0000000-0000-4000-8000-000000000009';

delete from public.inventory_movements
where variant_id in (
  'd0000000-0000-4000-8000-000000000006',
  'd0000000-0000-4000-8000-000000000007'
);

delete from public.production_batches
where id = 'd0000000-0000-4000-8000-000000000009'
  and batch_number = 'DEMO-BATCH-001';

delete from public.goods_receipt_items
where goods_receipt_id = '257b997b-3c10-41ff-8d1e-0a976c17d4e8';

delete from public.goods_receipts
where id = '257b997b-3c10-41ff-8d1e-0a976c17d4e8'
  and notes like 'DEMO ONLY%';

delete from public.purchase_order_items
where purchase_order_id = '84fab749-4192-4635-9450-260ab2bc76d5';

delete from public.purchase_orders
where id = '84fab749-4192-4635-9450-260ab2bc76d5'
  and notes like 'DEMO ONLY%';

delete from public.raw_material_movements
where material_id in (
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000003'
);

delete from public.product_variants
where id in (
  'd0000000-0000-4000-8000-000000000006',
  'd0000000-0000-4000-8000-000000000007'
);

delete from public.products
where id = 'd0000000-0000-4000-8000-000000000005'
  and name like '[DEMO]%';

delete from public.categories
where id = 'd0000000-0000-4000-8000-000000000004'
  and name like '[DEMO]%';

delete from public.raw_materials
where id in (
  'd0000000-0000-4000-8000-000000000002',
  'd0000000-0000-4000-8000-000000000003'
)
and name like '[DEMO]%';

delete from public.business_customers
where id = 'd0000000-0000-4000-8000-000000000008'
  and notes like 'DEMO DATA ONLY%';

delete from public.suppliers
where id = 'd0000000-0000-4000-8000-000000000001'
  and notes like 'DEMO DATA ONLY%';

commit;
