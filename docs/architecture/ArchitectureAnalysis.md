# E-Commerce Platform — Architectural Analysis

## Tech Stack Summary

| Layer             | Technology                                            |
|-------------------|-------------------------------------------------------|
| **Backend**       | Java 21, Quarkus, Hibernate ORM (Panache), PostgreSQL |
| **API**           | GraphQL (`/api/graphql`) + REST (`/api/*`) — mixed    |
| **Auth (Admin)**  | JWT (RSA key pair, SmallRye JWT)                      |
| **Payment**       | PayFast (sandbox configured), ITN webhook             |
| **Email**         | Quarkus Mailer → Gmail SMTP                           |
| **Frontend**      | React 18, TypeScript, Vite, Zustand, React Router v6  |
| **Image Storage** | Local filesystem, volume-mounted path                 |
| **DB Migrations** | Flyway (via `ec-infra`)                               |
| **Shared Module** | `ec-common` — all entities, DTOs, enums, repositories |

---

## 1. Core Domains

| Domain          | Responsibility                                              |
|-----------------|-------------------------------------------------------------|
| **Catalog**     | Products, categories, brands, variants, prices, images      |
| **Inventory**   | Stock per variant                                           |
| **Cart**        | Client-side session cart (localStorage only)                |
| **Checkout**    | Multi-step: contact → shipping → payment → confirmation     |
| **Orders**      | Order lifecycle from creation to delivery                   |
| **Customers**   | Guest, registered, and wholesaler account types             |
| **Payments**    | PayFast gateway, ITN webhook, payment audit log             |
| **Admin**       | Staff authentication, role-based access, catalog management |
| **Bulk Import** | CSV product ingestion with staged review & apply            |
| **Settings**    | Key/value store config, shipping methods, payment config    |

---

## 2. What Already Exists — Domain by Domain

### 🗂 Catalog

**Features:** `ProductService`, `BrandService`, `CategoryService`, `ImageService`

- Product → Variant → SKU model with `SIMPLE`/`VARIABLE` product types
- Category tree (self-referencing `parent_id`)
- Brand with slug + logo URL
- **4-tier pricing** per variant: `RETAIL_PRICE`, `RETAIL_SALE_PRICE`, `WHOLESALE_PRICE`, `WHOLESALE_SALE_PRICE` — all
  time-bounded via `price_start_date / price_end_date`
- Images attached to **variants** (not products), with `sortOrder` and `isFeatured`
- Product list and product detail (with variants) exposed via GraphQL
- Admin UI: Brand list/CRUD, Category list/CRUD, Product list (read-only view)

**Gap:** No product editing form in admin. Category has no image in entity (column exists in DB). No SEO-friendly
(Search Engine Optimized) product slugs. No product-level search or filtering beyond category.

---

### 🛒 Cart

**Features:** `CartStore.ts`, `localStorage`

- Cart is **entirely client-side** — items stored as JSON in `localStorage` under key `ec_cart_order_items`
- A session UUID (`cart_session_id`) is generated on first visit and persisted
- Item merge logic by `variant.id`
- Item count synced across browser tabs via `storage` events

**Gap:** No server-side cart. No cart recovery across devices. No abandoned cart tracking. No cart expiry logic.

---

### 💳 Checkout

**Features:** `Checkout.tsx`, `CustomerService.ts`, `OrderService.ts`, `StoreSettings.ts`

- Customer email lookup → guest or login inline
- Shipping method selection from `shippingMethods` GraphQL query
- Payment method selection from a JSON config in `store_settings`
- Detects in-store pickup vs. delivery address requirement
- Option to save address to customer account
- PayFast redirect: POST to `/api/payments/checkout` → returns hidden HTML form fields → submits to PayFast sandbox
- In-store payment path calls `updateOrderStatus` mutation directly
- Order synced to backend via `createOrder` GraphQL mutation

**Gap:** Shipping address captured in UI but **never persisted** (see Risk section). No coupon/discount code support. No
tax calculation. No order summary confirmation step with final price.

