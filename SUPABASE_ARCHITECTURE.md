# Qudris ShopKeeper - Supabase Architecture

## Overview

This document describes the migration from Google Drive-based sync to a production-grade Supabase backend with offline-first synchronization.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    UI Layer (Riverpod)                    │  │
│  │  Auth │ Dashboard │ Inventory │ POS │ Reports │ Staff    │  │
│  └────────────────────┬─────────────────────────────────────┘  │
│                       │                                         │
│  ┌────────────────────▼─────────────────────────────────────┐  │
│  │              Business Logic (Riverpod)                    │  │
│  │  Permissions │ Sync Controller │ Storage Manager         │  │
│  └────────┬──────────────────────────────────┬──────────────┘  │
│           │                                   │                 │
│  ┌────────▼──────────────────┐  ┌────────────▼──────────────┐ │
│  │   Local DB (Drift)        │  │  Network Layer (Dio)      │ │
│  │  - Offline-first          │  │  - Retry logic            │ │
│  │  - Source of truth        │  │  - Error handling         │ │
│  │  - dirty tracking         │  └────────────┬──────────────┘ │
│  └───────────────────────────┘               │                 │
└──────────────────────────────────────────────┼─────────────────┘
                                               │
                   ════════════════════════════▼═════════════════
                              INTERNET (Bi-directional Sync)
                   ════════════════════════════▼═════════════════
                                               │
┌──────────────────────────────────────────────┼─────────────────┐
│                      Supabase Cloud          │                 │
│                                              │                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │                  Supabase Auth                         │   │
│  │  - Google OAuth                                        │   │
│  │  - Email/Password                                      │   │
│  │  - Magic Link                                          │   │
│  │  - JWT with custom claims (profile_id, shop_ids)      │   │
│  └────────────────────────┬───────────────────────────────┘   │
│                           │                                   │
│  ┌────────────────────────▼───────────────────────────────┐   │
│  │              PostgreSQL Database                       │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │ Core Tables (with RLS):                          │  │   │
│  │  │  profiles, shops, staff, roles                   │  │   │
│  │  │  products, categories, inventory                 │  │   │
│  │  │  stock_movements, customers                      │  │   │
│  │  │  orders, order_items, payments                   │  │   │
│  │  │  devices, sync_states, audit_logs                │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  │  - Row-Level Security (RLS) by shop_id + role         │   │
│  │  - Soft deletes (deleted_at)                          │   │
│  │  - Versioning (last_modified, version)                │   │
│  └────────────────────────┬───────────────────────────────┘   │
│                           │                                   │
│  ┌────────────────────────▼───────────────────────────────┐   │
│  │              Edge Functions (Deno)                     │   │
│  │  - /sync: Batch pull/push with conflict resolution    │   │
│  │  - /sign-url: Generate signed URLs for Storage        │   │
│  └────────────────────────┬───────────────────────────────┘   │
│                           │                                   │
│  ┌────────────────────────▼───────────────────────────────┐   │
│  │                 Storage Buckets                        │   │
│  │  - product_images (scoped by shop_id)                 │   │
│  │  - receipts (scoped by shop_id/year/month)            │   │
│  │  - exports (CSV/JSON, time-limited signed URLs)       │   │
│  └────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Authentication Flow
1. User opens app → Check local session
2. If no session → Show SignIn screen
3. User signs in via Google/Email/Magic Link
4. Supabase Auth returns JWT with custom claims
5. App fetches/creates profile, determines active shop
6. Session persisted securely; JWT refreshed automatically

### 2. Offline-First Sync Flow

#### Pull (Server → Client)
```
1. App requests delta sync per table
2. Edge Function queries: WHERE last_modified > client_watermark
3. Returns changed rows + deleted rows (deleted_at IS NOT NULL)
4. Client upserts changed rows to local Drift DB
5. Client marks deleted rows as deleted locally
6. Update sync_states.last_pulled_at watermark
```

#### Push (Client → Server)
```
1. App gathers dirty rows from local DB (where dirty = true)
2. Batch POST to /sync with device_id + version
3. Edge Function processes each row:
   - If server.version > client.version → Conflict (server wins)
   - Else → Accept client change, increment version
4. Return authoritative rows (merged/resolved)
5. Client updates local DB with server response
6. Clear dirty flags
```

### 3. Conflict Resolution
- **Strategy**: Last-write-wins at row level (based on `updated_at`)
- **Audit Trail**: All conflicts logged to `audit_logs` with both versions
- **Future**: Can evolve to field-level merge using JSONB diffs

