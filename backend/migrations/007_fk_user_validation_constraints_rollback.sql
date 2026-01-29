-- Rollback Migration: Remove FK User Validation Constraints
-- Version: 007 (ROLLBACK)
-- Date: 2026-01-29
--
-- Execução: Para desfazer a migration 007, execute este script manualmente
-- psql -U usuario -d database -f 007_fk_user_validation_constraints_rollback.sql

-- =============================================================================
-- PARTE 1: Remover triggers
-- =============================================================================

DROP TRIGGER IF EXISTS trg_validate_account_descriptions_fk ON account_descriptions;
DROP TRIGGER IF EXISTS trg_validate_accounts_type_fk ON accounts;
DROP TRIGGER IF EXISTS trg_validate_accounts_category_fk ON accounts;
DROP TRIGGER IF EXISTS trg_validate_accounts_self_fk ON accounts;
DROP TRIGGER IF EXISTS trg_validate_payments_fk ON payments;

-- =============================================================================
-- PARTE 2: Remover funções
-- =============================================================================

DROP FUNCTION IF EXISTS validate_account_type_ownership();
DROP FUNCTION IF EXISTS validate_account_description_ownership();
DROP FUNCTION IF EXISTS validate_account_self_references();
DROP FUNCTION IF EXISTS validate_payment_references();

-- =============================================================================
-- FIM DO ROLLBACK
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Rollback 007: FK User Validation Constraints removidas com sucesso';
END $$;