---

### 📦 Orders

**Features:** `OrderService.java`, `OrderResource.java` (GraphQL), `PayFastResource.java`

- Order entity tracks: customer, items, `totalAmount`, `sessionId`, `status`
- Item reconciliation on `createOrder` — upserts, removes orphans
- Order status lifecycle:
  ```
  CREATED → PENDING → PAID / IN_STORE_PAYMENT → IN_TRANSIT → DELIVERED
                   ↘ CANCELLED / FAILED / SYSTEM_CANCELED
  ```
- Confirmation email sent on `PAID` (PayFast ITN) and `IN_STORE_PAYMENT`
- `findLatestOrderInfoBySessionId` — session-keyed order lookup

**Gap:** Shipping fields (`shippingAddressLine1`, etc.) on `OrderEntity` are `@Transient` — they are **never written to
the database**. Shipping method chosen is not stored on the order. No admin order management UI (role `ORDER_MANAGER`
exists but no screen). No order history for customers.

---

### 👤 Customers

**Features:** `CustomerResource.java`, `CustomerService.ts`

- `CustomerTypeEn`: `GUEST`, `REGISTERED`, `WHOLESALER`
- Lookup by email, login, `registerOrUpdate` endpoint
- Single default shipping/billing address on customer record
- Password stored as **SHA-256 hash** (not bcrypt/argon2)

**Gap:** No JWT/session token for customer auth — the admin JWT system is not shared with customers. Wholesaler type
exists but no wholesaler-specific checkout pricing path is implemented. No password reset. No customer account portal.
No order history view.

---

### 💰 Payments

**Features:** `PayFastService.java`, `PayFastResource.java`, `PaymentLogEntity`

- Generates ordered, signed hidden form fields for PayFast redirect
- ITN webhook at `POST /api/payments/itn` → logs `PaymentLogEntity`, updates order to `PAID`
- `PaymentLogEntity` is gateway-agnostic (`gateway_name` field) — good foundation
- Raw ITN response stored for auditing

**⚠️ Critical Gap:** Signature verification is **commented out** — any POST to `/api/payments/itn` will be trusted.
`payment_method` is hardcoded to `"dc"` (debit/credit card only). No refund or chargeback handling.

---

### 🔐 Admin

**Features:** `AdminAuthResource.java`, `AdminAuthService.java`, Staff JWT roles

- Staff login → JWT signed with RSA private key
- Roles: `SUPER_ADMIN`, `CATALOG_MANAGER`, `ORDER_MANAGER`, `VIEWER`
- Admin routes protected by role authority
- Dashboard: **hardcoded mock data** (no real API calls)
- Settings page: **theme colour picker only** (no store config UI)
- No staff user management screen

---

### 📤 Bulk Import

**Features:** `ProductImportService.java`, `ProductUploadAsyncService.java`, `ProductBulkUpload.tsx`,
`ProductImportReview.tsx`

- CSV upload → parsed → staged in `product_upload_staged`
- Validation: SKU, prices, category/brand slug matching, image references
- Diff detection: `is_new_product`, `is_new_variant`, `has_changes`
- Review screen before applying
- Async processing via `ProductUploadAsyncService`
- Batch lifecycle: `IMPORTING → PENDING → PROCESSING → PROCESSED / FAILED`
- Image bulk upload (SKU-mapped) via `ImageService`

---

## 3. Missing or Underdeveloped Areas

