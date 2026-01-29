-- Migration: Validação de FK cross-user
-- Version: 007
-- Date: 2026-01-29
--
-- TRAVA DE SEGURANÇA NO BANCO DE DADOS
-- Previne que registros referenciem FKs de outros usuários.
--
-- Cenários prevenidos:
-- 1. account_descriptions.account_id apontando para account_type de outro usuário
-- 2. accounts.type_id apontando para account_type de outro usuário
-- 3. accounts.category_id apontando para account_description de outro usuário
-- 4. accounts.card_id apontando para account (cartão) de outro usuário
-- 5. payments.account_id apontando para account de outro usuário
-- 6. payments.payment_method_id apontando para payment_method de outro usuário
-- 7. payments.bank_account_id apontando para bank de outro usuário

-- =============================================================================
-- PARTE 1: Funções de validação
-- =============================================================================

-- Função: Valida que account_type pertence ao mesmo usuário
CREATE OR REPLACE FUNCTION validate_account_type_ownership()
RETURNS TRIGGER AS $$
DECLARE
    type_user_id INTEGER;
    fk_id INTEGER;
BEGIN
    -- Determinar qual coluna FK verificar baseado na tabela
    IF TG_TABLE_NAME = 'accounts' THEN
        fk_id := NEW.type_id;
    ELSIF TG_TABLE_NAME = 'account_descriptions' THEN
        fk_id := NEW.account_id;
    ELSE
        RETURN NEW;
    END IF;

    IF fk_id IS NOT NULL THEN
        SELECT user_id INTO type_user_id
        FROM account_types
        WHERE id = fk_id AND deleted_at IS NULL;

        IF type_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: account_type id=% não encontrado', fk_id;
        END IF;

        IF type_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: account_type id=% pertence ao user_id=%, não ao user_id=%',
                fk_id, type_user_id, NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função: Valida que account_description pertence ao mesmo usuário
CREATE OR REPLACE FUNCTION validate_account_description_ownership()
RETURNS TRIGGER AS $$
DECLARE
    desc_user_id INTEGER;
BEGIN
    IF NEW.category_id IS NOT NULL THEN
        SELECT user_id INTO desc_user_id
        FROM account_descriptions
        WHERE id = NEW.category_id AND deleted_at IS NULL;

        IF desc_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: account_description id=% não encontrado', NEW.category_id;
        END IF;

        IF desc_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: account_description id=% pertence ao user_id=%, não ao user_id=%',
                NEW.category_id, desc_user_id, NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função: Valida que account (card_id/recurrence_id) pertence ao mesmo usuário
CREATE OR REPLACE FUNCTION validate_account_self_references()
RETURNS TRIGGER AS $$
DECLARE
    ref_user_id INTEGER;
BEGIN
    -- Validar card_id
    IF NEW.card_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM accounts
        WHERE id = NEW.card_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: account (card_id) id=% não encontrado', NEW.card_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: account (card_id) id=% pertence ao user_id=%, não ao user_id=%',
                NEW.card_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    -- Validar recurrence_id
    IF NEW.recurrence_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM accounts
        WHERE id = NEW.recurrence_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: account (recurrence_id) id=% não encontrado', NEW.recurrence_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: account (recurrence_id) id=% pertence ao user_id=%, não ao user_id=%',
                NEW.recurrence_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Função: Valida FKs de payments
CREATE OR REPLACE FUNCTION validate_payment_references()
RETURNS TRIGGER AS $$
DECLARE
    ref_user_id INTEGER;
BEGIN
    -- Validar account_id
    IF NEW.account_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM accounts
        WHERE id = NEW.account_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: account id=% não encontrado', NEW.account_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: account id=% pertence ao user_id=%, não ao user_id=%',
                NEW.account_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    -- Validar payment_method_id
    IF NEW.payment_method_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM payment_methods
        WHERE id = NEW.payment_method_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: payment_method id=% não encontrado', NEW.payment_method_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: payment_method id=% pertence ao user_id=%, não ao user_id=%',
                NEW.payment_method_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    -- Validar bank_account_id
    IF NEW.bank_account_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM banks
        WHERE id = NEW.bank_account_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: bank id=% não encontrado', NEW.bank_account_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: bank id=% pertence ao user_id=%, não ao user_id=%',
                NEW.bank_account_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    -- Validar credit_card_id (referência a account que é cartão)
    IF NEW.credit_card_id IS NOT NULL THEN
        SELECT user_id INTO ref_user_id
        FROM accounts
        WHERE id = NEW.credit_card_id AND deleted_at IS NULL;

        IF ref_user_id IS NULL THEN
            RAISE EXCEPTION 'FK_VALIDATION_ERROR: credit_card (account) id=% não encontrado', NEW.credit_card_id;
        END IF;

        IF ref_user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FK_CROSS_USER_ERROR: credit_card (account) id=% pertence ao user_id=%, não ao user_id=%',
                NEW.credit_card_id, ref_user_id, NEW.user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- PARTE 2: Triggers de validação
-- =============================================================================

-- Trigger para account_descriptions: validar account_id (FK para account_types)
DROP TRIGGER IF EXISTS trg_validate_account_descriptions_fk ON account_descriptions;
CREATE TRIGGER trg_validate_account_descriptions_fk
    BEFORE INSERT OR UPDATE ON account_descriptions
    FOR EACH ROW
    EXECUTE FUNCTION validate_account_type_ownership();

-- Triggers para accounts: validar type_id, category_id, card_id, recurrence_id
DROP TRIGGER IF EXISTS trg_validate_accounts_type_fk ON accounts;
CREATE TRIGGER trg_validate_accounts_type_fk
    BEFORE INSERT OR UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION validate_account_type_ownership();

DROP TRIGGER IF EXISTS trg_validate_accounts_category_fk ON accounts;
CREATE TRIGGER trg_validate_accounts_category_fk
    BEFORE INSERT OR UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION validate_account_description_ownership();

DROP TRIGGER IF EXISTS trg_validate_accounts_self_fk ON accounts;
CREATE TRIGGER trg_validate_accounts_self_fk
    BEFORE INSERT OR UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION validate_account_self_references();

-- Trigger para payments: validar todas as FKs
DROP TRIGGER IF EXISTS trg_validate_payments_fk ON payments;
CREATE TRIGGER trg_validate_payments_fk
    BEFORE INSERT OR UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION validate_payment_references();

-- =============================================================================
-- PARTE 3: Verificação de dados existentes (relatório, não corrige)
-- =============================================================================

-- Esta query pode ser executada manualmente para identificar dados inconsistentes
-- SELECT 'account_descriptions' AS table_name, ad.id, ad.user_id, ad.account_id, at.user_id AS fk_user_id
-- FROM account_descriptions ad
-- LEFT JOIN account_types at ON ad.account_id = at.id
-- WHERE ad.deleted_at IS NULL AND at.user_id != ad.user_id;

-- =============================================================================
-- FIM DA MIGRAÇÃO
-- =============================================================================

-- Log de conclusão
DO $$
BEGIN
    RAISE NOTICE 'Migration 007: FK User Validation Constraints aplicada com sucesso';
    RAISE NOTICE 'Triggers criados para validar ownership de FKs em:';
    RAISE NOTICE '  - account_descriptions (account_id -> account_types)';
    RAISE NOTICE '  - accounts (type_id -> account_types)';
    RAISE NOTICE '  - accounts (category_id -> account_descriptions)';
    RAISE NOTICE '  - accounts (card_id, recurrence_id -> accounts)';
    RAISE NOTICE '  - payments (account_id, payment_method_id, bank_account_id, credit_card_id)';
END $$;
