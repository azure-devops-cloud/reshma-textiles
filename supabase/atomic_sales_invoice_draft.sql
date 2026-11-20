create or replace function public.create_sales_invoice_draft(
  p_header jsonb,
  p_items jsonb
) returns uuid
language plpgsql
set search_path = 'public'
as $$
declare
  v_invoice_id uuid;
  v_customer_id uuid;
  v_customer public.business_customers%rowtype;
  v_variant public.product_variants%rowtype;
  v_settings public.business_settings%rowtype;
  v_line jsonb;
  v_product_name text;
  v_invoice_type text;
  v_supply_type text;
  v_customer_name text;
  v_quantity numeric;
  v_unit_price numeric;
  v_discount numeric;
  v_gst_rate numeric;
  v_taxable numeric;
  v_tax numeric;
  v_cgst_rate numeric;
  v_sgst_rate numeric;
  v_igst_rate numeric;
  v_cgst numeric;
  v_sgst numeric;
  v_igst numeric;
  v_subtotal numeric := 0;
  v_total_taxable numeric := 0;
  v_total_cgst numeric := 0;
  v_total_sgst numeric := 0;
  v_total_igst numeric := 0;
  v_total numeric := 0;
  v_hsn text;
  v_line_count integer := 0;
begin
  if not (select private.is_admin()) then raise exception 'Admin access required'; end if;
  if p_header is null or jsonb_typeof(p_header) <> 'object' then raise exception 'Invoice details are required'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Add at least one invoice line'; end if;
  if jsonb_array_length(p_items) > 200 then raise exception 'An invoice cannot contain more than 200 lines'; end if;

  v_invoice_type := coalesce(nullif(p_header->>'invoice_type',''),'retail');
  if v_invoice_type not in ('retail','wholesale') then raise exception 'Select a valid invoice type'; end if;
  v_supply_type := coalesce(nullif(p_header->>'supply_type',''),'unknown');
  if v_supply_type not in ('intra_state','inter_state','unknown') then raise exception 'Select a valid supply type'; end if;

  v_customer_id := nullif(p_header->>'customer_id','')::uuid;
  if v_customer_id is not null then
    select * into v_customer from public.business_customers where id=v_customer_id and is_active=true;
    if not found then raise exception 'Selected customer is inactive or unavailable'; end if;
    v_customer_name := v_customer.name;
  else
    v_customer_name := nullif(btrim(p_header->>'customer_name'),'');
  end if;
  if v_customer_name is null then raise exception 'Customer name is required'; end if;

  select * into v_settings from public.business_settings where id=true;
  insert into public.sales_invoices(
    invoice_type,invoice_date,due_date,customer_id,customer_name,customer_phone,customer_email,
    customer_gstin,billing_address,shipping_address,place_of_supply,place_of_supply_code,supply_type,
    status,subtotal,taxable_value,cgst_amount,sgst_amount,igst_amount,total_tax,grand_total,balance_due,
    notes,terms,seller_snapshot,created_by
  ) values (
    v_invoice_type,coalesce(nullif(p_header->>'invoice_date','')::date,current_date),
    nullif(p_header->>'due_date','')::date,v_customer_id,v_customer_name,
    case when v_customer_id is not null then v_customer.phone else nullif(btrim(p_header->>'customer_phone'),'') end,
    case when v_customer_id is not null then v_customer.email else nullif(btrim(p_header->>'customer_email'),'') end,
    case when v_customer_id is not null then v_customer.gstin else nullif(btrim(p_header->>'customer_gstin'),'') end,
    case when v_customer_id is not null then v_customer.billing_address else nullif(btrim(p_header->>'billing_address'),'') end,
    case when v_customer_id is not null then v_customer.shipping_address else nullif(btrim(p_header->>'shipping_address'),'') end,
    nullif(btrim(p_header->>'place_of_supply'),''),nullif(btrim(p_header->>'place_of_supply_code'),''),
    v_supply_type,'draft',0,0,0,0,0,0,0,0,nullif(btrim(p_header->>'notes'),''),nullif(btrim(p_header->>'terms'),''),
    case when v_settings.id is true then jsonb_build_object(
      'legal_name',v_settings.legal_name,'trade_name',v_settings.trade_name,'gst_registered',v_settings.gst_registered,
      'gstin',v_settings.gstin,'registered_address',v_settings.registered_address,'state',v_settings.state,
      'state_code',v_settings.state_code,'phone',v_settings.phone,'email',v_settings.email
    ) else '{}'::jsonb end,auth.uid()
  ) returning id into v_invoice_id;

  for v_line in select value from jsonb_array_elements(p_items) as x(value)
  loop
    v_line_count := v_line_count+1;
    if nullif(v_line->>'variant_id','') is null then raise exception 'Every invoice line must select a finished-goods SKU'; end if;
    select * into v_variant from public.product_variants where id=(v_line->>'variant_id')::uuid and is_active=true;
    if not found then raise exception 'Invoice line % uses an inactive or missing SKU',v_line_count; end if;
    select name into v_product_name from public.products where id=v_variant.product_id;
    v_quantity := nullif(v_line->>'quantity','')::numeric;
    v_unit_price := nullif(v_line->>'unit_price','')::numeric;
    v_discount := coalesce(nullif(v_line->>'discount_amount','')::numeric,0);
    v_gst_rate := coalesce(nullif(v_line->>'gst_rate','')::numeric,v_variant.gst_rate,0);
    if v_quantity is null or v_quantity<=0 or v_quantity<>trunc(v_quantity) then raise exception 'Invoice line % quantity must be a positive whole number of pieces',v_line_count; end if;
    if v_unit_price is null or v_unit_price<0 or v_discount<0 or v_discount>v_quantity*v_unit_price then raise exception 'Invoice line % has an invalid price or discount',v_line_count; end if;
    if v_gst_rate<0 or v_gst_rate>100 then raise exception 'Invoice line % has an invalid GST rate',v_line_count; end if;
    v_taxable := round(v_quantity*v_unit_price-v_discount,2);
    v_tax := round(v_taxable*v_gst_rate/100,2);
    v_cgst_rate := case when v_supply_type='intra_state' then v_gst_rate/2 else 0 end;
    v_sgst_rate := v_cgst_rate;
    v_igst_rate := case when v_supply_type='inter_state' then v_gst_rate else 0 end;
    v_cgst := case when v_supply_type='intra_state' then round(v_tax/2,2) else 0 end;
    v_sgst := case when v_supply_type='intra_state' then v_tax-v_cgst else 0 end;
    v_igst := case when v_supply_type='inter_state' then v_tax else 0 end;
    v_hsn := coalesce(nullif(btrim(v_line->>'hsn_code'),''),nullif(btrim(v_variant.hsn_code),''));
    insert into public.sales_invoice_items(
      invoice_id,product_id,variant_id,product_name,sku,hsn_code,quantity,unit,unit_price,discount_amount,
      taxable_value,gst_rate,cgst_rate,sgst_rate,igst_rate,cgst_amount,sgst_amount,igst_amount,line_total
    ) values (
      v_invoice_id,v_variant.product_id,v_variant.id,v_product_name,v_variant.sku,v_hsn,v_quantity,
      coalesce(nullif(btrim(v_line->>'unit'),''),'pcs'),v_unit_price,v_discount,v_taxable,v_gst_rate,
      v_cgst_rate,v_sgst_rate,v_igst_rate,v_cgst,v_sgst,v_igst,v_taxable+v_tax
    );
    v_subtotal := v_subtotal+v_quantity*v_unit_price;
    v_total_taxable := v_total_taxable+v_taxable;
    v_total_cgst := v_total_cgst+v_cgst;
    v_total_sgst := v_total_sgst+v_sgst;
    v_total_igst := v_total_igst+v_igst;
  end loop;

  v_total := v_total_taxable+v_total_cgst+v_total_sgst+v_total_igst;
  update public.sales_invoices set subtotal=v_subtotal,discount_amount=v_subtotal-v_total_taxable,
    taxable_value=v_total_taxable,cgst_amount=v_total_cgst,sgst_amount=v_total_sgst,igst_amount=v_total_igst,
    total_tax=v_total_cgst+v_total_sgst+v_total_igst,grand_total=v_total,balance_due=v_total,updated_at=now()
  where id=v_invoice_id;
  return v_invoice_id;
end;
$$;
revoke all on function public.create_sales_invoice_draft(jsonb,jsonb) from public, anon;
grant execute on function public.create_sales_invoice_draft(jsonb,jsonb) to authenticated;