| Area                                   | Status                     | Impact                             |
|----------------------------------------|----------------------------|------------------------------------|
| **Shipping address persistence**       | `@Transient` — never saved | 🔴 Critical — orders unfulfillable |
| **PayFast ITN signature verification** | Commented out              | 🔴 Security — fraud risk           |
| **Customer password hashing**          | SHA-256                    | 🔴 Security — use Argon2id         |
| **Admin order management**             | No screen exists           | 🔴 Operations can't manage orders  |
| **Stock reservation on checkout**      | Not implemented            | 🟠 Overselling risk                |
| **Customer account portal**            | No route or page           | 🟠 No order history                |
| **Shipping cost on order**             | Not stored                 | 🟠 Reporting inaccurate            |
| **ShippingZones**                      | In DB, not mapped          | 🟠 Zone-based pricing unusable     |
| **Wholesale checkout flow**            | Type exists, no path       | 🟠 Wholesaler sees retail prices   |
| **Coupon / discount codes**            | Not started                | 🟡 Common expectation              |
| **Tax calculation**                    | Not started                | 🟡 VAT/GST compliance              |
| **Refunds / returns**                  | Not started                | 🟡 Post-sale operations            |
| **Admin dashboard data**               | All mocked                 | 🟡 No real visibility              |
| **Staff user management**              | No UI                      | 🟡 Can't add staff via admin       |
| **Customer management in admin**       | Not started                | 🟡 No CRM capability               |
| **Product editing in admin**           | Not started                | 🟡 Must use CSV for all changes    |
| **Product search / filtering**         | Not started                | 🟡 UX gap for large catalogs       |
| **Fulfillment workflow**               | Not started                | 🟡 Courier/tracking not connected  |
| **Password reset flow**                | Not started                | 🟡 Customer self-service blocked   |

---

## 4. Core Entity Map

```
StoreSettingEntity
    key (PK), value, description

CategoryEntity
    id, name, slug, description, parent → Category (self-ref tree)

BrandEntity
    id, name, slug, logoUrl, description

ProductEntity
    id, name, description, shortDescription
    productType (SIMPLE | VARIABLE)
    → Category, → Brand

ProductVariantEntity
    id, sku (unique), stockQuantity
    attributesJson (JSONB e.g. {"color":"Red","size":"XL"})
    weightKg
    → Product

VariantPricesEntity
    id, priceType (RETAIL|RETAIL_SALE|WHOLESALE|WHOLESALE_SALE)
    price, priceStartDate, priceEndDate
    → ProductVariant

ProductImageEntity
    id, imageUrl, sortOrder, isFeatured
    → ProductVariant (NOT Product — important)

CustomerEntity
    id, email, firstName, lastName, phone
    shopperType (GUEST | REGISTERED | WHOLESALER)
    addressLine1..postalCode (single address)
    passwordHash (SHA-256)
    → Orders[]

OrderEntity
    id, sessionId, totalAmount, status
    shippingFields (@Transient — not persisted!)
    → Customer, → OrderItems[]

OrderItemEntity
    id, quantity, unitPrice (snapshot at time of purchase)
    → Order, → ProductVariant

PaymentLogEntity
    id, gatewayName, externalReference, internalReference
    amountGross, amountFee, amountNet, status, rawResponse
    → Order

ShippingMethodEntity
    id, name, isActive, baseFee, estimatedDays

StaffUserEntity
    id, username, email, passwordHash, fullName
    role (SUPER_ADMIN | CATALOG_MANAGER | ORDER_MANAGER | VIEWER)
    isActive

ProductUploadBatchEntity
    id, filename, status (IMPORTING→PENDING→PROCESSING→PROCESSED|FAILED)
    totalRows, processedRows, skippedRows, validationErrorCount
    → StaffUser (uploadedBy)

ProductUploadStagedEntity
    id, sku, name, prices, categorySlug, brandSlug, images, attributes
    validationStatus, validationErrors, isNewProduct, isNewVariant, hasChanges
    → ProductUploadBatch
```

---

## 5. System Flow Overview