### 4. Multi-Tenancy & Security

#### Row-Level Security (RLS)
Every table has:
```sql
shop_id UUID REFERENCES shops(id)
```

Policies enforce:
```sql
-- User must be authenticated
auth.uid() IS NOT NULL

-- User must be staff member of the shop
EXISTS (
  SELECT 1 FROM staff 
  WHERE staff.shop_id = table.shop_id 
  AND staff.user_id = auth.uid()
  AND staff.deleted_at IS NULL
)
```

#### Role-Based Permissions
- **Owner**: Full CRUD on all shop data, can invite/remove staff
- **Manager**: Full CRUD on products/inventory/orders, can view staff
- **Cashier**: Create orders/payments, read-only products/customers

Enforced at:
1. **Database**: RLS policies per role
2. **Client**: UI feature gates via `permissions.dart`

## Tables & Key Columns

### Core Identity
- `profiles`: Maps auth.users → app profile (name, avatar, settings)
- `shops`: Shop entity (name, address, currency, timezone)
- `staff`: User membership in shop with role
- `devices`: Registered devices for sync tracking

### Catalog
- `categories`: Product categories (name, parent_id for hierarchy)
- `products`: SKU, name, price, cost, tax, barcode, image, reorder level

### Inventory
- `inventory`: Current stock levels (on_hand, reserved, reorder triggers)
- `stock_movements`: Audit trail (sale/purchase/adjustment/return)

### Sales
- `customers`: Name, phone, email, loyalty points
- `orders`: Header (status, totals, channel, customer)
- `order_items`: Line items (product, qty, price, discounts)
- `payments`: Payment records (method, amount, receipt image)

### Sync & Audit
- `sync_states`: Per table/device watermarks (last_pulled_at)
- `audit_logs`: Who/what/when for all critical actions

## Storage Strategy

### Buckets
1. **product_images**: `{shop_id}/{product_id}/{filename}`
2. **receipts**: `{shop_id}/{year}/{month}/{order_id}/{filename}`
3. **exports**: `{shop_id}/exports/{timestamp}_{type}.{csv|json}`

### Policies
- Upload: Only staff of the shop
- Read: Staff + time-limited signed URLs for exports
- Delete: Owner/Manager only

## Sync Lifecycle

### App Startup
1. Check auth session
2. If authenticated → Run delta sync for all tables
3. Show dashboard (local data available immediately)
4. Sync happens in background

### Background Sync
- Trigger on: App foreground, connectivity change, manual refresh
- Throttle: Max once per 30s
- Exponential backoff on errors

### Migration (One-Time)
1. Detect first launch with Supabase enabled
2. Prompt owner to login/create shop
3. Push all local data to Supabase:
   - Products, categories, inventory, customers
   - Orders, order_items, payments
   - Upload local images to Storage
4. Mark migration complete
5. Disable Google Drive features

## Technology Stack

### Flutter
- **State Management**: Riverpod
- **Local DB**: Drift (SQLite)
- **HTTP**: Dio
- **Auth**: supabase_flutter
- **Code Gen**: build_runner, freezed, json_serializable

### Supabase
- **Auth**: Social (Google), Email, Magic Link
- **Database**: PostgreSQL 15+ with RLS
- **Storage**: S3-compatible object storage
- **Edge Functions**: Deno runtime

## Observability

### Metrics Tracked
- Sync duration per table
- Rows pulled/pushed per sync
- Conflict count
- Network errors
- Storage upload/download sizes

### Logging
- Local: Debug logs in dev, error-only in prod
- Remote: Critical errors to `audit_logs`
- Sync outcomes logged with device_id + timestamp

## Resilience

### Network Failures
- Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
- Queue operations during offline
- Surface sync status in UI

### Data Integrity
- Foreign key constraints in Postgres
- Drift foreign keys for local consistency
- Validate data before sync push
- Server validates RLS before accept

## Next-Gen Features (Future)

1. **Real-time sync**: Supabase Realtime for live updates
2. **Field-level merge**: JSONB diff for granular conflict resolution
3. **Multi-shop support**: User can switch between shops
4. **Web dashboard**: Admin panel for owners
5. **Analytics**: BigQuery export via Edge Functions
6. **Webhook integrations**: Payments, inventory alerts

---

**Document Version**: 1.0  
**Last Updated**: October 8, 2025  
**Author**: Qudris ShopKeeper Team

