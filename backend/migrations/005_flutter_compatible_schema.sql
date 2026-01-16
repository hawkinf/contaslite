-- Migration: Schema compatível com Flutter (Contaslite)
-- Version: 005
-- Date: 2026-01-15
--
-- IMPORTANTE: Esta migração recria as tabelas para alinhar com o schema do Flutter.
-- Se já existirem dados, faça backup antes de executar.
--
-- Ordem de execução:
-- 1. Dropar tabelas na ordem reversa de dependência
-- 2. Criar tabelas na ordem correta de dependência

-- =============================================================================
-- PARTE 1: Limpar tabelas existentes (na ordem reversa de dependência)
-- =============================================================================

DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS account_descriptions CASCADE;
DROP TABLE IF EXISTS account_types CASCADE;
DROP TABLE IF EXISTS banks CASCADE;
DROP TABLE IF EXISTS payment_methods CASCADE;
DROP TABLE IF EXISTS subcategories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- =============================================================================
-- PARTE 2: Criar tabelas na ordem correta de dependência
-- =============================================================================

-- -----------------------------------------------------------------------------
-- account_types: Tipos de conta (Cartões de Crédito, Consumo, Saúde, etc.)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS account_types (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    logo VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_account_types_user_id ON account_types(user_id);
CREATE INDEX IF NOT EXISTS idx_account_types_updated_at ON account_types(updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_types_unique_name
    ON account_types(user_id, name) WHERE deleted_at IS NULL;

COMMENT ON TABLE account_types IS 'Tipos de conta (Cartões de Crédito, Consumo, Saúde, etc.)';
COMMENT ON COLUMN account_types.logo IS 'Emoji ou identificador visual';

-- -----------------------------------------------------------------------------
-- account_descriptions: Subcategorias de tipos de conta
-- No Flutter: tabela account_descriptions com accountId -> account_types.id
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS account_descriptions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id INTEGER NOT NULL REFERENCES account_types(id) ON DELETE CASCADE,
    description VARCHAR(255) NOT NULL,
    logo VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_account_descriptions_user_id ON account_descriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_account_descriptions_account_id ON account_descriptions(account_id);
CREATE INDEX IF NOT EXISTS idx_account_descriptions_updated_at ON account_descriptions(updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_account_descriptions_unique
    ON account_descriptions(user_id, account_id, description) WHERE deleted_at IS NULL;

COMMENT ON TABLE account_descriptions IS 'Subcategorias de tipos de conta (Flutter: account_descriptions)';
COMMENT ON COLUMN account_descriptions.account_id IS 'FK para account_types (Flutter chama de accountId)';
COMMENT ON COLUMN account_descriptions.description IS 'Nome da subcategoria (Flutter chama de categoria)';

-- -----------------------------------------------------------------------------
-- banks: Contas bancárias do usuário
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS banks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    code INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255) DEFAULT '',
    agency VARCHAR(20) NOT NULL,
    account VARCHAR(30) NOT NULL,
    color INTEGER DEFAULT 4283657666,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_banks_user_id ON banks(user_id);
CREATE INDEX IF NOT EXISTS idx_banks_code ON banks(code);
CREATE INDEX IF NOT EXISTS idx_banks_updated_at ON banks(updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_banks_unique_account
    ON banks(user_id, agency, account) WHERE deleted_at IS NULL;

COMMENT ON TABLE banks IS 'Contas bancárias do usuário';
COMMENT ON COLUMN banks.code IS 'Código do banco (ex: 001 para BB, 341 para Itaú)';
COMMENT ON COLUMN banks.color IS 'Cor para exibição (código hexadecimal int)';

-- -----------------------------------------------------------------------------
-- payment_methods: Métodos de pagamento
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(50) NOT NULL,
    icon_code INTEGER NOT NULL,
    requires_bank BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    usage INTEGER DEFAULT 2,
    logo VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,

    CHECK (usage IN (0, 1, 2))
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_user_id ON payment_methods(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_methods_is_active ON payment_methods(is_active);
CREATE INDEX IF NOT EXISTS idx_payment_methods_updated_at ON payment_methods(updated_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_methods_unique_name
    ON payment_methods(user_id, name) WHERE deleted_at IS NULL;

COMMENT ON TABLE payment_methods IS 'Métodos de pagamento';
COMMENT ON COLUMN payment_methods.type IS 'Tipo: credit_card, debit, pix, cash, transfer';
COMMENT ON COLUMN payment_methods.icon_code IS 'Código do ícone Material Icons';
COMMENT ON COLUMN payment_methods.usage IS '0=pagamentos, 1=recebimentos, 2=ambos';

-- -----------------------------------------------------------------------------
-- accounts: Contas, cartões de crédito e despesas de cartão
-- Schema completo compatível com Flutter
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Referências para classificação
    type_id INTEGER NOT NULL REFERENCES account_types(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES account_descriptions(id) ON DELETE SET NULL,

    -- Dados principais
    description TEXT NOT NULL,
    value DECIMAL(15, 2) NOT NULL DEFAULT 0,
    estimated_value DECIMAL(15, 2),

    -- Data de vencimento (dia + mês + ano)
    due_day INTEGER NOT NULL CHECK (due_day >= 1 AND due_day <= 31),
    month INTEGER CHECK (month >= 1 AND month <= 12),
    year INTEGER CHECK (year >= 2000 AND year <= 2100),

    -- Recorrência
    is_recurrent BOOLEAN DEFAULT FALSE,
    pay_in_advance BOOLEAN DEFAULT FALSE,
    recurrence_id INTEGER,

    -- Parcelamento
    installment_index INTEGER,
    installment_total INTEGER,
    purchase_uuid VARCHAR(36),

    -- Campos específicos para cartão de crédito
    best_buy_day INTEGER CHECK (best_buy_day IS NULL OR (best_buy_day >= 1 AND best_buy_day <= 31)),
    card_brand VARCHAR(50),
    card_bank VARCHAR(100),
    card_limit DECIMAL(15, 2),
    card_color INTEGER,

    -- Rastreamento de despesas do cartão
    card_id INTEGER,

    -- Campos adicionais
    logo VARCHAR(255),
    observation TEXT,
    establishment VARCHAR(255),
    purchase_date VARCHAR(50),
    creation_date VARCHAR(50),

    -- Timestamps e soft delete
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

-- Indexes para accounts
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_type_id ON accounts(type_id);
CREATE INDEX IF NOT EXISTS idx_accounts_category_id ON accounts(category_id);
CREATE INDEX IF NOT EXISTS idx_accounts_month_year ON accounts(month, year);
CREATE INDEX IF NOT EXISTS idx_accounts_card_id ON accounts(card_id);
CREATE INDEX IF NOT EXISTS idx_accounts_purchase_uuid ON accounts(purchase_uuid);
CREATE INDEX IF NOT EXISTS idx_accounts_recurrence_id ON accounts(recurrence_id);
CREATE INDEX IF NOT EXISTS idx_accounts_is_recurrent ON accounts(is_recurrent);
CREATE INDEX IF NOT EXISTS idx_accounts_card_brand ON accounts(card_brand) WHERE card_brand IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_accounts_updated_at ON accounts(updated_at);
CREATE INDEX IF NOT EXISTS idx_accounts_deleted_at ON accounts(deleted_at);

COMMENT ON TABLE accounts IS 'Contas a pagar/receber, cartões de crédito e suas despesas';
COMMENT ON COLUMN accounts.card_brand IS 'Se preenchido, indica que é um cartão de crédito';
COMMENT ON COLUMN accounts.card_id IS 'ID do cartão ao qual esta despesa pertence';
COMMENT ON COLUMN accounts.purchase_uuid IS 'UUID que agrupa parcelas de uma mesma compra';
COMMENT ON COLUMN accounts.recurrence_id IS 'ID do registro pai para contas recorrentes';
COMMENT ON COLUMN accounts.estimated_value IS 'Valor previsto/médio para recorrências';

-- -----------------------------------------------------------------------------
-- payments: Registro de pagamentos realizados
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    payment_method_id INTEGER NOT NULL REFERENCES payment_methods(id) ON DELETE SET NULL,
    bank_account_id INTEGER REFERENCES banks(id) ON DELETE SET NULL,
    credit_card_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
    value DECIMAL(15, 2) NOT NULL,
    payment_date VARCHAR(50) NOT NULL,
    observation TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_account_id ON payments(account_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_method_id ON payments(payment_method_id);
CREATE INDEX IF NOT EXISTS idx_payments_bank_account_id ON payments(bank_account_id);
CREATE INDEX IF NOT EXISTS idx_payments_credit_card_id ON payments(credit_card_id);
CREATE INDEX IF NOT EXISTS idx_payments_payment_date ON payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_payments_updated_at ON payments(updated_at);

COMMENT ON TABLE payments IS 'Registro de pagamentos realizados';
COMMENT ON COLUMN payments.credit_card_id IS 'Cartão de crédito usado (referência a Account com card_brand)';

-- =============================================================================
-- PARTE 3: Funções auxiliares
-- =============================================================================

-- Função para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers para atualizar updated_at
DROP TRIGGER IF EXISTS update_account_types_updated_at ON account_types;
CREATE TRIGGER update_account_types_updated_at
    BEFORE UPDATE ON account_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_account_descriptions_updated_at ON account_descriptions;
CREATE TRIGGER update_account_descriptions_updated_at
    BEFORE UPDATE ON account_descriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_banks_updated_at ON banks;
CREATE TRIGGER update_banks_updated_at
    BEFORE UPDATE ON banks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_payment_methods_updated_at ON payment_methods;
CREATE TRIGGER update_payment_methods_updated_at
    BEFORE UPDATE ON payment_methods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_accounts_updated_at ON accounts;
CREATE TRIGGER update_accounts_updated_at
    BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_payments_updated_at ON payments;
CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- FIM DA MIGRAÇÃO
-- =============================================================================
