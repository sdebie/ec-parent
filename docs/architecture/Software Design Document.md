# Software Design Document: Multi-Tenant Isolated E-Commerce Platform

This document outlines the single-codebase, multi-deployment architecture for a modern e-commerce platform. It provides
a complete technical blueprint for deploying independent, containerized instances for each client.

---

## Introduction and Overview

### Purpose

This document details the design of a fully isolated multi-tenant e-commerce system. It allows a single codebase to
serve multiple unique clients (e.g., ClientA.co.za and ClientB.co.za).

### Scope

The platform includes an online Storefront and an integrated Administrative Portal. It covers backend logic, data
isolation, and deployment configurations.

### Core Goals

- Run independent client systems from one codebase.
- Ensure zero data overlap between client environments.
- Combine public retail shopping and secure business wholesale operations.

---

## System Architecture

The platform uses an Isolated Single-Tenant Deployment per Client pattern. While the code is shared, each client runs
its own dedicated infrastructure stack.

```
       [ Client A Request ]                     [ Client B Request ]
                │                                        │
                ▼                                        ▼
    ┌──────────────────────────────┐        ┌──────────────────────────────┐
    │   Docker Compose Stack: A    │        │   Docker Compose Stack: B    │
    │  ┌────────────────────────┐  │        │  ┌────────────────────────┐  │
    │  │   React SPA Frontend   │  │        │  │   React SPA Frontend   │  │
    │  │   (Tailwind CSS v4)    │  │        │  │   (Tailwind CSS v4)    │  │
    │  └───────────┬────────────┘  │        │  └───────────┬────────────┘  │
    │              │ API Calls     │        │              │ API Calls     │
    │              ▼               │        │              ▼               │
    │  ┌────────────────────────┐  │        │  ┌────────────────────────┐  │
    │  │  Quarkus Backend App   │  │        │  │  Quarkus Backend App   │  │
    │  └───────────┬────────────┘  │        │  └───────────┬────────────┘  │
    │              │ JDBC          │        │              │ JDBC          │
    │              ▼               │        │              ▼               │
    │  ┌────────────────────────┐  │        │  ┌────────────────────────┐  │
    │  │   PostgreSQL Database  │  │        │  │  PostgreSQL Database   │  │
    │  └────────────────────────┘  │        │  └────────────────────────┘  │
    └──────────────────────────────┘        └──────────────────────────────┘
```

### Architectural Highlights

- Total Isolation: Client A cannot access or impact Client B.
- Stack Composition: Every client runs a containerized group containing PostgreSQL, Quarkus, and React.
- Environment Configuration: Runtime differences (like database credentials and domain origins) are managed using
  external environment variables.

---

## Data Design

Each client runs a private PostgreSQL database instance. The data models are packaged into a reusable Common Java
Library Module.

### Core Database Entities

- Users: Stores retail customers, wholesale partners, and system admins.
- Products: Holds item titles, descriptions, status flags, and inventory counts.
- Categories & Brands: Used to organize and classify the catalog.
- Orders: Tracks purchase history, item prices, quantities, and delivery status.
- Wholesale Applications: Manages business registration data and approval tracking.

### Reusable Common Library

- Quarkus BOM Parent: Standardizes third-party dependency versions across the codebase.
- Shared Entities: Reusable Java objects decorated with Jakarta Persistence (`@Entity`) annotations.
- Repositories: Standardized Panache data access classes to keep queries uniform.

---

## Interface Design

Communications between systems are standard, stateless, and secured.

### Internal API Design

The React application communicates with the Quarkus backend using strict RESTful API endpoints.

- GET `/api/v1/products`: Fetches filtered public store catalog items.
- POST `/api/v1/orders`: Handles checkout processing for both guests and authenticated accounts.
- POST `/api/v1/admin/bulk-upload:` Receives multi-item CSV file payloads for inventory injection.
- POST `/api/v1/admin/images/upload`: Processes and saves product imagery to the local attached volume.
- POST `/api/v1/payments/payfast-notify`: Handles payment status updates from PayFast.