```
BROWSE
  │
  ├─ GET /graphql → productList(categoryName)
  │    Returns: product id, name, description, variantIds[], images[], min prices
  │
  ├─ GET /graphql → getProductWithVariants(productId)
  │    Returns: full product + all variants + prices + images
  │
  └─ Customer selects variant → "Add to Cart"
       Cart saved to localStorage (client-side only)
       CartStore updates item count
           │
           ▼
CART PAGE (/cart)
  │
  └─ Review items, quantities, subtotal
           │
           ▼
CHECKOUT (/checkout)
  │
  ├─ createOrder mutation → syncs cart to backend Order (status: CREATED)
  ├─ Customer email lookup (REST GET /api/customers/lookup)
  │    ├─ Found + has password → inline login form
  │    └─ Not found / guest → contact info form
  ├─ updateCustomerInformation mutation → links Customer to Order
  ├─ Shipping method selected (GraphQL shippingMethods query)
  ├─ Payment method selected (from store_settings JSON)
  │
  ├─ PATH A: PayFast
  │    POST /api/payments/checkout → [HtmlFormField list]
  │    → Frontend builds hidden form → submits to PayFast sandbox
  │    → PayFast processes payment
  │    → PayFast POSTs to /api/payments/itn
  │         → PaymentLog created
  │         → Order status → PAID
  │         → Confirmation email sent
  │    → Customer redirected to /payment-success
  │
  └─ PATH B: In-store
       updateOrderStatus mutation (IN_STORE_PAYMENT)
       → Confirmation email sent
           │
           ▼
FULFILLMENT (⚠️ MANUAL — NO AUTOMATED FLOW)
  │
  └─ Admin manually updates status to IN_TRANSIT, DELIVERED
     (No screen exists for this yet)
```

---

## 6. Architecture Risks & Gaps

### 🔴 Critical — Fix Before Going Live

**1. Shipping address is `@Transient` on `OrderEntity`**
All six shipping fields (`shippingPhone`, `shippingAddressLine1`, etc.) are annotated `@Transient`. They exist in the DB
schema but are **never written**. Every order loses its delivery address the moment it is persisted. You need to either
remove `@Transient` and ensure Flyway has those columns, or move the address to a dedicated `OrderShippingAddress`
entity.

**2. PayFast ITN signature verification is commented out**
`/api/payments/itn` accepts any POST from anywhere and will mark an order as `PAID`. This is a direct fraud vector.
Uncomment and implement the signature verification before going live.

**3. SHA-256 password hashing**
SHA-256 is cryptographically broken for passwords — fast GPUs can brute-force it trivially. Migrate to Argon2id or
bcrypt (Quarkus ships `quarkus-security-jpa` with built-in bcrypt support).

---

### 🟠 High — Breaks Real Operations

**4. Cart is purely client-side**
There is no server-side cart entity. If a customer clears their browser, their cart is gone. You cannot send abandoned
cart emails. You cannot reconcile stock. The session ID model works for a simple store but will not scale to marketing
automation or multi-device shopping.

**5. No admin order management**
The `ORDER_MANAGER` role exists but there is no corresponding admin screen. No one can view, filter, update, or fulfil
orders through the admin panel without direct database access.

**6. No stock reservation**
`stockQuantity` exists on `ProductVariantEntity` but nothing decrements it on checkout or reserves it while in cart. Two
customers can buy the last unit simultaneously.

**7. Shipping method selection not persisted on the Order**
The customer selects a shipping method in checkout but no `shippingMethodId` or `shippingCost` is saved to the
`OrderEntity`. Order receipts and fulfillment have no shipping data.

---

### 🟡 Medium — Will Hurt When You Scale or Resell

**8. No customer authentication token**
Admin auth uses JWT (correct). Customer auth at `/api/customers/login` returns a profile DTO but **no token**. The
customer state in `authStore.ts` is for admin only. There is no secure, stateless customer session — meaning a logged-in
customer cannot access protected routes.

**9. Wholesaler type exists but has no checkout path**
`CustomerTypeEn.WHOLESALER` and `PriceTypeEn.WHOLESALE_PRICE` are modelled but the checkout page does not check the
customer type and select the appropriate price tier. A wholesaler will see and pay retail prices.

