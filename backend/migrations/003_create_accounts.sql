-- Migration: Create accounts table
-- Version: 003
-- Date: 2026-01-12

-- Note: Este script assume que as tabelas account_types, categories, 
-- subcategories e payment_methods já existem.
-- Crie-as primeiro antes de rodar este script.

CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type_id INTEGER REFERENCES account_types(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    subcategory_id INTEGER REFERENCES subcategories(id) ON DELETE SET NULL,
    payment_method_id INTEGER REFERENCES payment_methods(id) ON DELETE SET NULL,
    
    description TEXT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    due_date DATE NOT NULL,
    payment_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,
    
    CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled'))
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_type_id ON accounts(type_id);
CREATE INDEX IF NOT EXISTS idx_accounts_category_id ON accounts(category_id);
CREATE INDEX IF NOT EXISTS idx_accounts_due_date ON accounts(due_date);
CREATE INDEX IF NOT EXISTS idx_accounts_status ON accounts(status);
CREATE INDEX IF NOT EXISTS idx_accounts_updated_at ON accounts(updated_at);
CREATE INDEX IF NOT EXISTS idx_accounts_deleted_at ON accounts(deleted_at);

-- Comments
COMMENT ON TABLE accounts IS 'Tabela de contas a pagar e receber';
COMMENT ON COLUMN accounts.deleted_at IS 'Soft delete timestamp';
COMMENT ON COLUMN accounts.status IS 'Status: pending, paid, overdue, cancelled';
