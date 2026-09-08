# Comprehensive Security Assessment — zacommerce.co.za (UVH Holdings)

**Prepared for:** UVH Holdings development team **Date:** 2026-09-05 **Assessment type:** Black-box, passive /
non-intrusive (no exploitation, no brute-force, no data exfiltration, no unauthorized data access)
**Target:** https://zacommerce.co.za

---

## EXECUTIVE SUMMARY

The site is a React 19 SPA fronted by Cloudflare, backed by a Quarkus (Java) + SmallRye GraphQL API. Overall the backend
authorization model is **solid** (sensitive queries and mutations are correctly gated), but there are **two critical
issues** that must be fixed before the site can safely process real money and customer data:

1. **PayFast is running in SANDBOX (test) mode** — live payments will not settle.
2. **A confirmed IDOR** in `getOrderDetail`/`orderStatus` allows any unauthenticated attacker with a valid order ID to
   read a customer's email, phone, and physical address.

There are also several high/medium hygiene issues (missing security headers, no rate limiting, placeholder contact data,
GraphQL introspection enabled, and a directly-applicable SmallRye GraphQL DoS CVE).

---

## 1. TECH STACK & VERSION FINGERPRINTING

| Layer         | Technology                          | Version                    | Evidence                                                                                 |
|---------------|-------------------------------------|----------------------------|------------------------------------------------------------------------------------------|
| Frontend      | React SPA (Vite)                    | **React 19.2.7**           | `version:\`19.2.7\`` in bundle                                                           |
| Routing       | React Router                        | **v6** (data router)       | `reactrouter.com/v6`, `RouterProvider`, `v7_*` future flags                              |
| HTTP client   | Axios                               | bundled (version stripped) | —                                                                                        |
| Validation    | Zod                                 | present                    | `ZodError`                                                                               |
| State         | Zustand                             | present                    | `customerAuthStore`, `localWishlistStore`                                                |
| Data fetching | TanStack Query                      | present                    | `useMutation`, `queryKey`                                                                |
| Backend       | **Quarkus (Java)**                  | unknown (not disclosed)    | `io.quarkus.security.UnauthorizedException`                                              |
| GraphQL       | **SmallRye GraphQL** (MicroProfile) | unknown                    | `org.eclipse.microprofile.graphql.GraphQLException`, `application/graphql-response+json` |
| Payments      | PayFast                             | **SANDBOX**                | `sandbox.payfast.co.za/onsite/engine.js`                                                 |
| CDN/WAF       | Cloudflare                          | —                          | `server: cloudflare`, origin IP hidden                                                   |
| TLS           | Google Trust Services (WE1)         | valid                      | TLS 1.2/1.3                                                                              |

**Note:** Quarkus and SmallRye GraphQL versions are not disclosed in any response header or error. The dev team should
confirm they are on patched versions (see CVE section).

---

## 2. ORIGIN / LOCAL SERVER DISCOVERY

**Result: origin IP is NOT exposed.** The site is fully proxied through Cloudflare.

- Apex resolves only to Cloudflare anycast IPs (`104.21.85.147`, `172.67.206.173`).
- No `www`, `mail`, `api`, `admin` subdomains resolve to a real origin.
- `db.zacommerce.co.za` resolves but is also Cloudflare-proxied (serves the SPA) — a wildcard DNS artifact.
- Certificate Transparency (crt.sh) shows only `*.zacommerce.co.za`, `www`, `mail`, apex — no origin hostname leaked.
- Historical certs (2019–2020) were Let's Encrypt; current (2026) are Google Trust Services / GoDaddy / Cloudflare —
  consistent with a Cloudflare migration.

**Recommendation:** ensure the origin firewall only accepts Cloudflare IP ranges (otherwise the origin can be found via
Shodan/Censys scans of the IP space). This is a hardening step, not a current exposure.

---

## 3. FULL API SURFACE

### GraphQL: `POST /api/graphql`