**10. `ProductImage` is linked to `ProductVariant`, not `Product`**
Images are fetched by `productVariant.product.id`. This works but means a product with 5 colour variants needs images on
each variant independently. If you want shared product-level gallery images, the model needs to accommodate it.

**11. `ShippingZones` table is dead**
The `shipping_zones` table exists in the Flyway migration, has the right foreign key to `shipping_methods`, but there is
no Java entity, no repository, no service, and no UI for it. Zone-based pricing (e.g., different rates per province) is
completely blocked.

**12. Single Gmail SMTP with hardcoded sender**
`shawn.debie@gmail.com` is the hardcoded sender and SMTP account. The app password is in plain text in
`application.properties`. This will hit Gmail send limits quickly under real volume. Should be moved to a transactional
email provider (SendGrid, Mailgun, Amazon SES) and driven from `store_settings`.

**13. Mixed GraphQL + REST without a clear contract**
Some domains use GraphQL (products, orders, brands, categories, settings), others use REST (auth, customers, images,
payments). This is not wrong by itself, but the boundary is arbitrary. As the team grows this will cause confusion about
which transport to use for new features.

**14. `ec-common` is a shared JPA module**
All entities, repositories, and DTOs live in `ec-common` which is shared by `ec-backend` and `ec-infra`. This is fine
now, but if you ever split backend services (e.g., separate order service from catalog service), this shared module
becomes a monolith coupling point that prevents independent deployment.

---

## 7. Questions You Need to Answer

### Business Model

1. **Is this single-store or multi-tenant?** Will you ever run multiple stores from one codebase (e.g., reselling the
   platform)? This fundamentally changes the entity model — everything needs a `storeId` tenant discriminator.
2. **How does a wholesaler become a wholesaler?** Is there an application process, admin approval, or self-service
   sign-up? Does wholesale pricing apply at checkout automatically, or does the admin flag the account?
3. **Do you need tax (VAT)?** South African VAT is 15%. Is pricing inclusive or exclusive? Does the
   `VariantPricesEntity` store inc or exc VAT?

### Checkout & Orders

4. **Should shipping cost be included in `totalAmount` or charged separately?** Right now `totalAmount` comes entirely
   from the cart items with no shipping fee component.
5. **What does a fulfilled order look like?** Who marks it `IN_TRANSIT`? Do you integrate with a courier (e.g., Courier
   Guy, RAM), or is it manual? Do customers get a tracking number?
6. **What happens if a PayFast payment fails or is cancelled?** Should the order be auto-cancelled after a timeout? What
   is the cancel URL experience?
7. **Should a guest order be claimable by a registered account?** If a guest checks out with `email@example.com` and
   later registers, should they see that order in their history?

### Payments

8. **Is PayFast the only gateway, or are Ozow, iKhokha, or EFT planned?** The `PaymentLogEntity.gatewayName` suggests
   multi-gateway was intended. Knowing this now determines whether you need a payment gateway abstraction layer.
9. **Do you need refund/return processing?** If yes, will it be initiated through the admin panel and pushed back to
   PayFast programmatically?

### Catalog & Inventory

10. **Are product attributes (colour, size, etc.) supposed to be user-selectable on the storefront?** They are stored as
    `attributesJson` on variants but the current storefront product detail page does not expose attribute-based variant
    selection.
11. **Do you need real-time stock control?** Should "out of stock" variants be hidden or just marked unavailable? Should
    stock be decremented at order creation or at payment confirmation?
12. **Will products have slugs for SEO?** Currently product URLs use UUID (`/product/:productId`). For SEO you likely
    want `/product/brand-name-product-name`.

### Admin & Operations

13. **What does the admin order management screen need to do?** Filter by status, search by customer email, export,
    print packing slips, trigger courier pickup?
14. **Do you plan to add more staff users through the admin?** There is no UI for this — staff are presumably seeded
    directly into the DB currently.
15. **What analytics do you actually need on the dashboard?** Revenue over time, top products, conversion rate, average
    order value — knowing this determines the reporting queries needed.