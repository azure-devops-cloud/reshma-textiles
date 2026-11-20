import fs from "node:fs";

const html = fs.readFileSync("index.html", "utf8");
const app = fs.readFileSync("app.js", "utf8");
const manifest = JSON.parse(fs.readFileSync("manifest.webmanifest", "utf8"));
const sw = fs.readFileSync("sw.js", "utf8");

const ids = [...html.matchAll(/\sid=["']([^"']+)["']/g)].map(match => match[1]);
const duplicates = ids.filter((id, index) => ids.indexOf(id) !== index);
if (duplicates.length) throw new Error("Duplicate HTML IDs: " + [...new Set(duplicates)].join(", "));

const requiredIds = [
  "erpLoginGate", "erpLoginForm", "erpLoginStatus", "erpAppShell",
  "erpSidebar", "erpContentMount", "erpSignOut", "erpInstallApp",
  "businessWorkspace", "opsMetricMaterials", "opsMetricSuppliers",
  "opsMetricBatches", "opsMetricInvoices", "materialForm", "supplierForm",
  "purchaseOrderForm", "receiptForm", "variantForm", "customerForm",
  "invoiceForm", "expenseForm", "supplierBillForm", "settingForm"
];
const missing = requiredIds.filter(id => !ids.includes(id));
if (missing.length) throw new Error("Missing required ERP elements: " + missing.join(", "));
if (!html.includes('<link rel="manifest" href="/manifest.webmanifest">')) throw new Error("PWA manifest link missing");
if (!app.includes('signInWithPassword')) throw new Error("Owner sign-in handler missing");
if (!app.includes('profile?.role!=="admin"')) throw new Error("Owner/admin authorization check missing");
if (!app.includes('navigator.serviceWorker.register("/sw.js")')) throw new Error("Service worker registration missing");
if (!manifest.name || manifest.start_url !== "/" || manifest.display !== "standalone" || !manifest.icons?.length) throw new Error("PWA manifest is incomplete");
if (!sw.includes("APP_SHELL") || sw.includes("service_role")) throw new Error("Unexpected service worker configuration");
if (/service_role|sb_secret_/i.test(html + app)) throw new Error("A privileged Supabase key must never be shipped to the browser");

console.log("ERP validation passed: unique IDs, required modules, owner-only login and PWA shell.");