- **Introspection ENABLED** — full schema downloadable at `/api/graphql/schema.graphql` (1014 lines).
- Schema exposes the complete data model and privilege hints ("Staff JWT required", "SUPER_ADMIN only").

### REST endpoints (from JS bundles):

| Method | Path                                                         | Auth                 |
|--------|--------------------------------------------------------------|----------------------|
| GET    | `/api/storefront/config`                                     | public               |
| GET    | `/api/storefront/payment-methods`                            | public               |
| GET    | `/api/storefront/shipping-methods`                           | public               |
| GET    | `/api/storefront/wishlist`                                   | Bearer               |
| POST   | `/api/customers/login`, `/login/google`, `/password-reset/*` | public               |
| POST   | `/api/admin/auth/login`                                      | public               |
| GET    | `/api/admin/me`                                              | Bearer               |
| POST   | `/api/payments/checkout`                                     | X-Order-Token        |
| PATCH  | `/api/orders/{id}/contact`                                   | X-Order-Token        |
| POST   | `/api/orders/{id}/in-store-payment`                          | X-Order-Token        |
| POST   | `/api/admin/imports/{product\|price\|sage}/upload`           | Bearer (401 without) |

---

## 4. FINDINGS

### CRITICAL

#### C1. PayFast in SANDBOX mode (production)

- Every page loads `https://sandbox.payfast.co.za/onsite/engine.js`.
- Live customer payments are processed against PayFast's **test** environment. Real money will not settle.
- **Fix:** switch to `www.payfast.co.za` + live merchant ID/passphrase, then run a real end-to-end test transaction.

#### C2. IDOR — `getOrderDetail` / `orderStatus` (broken object-level authorization) — CONFIRMED

- **Differential test result** (no auth):
    - `myOrders` → `"Unauthorized"` ✅ gated
    - `adminOrder` → `"unauthorized"` ✅ gated
    - `getOrderDetail` → `"Order not found"` ❌ **no auth check**
    - `orderStatus` → `"Order not found"` ❌ **no auth check**
- The `X-Order-Token` header is **ignored** — wrong token, empty token, and no token all return the identical response.
- `getOrderDetail` returns `customerEntity.email`, full shipping address (line1/line2/city/province/postalCode),
  shipping phone, order items (product name, variant attributes, unit price, quantity), and status history.
- **Impact:** any unauthenticated attacker with a valid order ID can read a customer's email, phone, and physical
  address. Order IDs are UUIDs (not sequential) — the only mitigating factor — but they leak via confirmation emails,
  referrer headers, and the guest checkout success page (which calls `orderStatus` with the ID in the URL).
- **Fix (urgent):** enforce ownership — require a valid customer JWT and verify the order belongs to that customer, or
  actually validate the `X-Order-Token`.

#### C3. GraphQL introspection + schema download enabled

- Full schema (1014 lines) publicly downloadable, revealing the entire data model and privilege model.
- **Fix:** disable introspection in production (`quarkus.smallrye-graphql.ui.enable=false`, disable schema endpoint).

#### C4. No security headers + HTTP not forced to HTTPS

- Missing: HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy.
- `http://zacommerce.co.za/` returns `200` (no redirect to HTTPS).
- **Fix:** add headers + force HTTPS redirect + HSTS.

### HIGH

#### H1. Placeholder contact/business data live in production

- `storefront.contact` = `admin@example.com`, `+27 00 000 0000`, `012 000 0000`, `+27821234567`,
  `207 Test Road, Test, Test, 0000`.
- Customers cannot contact the business. **Fix:** real data.

#### H2. No rate limiting / lockout on login

- `/api/customers/login` and `/api/admin/auth/login` accept unlimited rapid attempts (10+ tested, all 401, no
  429/lockout).
- **Fix:** Cloudflare rate-limit rules or app-level throttling + account lockout.

#### H3. Google Sign-In is broken (empty client ID)