### Security and Authentication

- Token Standard: Implements stateless JSON Web Tokens (JWT) for session control.
- Role Enforcement: API filters check token claims (ROLE_RETAIL, ROLE_WHOLESALE, ROLE_ADMIN) before processing protected
  updates.

---

## Component Design

The project is built as a clean Monorepo consisting of three distinct functional layers.

1. Common Library Module (`/common`)
    - Houses cross-project enumerations (e.g., OrderStatus, UserRole).
    - Contains master Hibernate entities and data access repositories.
2. Backend Quarkus App (`/backend`)
    - Imports the `/common` library dependency.
    - API Controllers: Processes request formatting and path matching.
    - Services: Houses calculations, file processing rules, and business logic validations.
3. Frontend React App (`/frontend`)
    - Employs Tailwind CSS v4 for clean, modern utility styling.
    - Houses both the customer storefront views and secure admin views in a single bundle.

---

## User Interface Design

The single React SPA uses client-side routing to separate the public shopping layout from the secure workspace.

### The Storefront Application

- Browsing Space: Dynamic catalog layouts featuring fast searching, category tags, and attribute filtering.
- Checkout Funnel: A flexible shopping cart allowing checkout as an unauthenticated guest or a logged-in user.
- Account Portals: Offers standard retail order tracking and a wholesale portal with bulk B2B pricing tiers.

### The Administrative Portal

- Catalog Control: Screens to create, modify, or disable products, brands, and categories.
- Bulk Engine: File drag-and-drop tool to process bulk product CSV sheets and media assets.
- Operations Desk: Review queues for evaluating wholesale applications and managing active shipping workflows.

``` 
                  [ Admin Path Requested ]
                             │
                             ▼
               ┌───────────────────────────┐
               │ createAdminDataRoutes.tsx │
               └─────────────┬─────────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  <RouteGuard>   │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
     [ Checks Failed ]              [ Checks Passed ]
   (No Auth / Bad Domain)          (Valid Admin Session)
              │                             │
              ▼                             ▼
    Redirect to Storefront          Render Admin Console View
```

- The Guard Component: createAdminDataRoutes.tsx acts as the entry barrier for all management layouts.
- Context Checks: The <RouteGuard> evaluates two reactive properties:
    - isAuthenticated: Confirms active login tokens exist.
    - isAdminDomain: Validates the host domain address matches administrative allowances.

---

## Assumptions and Dependencies

### System Assumptions

- Each client runs on a separate web host domain name.
- Media files are stored locally inside a persistent Docker folder volume or sent to independent cloud storage buckets.
- Client updates are handled by building a single base image and restarting individual customer containers.

### Hard Dependencies

- Docker Engine: The target host environment must natively run Linux containers.
- Java 21 / Quarkus Engine: The foundational layer for backend execution.
- Node.js: Required to compile the React and Tailwind CSS v4 assets.

---

## Technical Specifications & Environment Mapping

To keep the codebase unified, all hardcoded values are removed from application.properties. Every setting is driven by
environment variables injected into the Docker container at startup.

### Core Configuration Properties

