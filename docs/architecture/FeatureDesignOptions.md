# Core admin portal functionality

## 1. Dashboard

A landing page showing the stuff that matters right now: new orders, low stock, failed payments, top products, revenue
snapshots, and tasks needing attention. This is a standard in commerce admin tools because store operators need an
operational summary the moment they log in.

## 2. Product management

Create, edit, archive, and organize products. This usually includes product name, SKU, description, price, images,
status, brand, category, and product type. This is one of the absolute foundations of the admin.

## 3. Category and collection management

Group products into categories, collections, or catalog structures so the storefront can display them cleanly and
customers can browse without wanting to throw their laptop out the window.

## 4. Brand management

Manage brands or manufacturers linked to products. Since your platform already supports brands, keep this as a
first-class admin area with logo, status, SEO text, and brand-to-product mapping. This is common in catalog-heavy
commerce back offices.

## 5. Inventory management

Track stock levels, availability, low-stock alerts, inventory changes, and whether items can be oversold or back
ordered. Product admin in mainstream platforms includes inventory handling because catalog without stock control
is just decorative lying.

## 6. Pricing management

Manage base price, compare-at price, cost, sale pricing, and customer-group or channel-specific pricing if needed
later. Commercetools and other platforms treat prices and discounts as separate but core admin capabilities.

## 7. Bulk import and export

CSV or spreadsheet import/export for products, stock, pricing, and maybe customers/orders. This is essential for real
stores because nobody wants to edit 4,000 products one modal at a time like it’s a punishment from the gods. Shopify
and BigCommerce both support admin-side data operations and CSV-style workflows in multiple areas.

## 8. Media management

Upload, map, replace, and remove product images and possibly other assets like brand logos or banners. Since you
already support SKU-mapped bulk image uploads, this should stay in your MVP.

## 9. Order management

View orders, filter by status, inspect line items, update statuses, capture payments, cancel, refund, print invoices,
and create manual orders if needed. Order processing is one of the central admin jobs in commercial platforms.

## 10. Fulfillment and shipping operations

Pick, pack, fulfill, generate tracking, mark shipped, handle delivery states, and manage shipping methods or
shipping rates. Shopify explicitly treats fulfillment and shipping as built-in operational admin capabilities.

## 11. Customer management

View customer profiles, contact details, addresses, order history, notes, tags, and support-related context.
BigCommerce and Shopify both include customer management and customer reporting inside admin tooling.

## 12. Promotions and discounts

Create discount codes, automatic discounts, cart discounts, product discounts, shipping discounts, and promotion
rules. This is core retail functionality, not a nice-to-have.

## 13. Tax configuration

Configure tax rules, tax-inclusive or tax-exclusive pricing behavior, tax-exempt products or customers, and
region-specific tax settings. Tax settings are standard store-admin configuration because they affect checkout,
order totals, and reporting.

## 14. Payment and finance visibility

View payment status, payment methods, refunds, gift card usage if supported, and finance summaries. Shopify’s
finance reporting shows how payment and financial information is treated as part of store administration and
reporting.

## 15. Shipping settings

Configure shipping zones, delivery methods, shipping fees, free-shipping thresholds, carrier rules, and possibly
courier integrations. This belongs in admin because it directly affects checkout and fulfillment logic.

## 16. User roles and permissions

Admin users should not all be mini-gods with access to everything. You need roles like super admin, catalog manager,
order manager, finance viewer, and support staff. Shopify’s admin permissions model is a good example of separating
access by functional area.

## 17. Analytics and reporting

Sales, orders, customers, best sellers, conversion-adjacent business reports, tax summaries, and operational
reports. Major platforms include reporting because merchants need to measure what is selling, what is stalling, and
where money is leaking.

## 18. Store settings

General business settings like store name, contact info, currency, locale, tax defaults, email settings, shipping
defaults, and branding-related configuration. BigCommerce and Shopify both treat these as core control-panel/admin
concerns.
Very useful functionality you should strongly consider

## 19. Content management for storefront

Manage homepage banners, promo blocks, navigation menus, static pages, SEO fields, and brand/category landing
content. Since your storefront must be customized per client, this becomes very important. Shopify’s admin includes
content and menu permissions because storefront content is part of day-to-day operations.

## 20. Search, filters, and saved views

Every major admin screen should have strong filtering, sorting, search, and export. This becomes essential once
product, order, and customer counts grow. Commerce admin tools expose these controls heavily because scale makes
manual browsing useless fast.

## 21. Audit trail / activity log

Track who changed products, prices, orders, shipping settings, tax rules, and promotions. This is especially useful
once multiple staff members are using the portal. It also saves you from the classic “I didn’t change that” ghost
story.

## 22. Notifications and alerts

Low stock alerts, failed order alerts, payment failures, import errors, sync failures, and fulfillment issues.
Admins need to know when something is broken before the customer does.

## 23. Returns and refunds

If you support post-purchase operations properly, you need return requests, refund handling, return statuses, and
notes.

## 24. Manual order creation

Useful for phone orders, WhatsApp orders, support-assisted orders, or special cases. BigCommerce explicitly supports
creating manual orders from the control panel.

## 25. API keys / integrations management

A settings area for delivery providers, payment gateways, email providers, accounting, ERP, or webhook endpoints.
Since you mentioned shipping and tax settings, this becomes important quickly.
If you want this to be resellable as a platform, 
Add these platform-level capabilities:

## 26. Tenant / client management

Each client should have their own:

- branding
- domain settings
- tax config
- shipping config
- payment config
- users
- catalog scope
- storefront theme/settings

That is what starts turning your project into a real reusable platform instead of one giant custom build wearing
different hats.

## 27. Theme and branding configuration

Let the admin manage logo, colors, fonts, homepage sections, banner images, footer content, and maybe layout presets
for the storefront. Since one of your goals is client-specific storefront design, this is a big one.

## 28. Feature flags / module toggles

Allow some clients to enable or disable modules like discounts, gift cards, pickup, delivery integrations, or
advanced reporting.

## 29. Multi-store / multi-channel readiness

If a client later wants multiple storefronts, branches, or sales channels, your admin should be built so this is
possible without rewriting the planet.