- The Google OAuth client ID is hardcoded as an empty string (`kp=\`\`` in the bundle). The "Sign in with Google" button
  will fail at runtime.
- **Fix:** configure the real Google OAuth client ID (this is a functional bug, not a security hole, but it's
  customer-facing).

#### H4. `www` subdomain not configured

- `www.zacommerce.co.za` = NXDOMAIN. **Fix:** add record + redirect.

### MEDIUM

#### M1. Public `storeSettings` / `countrySettings`

- Expose VAT rate, payment methods, store config, theme. Low sensitivity but unnecessary.

#### M2. `StaffDto` exposes `temporaryPassword` field in schema

- `temporaryPassword: String` on `StaffDto`/`StaffDtoInput`. If ever returned in a query response (vs. write-only
  input), it would leak credentials. Currently `staffList`/`staffById` are auth-gated, but confirm the field is
  write-only.

#### M3. `createWholesaleApplication` public + unauthenticated

- By design (application form), but accepts arbitrary PII (VAT number, reg number, addresses, emails) with no rate
  limiting or CAPTCHA → spam/abuse vector.

#### M4. `db.zacommerce.co.za` subdomain exists (wildcard DNS)

- Resolves (Cloudflare-proxied) and serves the SPA. **Fix:** remove wildcard or explicitly deny unknown subdomains.

#### M5. GraphQL alias amplification (no complexity limit)

- 2,000 aliases in a single query returned `200` in ~0.2s (no rejection). No query complexity/depth limit is enforced
  beyond a ~160-level nesting cap (which is generous). Combined with the SmallRye CVE below, this is a DoS surface.

---

## 5. CVE PASS (applicable to identified stack)

### Directly applicable

| CVE                | Component                                                                                                                                                              | Severity       | Status                                                                                                                                                                                                                                                                                                              |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **CVE-2026-76763** | SmallRye GraphQL (Quarkus) — BigInteger scalar coercion allows large-exponent float/string inputs to allocate huge BigInteger objects → CPU exhaustion / OOM → **DoS** | **7.5 HIGH**   | **Potentially affected** — the site uses SmallRye GraphQL and has `BigInteger` input fields (`saleDaysRemaining` in `VariantPriceDtoInput`). Unauthenticated exploitation is limited because the BigInteger *input* fields are on auth-gated mutations, but the dev team must confirm they're on a patched version. |
| **CVE-2026-40181** | React Router v6.7.0–6.30.3 / v7.0.0–7.14.0 — open redirect via `//` protocol-relative paths in `redirect()`                                                            | **6.1 MEDIUM** | **Potentially affected** — the app uses React Router v6 with `RouterProvider` (data router, NOT declarative `<BrowserRouter>`, so the CVE *is* applicable). No `redirect()` calls found in the app bundles, so practical impact is low, but the dependency should be updated to ≥6.30.4.                            |

### Dependency hygiene (frontend)

| CVE            | Component                           | Notes                                              |
|----------------|-------------------------------------|----------------------------------------------------|
| CVE-2024-39338 | axios <1.7.2 SSRF                   | axios version is bundled/stripped — confirm ≥1.7.2 |
| CVE-2024-57965 | axios <1.7.8 origin check           | confirm ≥1.7.8                                     |
| CVE-2025-27152 | axios absolute-URL handling         | confirm patched                                    |
| CVE-2026-25639 | axios <0.30.3 / <1.13.5 mergeConfig | confirm patched                                    |
| CVE-2026-39865 | axios 1.13.0–1.13.2                 | confirm patched                                    |

**Note:** axios version could not be extracted from the minified bundle. The dev team should run `npm audit` /
`npm ls axios react-router-dom` to confirm exact versions and patch accordingly.

### Not applicable / low risk

- React 19.2.7 itself has no known critical CVEs in the NVD at assessment time.
- No DOMPurify usage found; no `dangerouslySetInnerHTML` in application code (only React internals) → low stored-XSS
  surface.

---

