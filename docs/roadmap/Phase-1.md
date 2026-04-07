# 🥇 PHASE 1 — MVP (Critical Path)

> Goal: Customers can buy. Orders don’t break. You don’t panic.

## 🧱 EPIC 1: Storefront Core

### Module: Homepage

* FEAT: Display featured products
* FEAT: Display categories
* FEAT: Static hero banner
* FEAT: Basic trust messaging (delivery / secure checkout)

---

### Module: Product Listing (Category/Brand)

* FEAT: List products by category
* FEAT: Pagination
* FEAT: Sort (price, name)
* FEAT: Basic filter (brand, price range)

---

### Module: Product Detail Page

* FEAT: Product info (name, SKU, description)
* FEAT: Image gallery
* FEAT: Price display
* FEAT: Stock status
* FEAT: Add to cart
* FEAT: Quantity selector

---

### Module: Search

* FEAT: Keyword search (name + SKU)
* FEAT: Display results page

---

## 🛒 EPIC 2: Cart & Checkout

### Module: Cart

* FEAT: Add/remove items
* FEAT: Update quantity
* FEAT: Calculate subtotal
* FEAT: Persist cart (session/local storage)

---

### Module: Checkout

* FEAT: Guest checkout
* FEAT: Capture customer details
* FEAT: Capture delivery address
* FEAT: Select delivery method
* FEAT: Order summary

---

### Module: Order Creation (Backend Heavy)

* FEAT: Create order
* FEAT: Validate stock
* FEAT: Validate pricing
* FEAT: Reserve stock
* FEAT: Prevent duplicate orders (idempotency key)

---

### Module: Payment Integration

* FEAT: Integrate PayFast / Ozow / Stripe
* FEAT: Handle payment success
* FEAT: Handle payment failure
* FEAT: Store transaction reference

---

### Module: Order Confirmation

* FEAT: Confirmation page
* FEAT: Confirmation email

---

## 📦 EPIC 3: Admin — Order & Inventory

### Module: Order Management

* FEAT: View orders
* FEAT: Filter orders (status/date)
* FEAT: Update status (pending → paid → shipped → delivered)
* FEAT: View order details

---

### Module: Inventory

* FEAT: Stock per SKU
* FEAT: Reduce stock on order
* FEAT: Prevent overselling

---

## 👤 EPIC 4: Customer Accounts

### Module: Authentication

* FEAT: Register
* FEAT: Login
* FEAT: Forgot password

---

### Module: Customer Profile

* FEAT: View profile
* FEAT: Order history

---

## 🚚 EPIC 5: Delivery (Basic)

* FEAT: Flat delivery fee
* FEAT: Delivery vs pickup option
* FEAT: Show delivery fee in checkout

---

## 📄 EPIC 6: Trust & Legal

* FEAT: About page
* FEAT: Contact page
* FEAT: Terms & conditions
* FEAT: Privacy policy