| Property Key                              | Environment Variable        | Default Value                                 | Purpose/Usage                                 |
|-------------------------------------------|-----------------------------|-----------------------------------------------|-----------------------------------------------|
| quarkus.datasource.jdbc.url               | QUARKUS_DATASOURCE_JDBC_URL | jdbc:postgresql://localhost:5432/ecommerce_db | Database connection URL                       |
| quarkus.datasource.username               | QUARKUS_DATASOURCE_USERNAME | postgres                                      | Database admin user                           |
| quarkus.datasource.password               | QUARKUS_DATASOURCE_PASSWORD | postgres                                      | Database access secret                        |
| quarkus.hibernate-orm.database.generation | DATABASE_GENERATION         | updateDatabase                                | schema strategy                               |
| quarkus.http.cors.origins                 | CORS_ORIGINS                | *                                             | Locks API to client web domain                |
| storage.path                              | IMAGE_STORAGE_PATH          | /tmp/images                                   | Target folder directory for multi-part images |
| payfast.merchant-id                       | PAYFAST_MERCHANT_ID         | 10037872                                      | Client PayFast account ID (Sandbox default)   |
| payfast.merchant-key                      | PAYFAST_MERCHANT_KEY        | jvyb485e4zpxq                                 | Client PayFast security key                   |
| payfast.passphrase                        | PAYFAST_PASSPHRASE          | testpayfast1                                  | Salt string used to sign MD5 hashes           |
| payfast.base-url                          | PAYFAST_BASE_URL            | https://payfast.co.za                         | Target processing URL                         |
| payfast.notify-url                        | PAYFAST_NOTIFY_URL          | https://sdebiehome.co.za                      | Webhook target for Instant Transaction Links  |
| payfast.return-url                        | PAYFAST_RETURN_URL          | https://sdebiehome.co.za                      | Success landing route for retail shoppers     |
| payfast.cancel-url                        | PAYFAST_CANCEL_URL          | https://sdebiehome.co.za                      | Fallback route if checkout is aborted         |

### Docker File

Volume MappingThe file engine uses the local container folder writes. We intercept this path at deployment to ensure
images persist through service upgrades.

```yaml
version: '3.8'
services:
  postgres-db:
    image: postgres:latest
    environment:
      POSTGRES_DB: client_abc_db
      POSTGRES_USER: client_abc_user
      POSTGRES_PASSWORD: s3cur3-p@ss
    volumes:
      - ./client_data/db:/var/lib/postgresql/data

  quarkus-backend:
    image: client-backend:latest
    environment:
      - QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres-db:5432/client_abc_db
      - QUARKUS_DATASOURCE_USERNAME=client_abc_user
      - QUARKUS_DATASOURCE_PASSWORD=s3cur3-p@ss
      - CORS_ORIGINS=https://store.clientabc.co.za
      - IMAGE_STORAGE_PATH=/app/images
      - PAYFAST_MERCHANT_ID=20031940
    volumes:
      - ./client_data/uploads:/app/images
    ports:
      - "8080:8080"
    depends_on:
      - postgres-db
```

---

## New Client Provisioning Checklist

When rolling out a brand-new client instance onto the architecture, execute the following implementation checklist:

- Step 1: Provision Infrastructure — Spin up an isolated PostgreSQL instance and create a blank target database.
- Step 2: Collect Client Keys — Acquire live production values for PayFast credentials, domain names, SMTP
  configurations, and JWT secrets.
- Step 3: Build & Deploy Container Stack — Launch the backend container by injecting the client's custom parameters
  through the Docker environment maps.
- Step 4: Attach Volume System — Map the local host machine storage folder to the backend's designated
  IMAGE_STORAGE_PATH volume hook.
- Step 5: Publish App Bundles — Deploy the shared frontend React artifact compiled to hit the newly launched client
  backend endpoints.
- Step 6: Register System Tenant — Insert a new row matching the client web domain directly into the TenantConfig data
  table so the platform runtime endpoint correctly resolves the client's custom branding metadata.

## Glossary of Terms

- BOM (Bill of Materials): A configuration file that locks in specific dependency versions to prevent build errors.
- CORS (Cross-Origin Resource Sharing): A security system that restricts web applications from making API requests to a
  different domain than the one that served the application.
- Docker Container: A lightweight sandbox package containing an application and everything it needs to run.
- ITN (Instant Transaction Notification): A webhook message sent by PayFast to notify the backend that a payment status
  has changed.
- Panache: A Quarkus library that simplifies writing database queries.
- SPA (Single Page Application): A modern web application that updates the page dynamically without loading entirely new
  pages from a server.

---