# E-Commerce Database Schema Design

## Requirements Summary

- Entities: Users, Products, Orders, Order Items, Reviews
- Target: 10K orders/day (~300K/month, ~3.6M/year)
- PostgreSQL as primary RDBMS
- Designed for horizontal read scaling and vertical write scaling

---

## Schema (PostgreSQL DDL)

### Extensions

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
```

### Users

```sql
CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         VARCHAR(320) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(200) NOT NULL,
    phone         VARCHAR(20),
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_users_email ON users (LOWER(email));
CREATE INDEX idx_users_created_at ON users (created_at);
```

### Addresses

```sql
CREATE TABLE addresses (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    label       VARCHAR(50) NOT NULL DEFAULT 'home',
    line1       VARCHAR(255) NOT NULL,
    line2       VARCHAR(255),
    city        VARCHAR(100) NOT NULL,
    state       VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country     CHAR(2) NOT NULL,
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_addresses_user ON addresses (user_id);
```

### Categories

```sql
CREATE TABLE categories (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_id   BIGINT REFERENCES categories(id) ON DELETE SET NULL,
    name        VARCHAR(200) NOT NULL,
    slug        VARCHAR(200) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_categories_slug ON categories (slug);
CREATE INDEX idx_categories_parent ON categories (parent_id);
```

### Products

```sql
CREATE TABLE products (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id     BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    sku             VARCHAR(100) NOT NULL,
    name            VARCHAR(500) NOT NULL,
    description     TEXT,
    price_cents     BIGINT NOT NULL CHECK (price_cents > 0),
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    stock_qty       INTEGER NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
    weight_grams    INTEGER,
    is_published    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_products_sku ON products (sku);
CREATE INDEX idx_products_category ON products (category_id);
CREATE INDEX idx_products_price ON products (price_cents);
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_published ON products (is_published) WHERE is_published;
```

### Orders

```sql
CREATE TABLE orders (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status          VARCHAR(30) NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','confirmed','shipped','delivered','cancelled','refunded')),
    shipping_addr_id BIGINT REFERENCES addresses(id) ON DELETE SET NULL,
    billing_addr_id  BIGINT REFERENCES addresses(id) ON DELETE SET NULL,
    subtotal_cents  BIGINT NOT NULL CHECK (subtotal_cents >= 0),
    tax_cents       BIGINT NOT NULL DEFAULT 0 CHECK (tax_cents >= 0),
    shipping_cents  BIGINT NOT NULL DEFAULT 0 CHECK (shipping_cents >= 0),
    total_cents     BIGINT NOT NULL CHECK (total_cents >= 0),
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    notes           TEXT,
    placed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders (user_id, placed_at DESC);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_placed_at ON orders (placed_at DESC);
```

### Order Items

```sql
CREATE TABLE order_items (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id      BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity        INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_cents BIGINT NOT NULL CHECK (unit_price_cents > 0),
    line_total_cents BIGINT GENERATED ALWAYS AS (quantity * unit_price_cents) STORED,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items (order_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);
```

### Reviews

```sql
CREATE TABLE reviews (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title       VARCHAR(200),
    body        TEXT,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_review_one_per_user_product UNIQUE (product_id, user_id)
);

CREATE INDEX idx_reviews_product ON reviews (product_id, created_at DESC);
CREATE INDEX idx_reviews_user ON reviews (user_id);
```

### Materialized View: Product Rating Summary

```sql
CREATE MATERIALIZED VIEW product_rating_summary AS
SELECT
    product_id,
    COUNT(*)              AS review_count,
    ROUND(AVG(rating), 2) AS avg_rating
FROM reviews
GROUP BY product_id;

CREATE UNIQUE INDEX idx_prs_product ON product_rating_summary (product_id);

-- Refresh after bulk review inserts (e.g., nightly)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY product_rating_summary;
```

---

## Partitioning Strategy

### Orders Partitioning (Range by month)

At 10K orders/day, orders accumulate fast. Range-partition by `placed_at`:

```sql
CREATE TABLE orders (
    ...
) PARTITION BY RANGE (placed_at);

CREATE TABLE orders_2026_01 PARTITION OF orders
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
-- ... one per month, automate via pg_partman or cron
```

**Benefits**: fast partition pruning on date-range queries, easy archival/drop of old months.

### Order Items Partitioning

If order_items is not co-partitioned, it stays unpartitioned since FK constraints across partitions require careful handling. Keep it as a regular table — it references orders via order_id and doesn't need date pruning itself.

---

## Scalability Considerations for 10K Orders/Day

| Concern | Approach |
|---|---|
| **Write throughput** | Orders/order_items: partition by month to spread WAL load and enable concurrent inserts across partitions. Use BIGINT identity columns for monotonic IDs. |
| **Read throughput** | Product search: use pg_trgm GIN index for fuzzy text search; offload heavy reads to a read replica. Product rating summary: materialized view, refresh on schedule. |
| **Hot paths** | `products` and `orders` tables are hot. Add a connection pooler (PgBouncer) in front. Read replicas for product catalog queries. |
| **Stock concurrency** | Use `SELECT ... FOR UPDATE` on products when decrementing stock, or use an optimistic approach with `stock_qty` check constraint. |
| **Archival** | Orders older than 2 years can be detached (ALTER TABLE orders DETACH PARTITION) and moved to cold storage or a data warehouse. |
| **Sharding (future)** | If single-node writes become the bottleneck, shard orders by `user_id` using a middleware like Citus. Users and products can remain unsharded initially. |

---

## Key Design Decisions

1. **BIGINT identity vs UUID**: BIGINT for primary keys — smaller, faster indexes, better for sequential writes. UUIDs only if distributed ID generation is needed (not yet).

2. **Money in cents**: All monetary values stored as `BIGINT` cents to avoid floating-point rounding. `price_cents`, `total_cents`, etc.

3. **Normalized addresses**: Separate `addresses` table allows reuse across orders and supports multiple addresses per user.

4. **Denormalized order totals**: `subtotal_cents`, `tax_cents`, `shipping_cents`, `total_cents` are stored on the order row. Computed at order time from line items. Avoids expensive joins for order display.

5. **Materialized rating summary**: Avoids expensive `AVG()` over potentially millions of reviews on every product page. Refreshed periodically (nightly or every few hours).

6. **Soft deletes via is_active**: Users are deactivated, not deleted, to preserve order history integrity.

---

## Backup & Recovery

- **WAL archiving**: Enable `archive_mode = on` with continuous WAL archiving to S3/GCS for point-in-time recovery.
- **pg_dump**: Full logical backup weekly, incremental WAL archiving hourly.
- **RTO/RPO**: Target 1 hour RTO, 15 min RPO with WAL streaming to a standby.
- **Connection pooling**: PgBouncer in transaction mode, pool size 50-100 connections.
