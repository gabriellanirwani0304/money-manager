-- Migration 004: Transfer support between accounts

-- Add destination account column for transfers
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS to_account_id UUID REFERENCES accounts(id) ON DELETE SET NULL;

-- Make category_id nullable (transfers don't need a category)
ALTER TABLE transactions ALTER COLUMN category_id DROP NOT NULL;

-- Expand type constraint to include 'transfer'
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE transactions ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('income', 'expense', 'transfer'));

CREATE INDEX IF NOT EXISTS idx_transactions_to_account_id ON transactions(to_account_id);
