-- Migration 003: Add accounts (rekening/dompet)
-- Saldo rekening otomatis berubah saat transaksi dibuat/diupdate/dihapus

CREATE TABLE IF NOT EXISTS accounts (
    id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(100)  NOT NULL,
    type            VARCHAR(20)   NOT NULL DEFAULT 'bank'
                                  CHECK (type IN ('bank','cash','ewallet','investment','other')),
    bank_name       VARCHAR(100),
    icon            VARCHAR(50)   NOT NULL DEFAULT 'account_balance',
    color           VARCHAR(20)   NOT NULL DEFAULT '#6C5CE7',
    initial_balance NUMERIC(15,2) NOT NULL DEFAULT 0,
    balance         NUMERIC(15,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);

-- Tambah kolom account_id ke transactions (nullable, opsional)
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES accounts(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
