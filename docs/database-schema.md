# Money Manager — Database Schema

## ERD Overview

```
users ──< categories ──< transactions
      ──< budgets
      ──< recurring_transactions ──< transactions
      ──< refresh_tokens
```

---

## Tables

### `users`
Menyimpan akun pengguna.

```sql
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(255)  NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,
    currency      VARCHAR(10)   NOT NULL DEFAULT 'IDR',
    created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
```

### `refresh_tokens`
Whitelist refresh token untuk invalidasi saat logout.

```sql
CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ  NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
```

### `categories`
Kategori transaksi milik user. Bisa default (bawaan sistem, is_default=true) atau custom.

```sql
CREATE TABLE categories (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         REFERENCES users(id) ON DELETE CASCADE,
    name       VARCHAR(100) NOT NULL,
    type       VARCHAR(10)  NOT NULL CHECK (type IN ('income', 'expense')),
    icon       VARCHAR(50)  NOT NULL DEFAULT 'category',
    color      VARCHAR(20)  NOT NULL DEFAULT '#6366F1',
    is_default BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_categories_type ON categories(type);
-- Pastikan nama unik per user per tipe
CREATE UNIQUE INDEX idx_categories_user_name_type ON categories(user_id, name, type)
    WHERE user_id IS NOT NULL;
```

**Catatan:**
- `user_id = NULL` artinya kategori global default (seed data)
- `icon` menggunakan nama Material Icon string
- `color` dalam format hex `#RRGGBB`

### `transactions`
Catatan setiap transaksi keuangan.

```sql
CREATE TABLE transactions (
    id               UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id      UUID          NOT NULL REFERENCES categories(id),
    type             VARCHAR(10)   NOT NULL CHECK (type IN ('income', 'expense')),
    amount           NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    description      TEXT,
    date             DATE          NOT NULL,
    recurring_id     UUID          REFERENCES recurring_transactions(id) ON DELETE SET NULL,
    created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_date ON transactions(date DESC);
CREATE INDEX idx_transactions_category_id ON transactions(category_id);
CREATE INDEX idx_transactions_type ON transactions(type);
-- Full-text search
CREATE INDEX idx_transactions_description_fts ON transactions
    USING gin(to_tsvector('english', COALESCE(description, '')));
```

### `budgets`
Anggaran per kategori per bulan.

```sql
CREATE TABLE budgets (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID          NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    amount      NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    month       SMALLINT      NOT NULL CHECK (month BETWEEN 1 AND 12),
    year        SMALLINT      NOT NULL CHECK (year > 2000),
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, category_id, month, year)
);

CREATE INDEX idx_budgets_user_id ON budgets(user_id);
CREATE INDEX idx_budgets_month_year ON budgets(year, month);
```

### `recurring_transactions`
Template transaksi berulang yang di-generate otomatis.

```sql
CREATE TABLE recurring_transactions (
    id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id UUID          NOT NULL REFERENCES categories(id),
    type        VARCHAR(10)   NOT NULL CHECK (type IN ('income', 'expense')),
    amount      NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    description TEXT,
    frequency   VARCHAR(20)   NOT NULL CHECK (frequency IN ('daily','weekly','monthly','yearly')),
    next_date   DATE          NOT NULL,
    is_active   BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recurring_user_id ON recurring_transactions(user_id);
CREATE INDEX idx_recurring_next_date ON recurring_transactions(next_date) WHERE is_active = TRUE;
```

---

## Seed Data — Default Categories

```sql
-- Income Categories (user_id NULL = global default)
INSERT INTO categories (name, type, icon, color, is_default) VALUES
('Gaji',          'income',  'work',           '#22C55E', TRUE),
('Bonus',         'income',  'star',            '#10B981', TRUE),
('Investasi',     'income',  'trending_up',     '#059669', TRUE),
('Penjualan',     'income',  'sell',            '#16A34A', TRUE),
('Freelance',     'income',  'computer',        '#15803D', TRUE),
('Lainnya',       'income',  'add_circle',      '#166534', TRUE);

-- Expense Categories
INSERT INTO categories (name, type, icon, color, is_default) VALUES
('Makanan',       'expense', 'restaurant',      '#EF4444', TRUE),
('Transport',     'expense', 'directions_car',  '#F97316', TRUE),
('Belanja',       'expense', 'shopping_cart',   '#EAB308', TRUE),
('Tagihan',       'expense', 'receipt_long',    '#8B5CF6', TRUE),
('Kesehatan',     'expense', 'local_hospital',  '#EC4899', TRUE),
('Hiburan',       'expense', 'movie',           '#06B6D4', TRUE),
('Pendidikan',    'expense', 'school',          '#3B82F6', TRUE),
('Investasi',     'expense', 'savings',         '#6366F1', TRUE),
('Cicilan',       'expense', 'credit_card',     '#DC2626', TRUE),
('Lainnya',       'expense', 'more_horiz',      '#6B7280', TRUE);
```

---

## Key Queries

### Dashboard Summary (bulan ini)
```sql
SELECT
    type,
    SUM(amount) AS total
FROM transactions
WHERE user_id = $1
  AND DATE_TRUNC('month', date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY type;
```

### Budget Status (satu bulan)
```sql
SELECT
    b.id,
    b.category_id,
    c.name AS category_name,
    c.icon,
    c.color,
    b.amount AS budget_amount,
    COALESCE(SUM(t.amount), 0) AS spent,
    ROUND(COALESCE(SUM(t.amount), 0) / b.amount * 100, 2) AS percentage
FROM budgets b
JOIN categories c ON c.id = b.category_id
LEFT JOIN transactions t
    ON t.category_id = b.category_id
    AND t.user_id = b.user_id
    AND t.type = 'expense'
    AND EXTRACT(MONTH FROM t.date) = b.month
    AND EXTRACT(YEAR FROM t.date) = b.year
WHERE b.user_id = $1 AND b.month = $2 AND b.year = $3
GROUP BY b.id, b.category_id, c.name, c.icon, c.color, b.amount;
```

### Monthly Trend (6 bulan)
```sql
SELECT
    DATE_TRUNC('month', date) AS month,
    type,
    SUM(amount) AS total
FROM transactions
WHERE user_id = $1
  AND date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '5 months'
GROUP BY DATE_TRUNC('month', date), type
ORDER BY month ASC;
```

### Category Breakdown
```sql
SELECT
    c.id,
    c.name,
    c.icon,
    c.color,
    SUM(t.amount) AS total,
    COUNT(*) AS count,
    ROUND(SUM(t.amount) / SUM(SUM(t.amount)) OVER () * 100, 2) AS percentage
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.user_id = $1
  AND t.type = $2
  AND EXTRACT(MONTH FROM t.date) = $3
  AND EXTRACT(YEAR FROM t.date) = $4
GROUP BY c.id, c.name, c.icon, c.color
ORDER BY total DESC;
```
