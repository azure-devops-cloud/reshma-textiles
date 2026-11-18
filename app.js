const config=window.RESHMA_CONFIG||{};const hasConfig=Boolean(config.supabaseUrl&&config.supabasePublishableKey);let supabase=null;let isSignUp=false;if(hasConfig){const{createClient}=await import("https://esm.sh/@supabase/supabase-js@2");supabase=createClient(config.supabaseUrl,config.supabasePublishableKey)}const grid=document.querySelector("#productGrid"),statusEl=document.querySelector("#catalogueStatus");document.querySelector("#year").textContent=new Date().getFullYear();function esc(v=""){return String(v).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]))}function card(p){const price=Number(p.retail_price)>0?new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:0}).format(p.retail_price):"Ask for price";return `<article class="product-card">${p.image_url?`<img src="${esc(p.image_url)}" alt="${esc(p.name)}" loading="lazy">`:'<div class="product-art plaid plum"></div>'}<div class="product-info"><span class="tag">${esc(p.categories?.name||"RESHMA COLLECTION")}</span><h3>${esc(p.name)}</h3><p>${esc(p.description||p.design||"Made for everyday comfort")}</p><strong>${price}</strong></div></article>`}async function loadProducts(){if(!supabase){statusEl.textContent="The live catalogue is temporarily unavailable. Please contact us for current designs.";grid.innerHTML='<div class="catalogue-empty"><strong>Our collection is being prepared.</strong><span>Contact us for current designs, availability and prices.</span><a href="#contact">Make an enquiry ↗</a></div>';document.querySelector("#productCount").textContent="COMING SOON";return}statusEl.textContent="Loading catalogue…";const{data,error}=await supabase.from("products").select("id,name,description,design,image_url,retail_price,categories(name)").eq("is_active",true).order("created_at",{ascending:false});if(error){statusEl.textContent="Catalogue is temporarily unavailable. Please contact us for current designs.";grid.innerHTML='<div class="catalogue-empty"><strong>We are preparing the live collection.</strong><span>Please contact us for current designs and availability.</span><a href="#contact">Make an enquiry ↗</a></div>';console.error(error.message);return}if(!data?.length){statusEl.textContent="";grid.innerHTML='<div class="catalogue-empty"><strong>Our first collection is being prepared.</strong><span>Contact us for current designs, availability and prices.</span><a href="#contact">Make an enquiry ↗</a></div>';document.querySelector("#productCount").textContent="COMING SOON";return}grid.innerHTML=data.map(card).join("");document.querySelector("#productCount").textContent=data.length+" designs";statusEl.remove()}loadProducts();document.querySelector("#accountBtn").addEventListener("click",()=>document.querySelector("#accountDialog").showModal());document.querySelector("#authToggle").addEventListener("click",()=>{isSignUp=!isSignUp;document.querySelector("#authTitle").textContent=isSignUp?"Create account":"Sign in";document.querySelector("#authSubmit").textContent=isSignUp?"Create account":"Sign in";document.querySelector("#authToggle").textContent=isSignUp?"Already registered? Sign in":"New here? Create an account"});document.querySelector("#authForm").addEventListener("submit",async e=>{e.preventDefault();const f=new FormData(e.currentTarget),msg=document.querySelector("#authStatus");if(!supabase){msg.textContent="Sign-in will be available after Supabase keys are configured.";return}msg.textContent="Please wait…";const r=isSignUp?await supabase.auth.signUp({email:f.get("email"),password:f.get("password")}):await supabase.auth.signInWithPassword({email:f.get("email"),password:f.get("password")});if(r.error){msg.textContent=r.error.message;return}msg.textContent=isSignUp?"Account created. Check your email if confirmation is enabled.":"You are signed in.";if(!isSignUp){document.querySelector("#accountBtn").textContent="My account";setTimeout(()=>document.querySelector("#accountDialog").close(),900)}});if(supabase)supabase.auth.getUser().then(({data})=>{if(data.user)document.querySelector("#accountBtn").textContent="My account"});document.querySelector("#enquiryForm").addEventListener("submit",async e=>{e.preventDefault();const form=e.currentTarget,f=new FormData(form),status=document.querySelector("#enquiryStatus"),submit=form.querySelector('button[type="submit"]');if(!supabase){status.textContent="We couldn't connect to the enquiry service. Please try again later.";return}const name=String(f.get("name")||"").trim(),phone=String(f.get("phone")||"").trim(),type=String(f.get("type")||"Retail purchase"),message=String(f.get("message")||"").trim();if(name.length<2||phone.length<7){status.textContent="Please enter your name and a valid phone number.";return}submit.disabled=true;submit.textContent="Saving your enquiry…";status.textContent="";try{const{error}=await supabase.from("customer_enquiries").insert({customer_name:name,phone,enquiry_type:type,message:message||null});if(error)throw error;form.reset();status.textContent="Thank you! Your enquiry has been saved. Our team will contact you soon.";status.scrollIntoView({behavior:"smooth",block:"nearest"})}catch(error){console.error("Enquiry submission failed:",error);status.textContent="We couldn't save your enquiry right now. Please try again in a moment."}finally{submit.disabled=false;submit.innerHTML='Send your enquiry <span>↗</span>'}});
const adminPanel=document.querySelector("#adminInbox"),productManager=document.querySelector("#productManager"),adminLink=document.querySelector("#enquiriesBtn"),adminStatus=document.querySelector("#adminStatus"),enquiryList=document.querySelector("#enquiryList");
let adminRows=[],adminReady=false;
const statusLabels={new:"New",contacted:"Contacted",in_progress:"In progress",converted:"Converted",closed:"Closed"};
function dateLabel(v){return new Intl.DateTimeFormat("en-IN",{dateStyle:"medium",timeStyle:"short"}).format(new Date(v))}
function csvCell(v){return '"'+String(v??"").replace(/"/g,'""')+'"'}
function renderAdminRows(){
 const term=(document.querySelector("#enquirySearch").value||"").trim().toLowerCase(),filter=document.querySelector("#enquiryFilter").value;
 const rows=adminRows.filter(r=>(filter==="all"||r.status===filter)&&(!term||[r.customer_name,r.phone,r.message,r.enquiry_type].some(v=>String(v||"").toLowerCase().includes(term))));
 enquiryList.innerHTML=rows.length?rows.map(r=>`<article class="enquiry-card"><div class="enquiry-card-main"><div class="enquiry-card-head"><span class="enquiry-type">${esc(r.enquiry_type)}</span><time>${esc(dateLabel(r.created_at))}</time></div><h3>${esc(r.customer_name)}</h3><a class="enquiry-phone" href="tel:${esc(r.phone.replace(/[^+0-9]/g,""))}">${esc(r.phone)}</a><p>${esc(r.message||"No additional message provided.")}</p></div><div class="enquiry-card-side"><span class="status-pill status-${esc(r.status)}">${esc(statusLabels[r.status]||r.status)}</span><label>Update status<select class="status-update" aria-label="Update status for ${esc(r.customer_name)}" data-id="${esc(r.id)}">${Object.entries(statusLabels).map(([k,v])=>`<option value="${k}" ${r.status===k?"selected":""}>${v}</option>`).join("")}</select></label></div></article>`).join(""):'<div class="admin-empty">No enquiries match this view yet.</div>';
 document.querySelector("#metricTotal").textContent=adminRows.length;
 document.querySelector("#metricNew").textContent=adminRows.filter(r=>r.status==="new").length;
 document.querySelector("#metricProgress").textContent=adminRows.filter(r=>r.status==="in_progress").length;
 document.querySelector("#metricConverted").textContent=adminRows.filter(r=>r.status==="converted").length;
}
async function checkAdmin(){
 if(!supabase)return;
 const{data:{user}}=await supabase.auth.getUser();
 if(!user){adminReady=false;adminLink.hidden=true;adminPanel.hidden=true;productManager.hidden=true;document.querySelector("#signOutBtn").hidden=true;return}
 document.querySelector("#signOutBtn").hidden=false;
 const{data:profile,error}=await supabase.from("profiles").select("role").eq("id",user.id).maybeSingle();
 adminReady=!error&&profile?.role==="admin";
 adminLink.hidden=!adminReady;
 if(!adminReady){adminPanel.hidden=true;productManager.hidden=true;return}
 adminPanel.hidden=false;productManager.hidden=false;await Promise.all([loadEnquiries(),loadAdminProducts()]);
}
async function loadEnquiries(){
 if(!adminReady)return;
 adminStatus.textContent="Loading enquiries…";
 const{data,error}=await supabase.from("customer_enquiries").select("id,customer_name,phone,enquiry_type,message,status,created_at").order("created_at",{ascending:false}).limit(200);
 if(error){adminStatus.textContent="Unable to load enquiries. Please refresh your session and try again.";console.error("Admin enquiry load failed:",error);return}
 adminRows=data||[];adminStatus.textContent=adminRows.length===200?"Showing the latest 200 enquiries.":adminRows.length+" enquiries loaded.";renderAdminRows();
}
adminLink.addEventListener("click",()=>{adminPanel.hidden=false;adminPanel.scrollIntoView({behavior:"smooth",block:"start"})});
document.querySelector("#refreshEnquiries").addEventListener("click",loadEnquiries);
document.querySelector("#enquirySearch").addEventListener("input",renderAdminRows);
document.querySelector("#enquiryFilter").addEventListener("change",renderAdminRows);
enquiryList.addEventListener("change",async e=>{
 const select=e.target.closest(".status-update");if(!select||!adminReady)return;
 const id=select.dataset.id,next=select.value;select.disabled=true;
 const{data,error}=await supabase.from("customer_enquiries").update({status:next}).eq("id",id).select("id,status").single();
 if(error){adminStatus.textContent="Status update failed. Please refresh and try again.";console.error(error);select.disabled=false;return}
 const row=adminRows.find(r=>r.id===id);if(row)row.status=data.status;adminStatus.textContent="Enquiry status updated.";renderAdminRows();
});
document.querySelector("#exportEnquiries").addEventListener("click",()=>{
 if(!adminReady)return;
 const cols=["created_at","customer_name","phone","enquiry_type","message","status"];
 const csv=[cols.join(","),...adminRows.map(r=>cols.map(k=>csvCell(r[k])).join(","))].join("\r\n");
 const url=URL.createObjectURL(new Blob(["\ufeff"+csv],{type:"text/csv;charset=utf-8"})),a=document.createElement("a");a.href=url;a.download="reshma-textiles-enquiries.csv";a.click();URL.revokeObjectURL(url);
});
document.querySelector("#signOutBtn").addEventListener("click",async()=>{
 const{error}=await supabase.auth.signOut();if(error){document.querySelector("#authStatus").textContent=error.message;return}
 document.querySelector("#accountBtn").textContent="Account ↗";document.querySelector("#authStatus").textContent="You are signed out.";document.querySelector("#signOutBtn").hidden=true;adminLink.hidden=true;adminPanel.hidden=true;
});

const productForm=document.querySelector("#productForm"),adminProductList=document.querySelector("#adminProductList"),productAdminStatus=document.querySelector("#productAdminStatus");
let adminProducts=[];
function slugify(v){return String(v||"").toLowerCase().normalize("NFKD").replace(/[\\u0300-\\u036f]/g,"").replace(/[^a-z0-9]+/g,"-").replace(/^-|-$/g,"")}
async function loadAdminProducts(){
 if(!adminReady)return;
 productAdminStatus.textContent="Loading products…";
 const{data,error}=await supabase.from("products").select("id,name,slug,sku,fabric,design,description,image_url,retail_price,wholesale_price,min_wholesale_qty,is_active,created_at").order("created_at",{ascending:false}).limit(200);
 if(error){productAdminStatus.textContent="Could not load products. Check your admin session.";console.error(error);return}
 adminProducts=data||[];productAdminStatus.textContent=adminProducts.length+" products loaded.";
 adminProductList.innerHTML=adminProducts.length?adminProducts.map(p=>'<article class="admin-product-card"><div><span class="status-pill '+(p.is_active?"status-converted":"status-closed")+'">'+(p.is_active?"Published":"Draft")+'</span><h3>'+esc(p.name)+'</h3><p>'+esc([p.sku,p.fabric,p.design].filter(Boolean).join(" · ")||"No product code or details")+'</p><small>Retail ₹'+Number(p.retail_price||0).toLocaleString("en-IN")+' · Wholesale ₹'+Number(p.wholesale_price||0).toLocaleString("en-IN")+' · Min. '+esc(p.min_wholesale_qty)+' pcs</small></div><div class="admin-product-actions"><button class="text-link" type="button" data-product-edit="'+esc(p.id)+'">Edit</button><button class="text-link" type="button" data-product-toggle="'+esc(p.id)+'">'+(p.is_active?"Unpublish":"Publish")+'</button></div></article>').join(""):'<div class="admin-empty">No products added yet. Use the form above to create your first product.</div>';
}
function resetProductForm(){productForm.reset();productForm.elements.id.value="";productForm.elements.retail_price.value="0";productForm.elements.wholesale_price.value="0";productForm.elements.min_wholesale_qty.value="10";document.querySelector("#saveProductBtn").textContent="Save product";document.querySelector("#cancelProductEdit").hidden=true}
productForm.addEventListener("submit",async e=>{
 e.preventDefault();if(!adminReady)return;
 const f=new FormData(productForm),id=String(f.get("id")||""),name=String(f.get("name")||"").trim(),sku=String(f.get("sku")||"").trim();
 const payload={name,slug:slugify(name)+(sku?"-"+slugify(sku):""),sku:sku||null,fabric:String(f.get("fabric")||"").trim()||null,design:String(f.get("design")||"").trim()||null,description:String(f.get("description")||"").trim()||null,image_url:String(f.get("image_url")||"").trim()||null,retail_price:Number(f.get("retail_price")),wholesale_price:Number(f.get("wholesale_price")),min_wholesale_qty:Number(f.get("min_wholesale_qty")),is_active:f.get("is_active")==="on"};
 if(!name||![payload.retail_price,payload.wholesale_price].every(v=>Number.isFinite(v)&&v>=0)||!Number.isInteger(payload.min_wholesale_qty)||payload.min_wholesale_qty<1){productAdminStatus.textContent="Check the product name, prices and minimum quantity.";return}
 const submit=document.querySelector("#saveProductBtn");submit.disabled=true;productAdminStatus.textContent=id?"Updating product…":"Saving product…";
 const result=id?await supabase.from("products").update(payload).eq("id",id).select("id").single():await supabase.from("products").insert(payload).select("id").single();
 submit.disabled=false;
 if(result.error){productAdminStatus.textContent="Could not save product: "+result.error.message;return}
 resetProductForm();productAdminStatus.textContent="Product saved.";await Promise.all([loadAdminProducts(),loadProducts()]);
});
adminProductList.addEventListener("click",async e=>{
 const edit=e.target.closest("[data-product-edit]"),toggle=e.target.closest("[data-product-toggle]");
 if(edit){const p=adminProducts.find(x=>x.id===edit.dataset.productEdit);if(!p)return;for(const k of ["id","name","sku","fabric","design","description","image_url","retail_price","wholesale_price","min_wholesale_qty"])productForm.elements[k].value=p[k]??"";productForm.elements.is_active.checked=p.is_active;document.querySelector("#saveProductBtn").textContent="Update product";document.querySelector("#cancelProductEdit").hidden=false;productForm.scrollIntoView({behavior:"smooth",block:"start"});return}
 if(toggle){const p=adminProducts.find(x=>x.id===toggle.dataset.productToggle);if(!p||!adminReady)return;toggle.disabled=true;const{error}=await supabase.from("products").update({is_active:!p.is_active}).eq("id",p.id);if(error){productAdminStatus.textContent="Could not change publish status: "+error.message;toggle.disabled=false;return}productAdminStatus.textContent=p.is_active?"Product unpublished.":"Product published.";await Promise.all([loadAdminProducts(),loadProducts()]);}
});
document.querySelector("#cancelProductEdit").addEventListener("click",resetProductForm);
document.querySelector("#refreshProducts").addEventListener("click",loadAdminProducts);

if(supabase)supabase.auth.onAuthStateChange((event)=>{if(["SIGNED_IN","INITIAL_SESSION","TOKEN_REFRESHED"].includes(event))setTimeout(checkAdmin,0);if(event==="SIGNED_OUT")checkAdmin()});