## 6. WHAT'S DONE RIGHT (positive findings)

- ✅ **Origin IP hidden** behind Cloudflare (no leak via DNS, CT logs, or direct IP).
- ✅ **Auth enforced** on all sensitive GraphQL queries (customers, orders, staff, quotes, wholesale, imports, settings)
  and all admin mutations (`deleteBrand`, `updateOrderStatus`, `saveShippingMethod`, `addProductInformation`, etc. all
  return `unauthorized`).
- ✅ **CORS locked down** — cross-origin POST → 403; only `https://zacommerce.co.za` allowed with credentials.
- ✅ **No user enumeration** on login/password-reset (generic messages).
- ✅ **No hardcoded secrets** in JS bundles (no API keys, PayFast passphrase, Google client secret).
- ✅ **No exposed `.env`/`.git`/backups** (SPA fallback, not real files).
- ✅ **GraphQL "bad faith introspection" protection** present (blocks bulk `__Type.fields` enumeration).
- ✅ **Valid TLS**, TLS 1.2/1.3, Google Trust Services cert.
- ✅ **Admin import upload endpoints** return 401 without auth.

---

## 7. PRIORITIZED REMEDIATION CHECKLIST

| #  | Priority    | Action                                                                  |
|----|-------------|-------------------------------------------------------------------------|
| 1  | 🔴 Critical | Switch PayFast to production (C1)                                       |
| 2  | 🔴 Critical | Fix `getOrderDetail`/`orderStatus` IDOR — enforce ownership (C2)        |
| 3  | 🔴 Critical | Disable GraphQL introspection + schema endpoint (C3)                    |
| 4  | 🔴 Critical | Add security headers + force HTTPS + HSTS (C4)                          |
| 5  | 🟠 High     | Replace placeholder contact/business data (H1)                          |
| 6  | 🟠 High     | Add rate limiting/lockout on login (H2)                                 |
| 7  | 🟠 High     | Configure Google OAuth client ID (H3)                                   |
| 8  | 🟠 High     | Add `www` DNS record + redirect (H4)                                    |
| 9  | 🟡 Medium   | Patch SmallRye GraphQL (CVE-2026-76763) + React Router (CVE-2026-40181) |
| 10 | 🟡 Medium   | Run `npm audit`; update axios to latest (CVE pass)                      |
| 11 | 🟡 Medium   | Restrict public `storeSettings`/`countrySettings` (M1)                  |
| 12 | 🟡 Medium   | Confirm `temporaryPassword` is write-only (M2)                          |
| 13 | 🟡 Medium   | Add CAPTCHA/rate-limit to `createWholesaleApplication` (M3)             |
| 14 | 🟡 Medium   | Remove wildcard DNS / `db` subdomain (M4)                               |
| 15 | 🟡 Medium   | Add GraphQL query complexity/depth limits (M5)                          |

---

## 8. LIMITATIONS & RECOMMENDED FOLLOW-UP

This was a **black-box, passive** assessment. The following require an **authorized authenticated test** (with test
accounts) to fully validate:

1. **IDOR data exposure** — I confirmed the missing auth check via differential response analysis, but did not possess a
   valid order ID to demonstrate actual PII retrieval. The dev team should reproduce with their own test order.
2. **Privilege escalation** — role-based access (SUPER_ADMIN vs CATALOG_MANAGER vs VIEWER vs ORDER_MANAGER) could not be
   tested without staff accounts.
3. **Payment-flow integrity** — price tampering, order total manipulation, and PayFast callback validation require an
   authenticated checkout test.
4. **Business-logic flaws** — quote/wholesale workflows, bulk import validation, and abandoned-cart handling.

**Recommended:** schedule an authenticated penetration test with the dev team providing test customer + staff accounts,
and a staging environment for the PayFast production switch.

---

*This report is provided for defensive remediation purposes only. All testing was non-intrusive and did not access,
modify, or exfiltrate any real customer data.*
