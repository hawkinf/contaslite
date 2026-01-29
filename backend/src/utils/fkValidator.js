/**
 * FK Validator - Valida FKs pertencem ao mesmo usuário
 *
 * TRAVA DE SEGURANÇA: Impede que um usuário referencie dados de outro usuário
 * através de FKs manipuladas.
 *
 * Cenário de ataque prevenido:
 * - Usuário A envia accountId=50 (que pertence ao Usuário B)
 * - Sem validação, o registro seria criado com FK cruzada
 * - Com validação, retorna erro 400 e rejeita o registro
 */

const { sequelize } = require('../config/database');
const logger = require('./logger');

/**
 * Valida que um ID de account_type pertence ao usuário especificado
 * @param {number} accountTypeId - ID do account_type a validar
 * @param {number} userId - ID do usuário dono esperado
 * @returns {Promise<{valid: boolean, error?: string}>}
 */
async function validateAccountTypeOwnership(accountTypeId, userId) {
  if (!accountTypeId) {
    return { valid: true }; // FK nula é permitida em alguns casos
  }

  const [results] = await sequelize.query(`
    SELECT id, user_id FROM account_types
    WHERE id = :accountTypeId AND deleted_at IS NULL
  `, {
    replacements: { accountTypeId },
    type: sequelize.QueryTypes.SELECT
  });

  if (!results) {
    return {
      valid: false,
      error: `account_type id=${accountTypeId} não encontrado`
    };
  }

  if (results.user_id !== userId) {
    logger.warn(`[FK SECURITY] Tentativa de FK cruzada: account_type id=${accountTypeId} pertence ao user_id=${results.user_id}, não ao user_id=${userId}`);
    return {
      valid: false,
      error: `account_type id=${accountTypeId} não pertence ao usuário`
    };
  }

  return { valid: true };
}

/**
 * Valida que um ID de account_description pertence ao usuário especificado
 * @param {number} accountDescriptionId - ID do account_description a validar
 * @param {number} userId - ID do usuário dono esperado
 * @returns {Promise<{valid: boolean, error?: string}>}
 */
async function validateAccountDescriptionOwnership(accountDescriptionId, userId) {
  if (!accountDescriptionId) {
    return { valid: true }; // FK nula é permitida
  }

  const [results] = await sequelize.query(`
    SELECT id, user_id FROM account_descriptions
    WHERE id = :accountDescriptionId AND deleted_at IS NULL
  `, {
    replacements: { accountDescriptionId },
    type: sequelize.QueryTypes.SELECT
  });

  if (!results) {
    return {
      valid: false,
      error: `account_description id=${accountDescriptionId} não encontrado`
    };
  }

  if (results.user_id !== userId) {
    logger.warn(`[FK SECURITY] Tentativa de FK cruzada: account_description id=${accountDescriptionId} pertence ao user_id=${results.user_id}, não ao user_id=${userId}`);
    return {
      valid: false,
      error: `account_description id=${accountDescriptionId} não pertence ao usuário`
    };
  }

  return { valid: true };
}

/**
 * Valida FKs de account_descriptions antes de criar/atualizar
 * @param {Object} data - Dados do registro (formato Flutter)
 * @param {number} userId - ID do usuário autenticado
 * @returns {Promise<{valid: boolean, errors: string[]}>}
 */
async function validateAccountDescriptionFKs(data, userId) {
  const errors = [];

  // Validar accountId (FK para account_types)
  if (data.accountId) {
    const result = await validateAccountTypeOwnership(data.accountId, userId);
    if (!result.valid) {
      errors.push(result.error);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Valida FKs de accounts antes de criar/atualizar
 * @param {Object} data - Dados do registro (formato Flutter)
 * @param {number} userId - ID do usuário autenticado
 * @returns {Promise<{valid: boolean, errors: string[]}>}
 */
async function validateAccountFKs(data, userId) {
  const errors = [];

  // Validar typeId (FK para account_types)
  if (data.typeId) {
    const result = await validateAccountTypeOwnership(data.typeId, userId);
    if (!result.valid) {
      errors.push(result.error);
    }
  }

  // Validar categoryId (FK para account_descriptions)
  if (data.categoryId) {
    const result = await validateAccountDescriptionOwnership(data.categoryId, userId);
    if (!result.valid) {
      errors.push(result.error);
    }
  }

  // Validar cardId (FK para outra account do mesmo usuário)
  if (data.cardId) {
    const [cardRecord] = await sequelize.query(`
      SELECT id, user_id FROM accounts
      WHERE id = :cardId AND deleted_at IS NULL
    `, {
      replacements: { cardId: data.cardId },
      type: sequelize.QueryTypes.SELECT
    });

    if (!cardRecord) {
      errors.push(`card_id=${data.cardId} não encontrado`);
    } else if (cardRecord.user_id !== userId) {
      logger.warn(`[FK SECURITY] Tentativa de FK cruzada: card_id=${data.cardId} pertence ao user_id=${cardRecord.user_id}, não ao user_id=${userId}`);
      errors.push(`card_id=${data.cardId} não pertence ao usuário`);
    }
  }

  // Validar recurrenceId (FK para outra account do mesmo usuário)
  if (data.recurrenceId) {
    const [recurrenceRecord] = await sequelize.query(`
      SELECT id, user_id FROM accounts
      WHERE id = :recurrenceId AND deleted_at IS NULL
    `, {
      replacements: { recurrenceId: data.recurrenceId },
      type: sequelize.QueryTypes.SELECT
    });

    if (!recurrenceRecord) {
      errors.push(`recurrence_id=${data.recurrenceId} não encontrado`);
    } else if (recurrenceRecord.user_id !== userId) {
      logger.warn(`[FK SECURITY] Tentativa de FK cruzada: recurrence_id=${data.recurrenceId} pertence ao user_id=${recurrenceRecord.user_id}, não ao user_id=${userId}`);
      errors.push(`recurrence_id=${data.recurrenceId} não pertence ao usuário`);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Valida FKs de payments antes de criar/atualizar
 * @param {Object} data - Dados do registro (formato Flutter)
 * @param {number} userId - ID do usuário autenticado
 * @returns {Promise<{valid: boolean, errors: string[]}>}
 */
async function validatePaymentFKs(data, userId) {
  const errors = [];

  // Validar accountId (FK para accounts)
  if (data.accountId) {
    const [accountRecord] = await sequelize.query(`
      SELECT id, user_id FROM accounts
      WHERE id = :accountId AND deleted_at IS NULL
    `, {
      replacements: { accountId: data.accountId },
      type: sequelize.QueryTypes.SELECT
    });

    if (!accountRecord) {
      errors.push(`account_id=${data.accountId} não encontrado`);
    } else if (accountRecord.user_id !== userId) {
      logger.warn(`[FK SECURITY] Tentativa de FK cruzada em payment: account_id=${data.accountId} pertence ao user_id=${accountRecord.user_id}, não ao user_id=${userId}`);
      errors.push(`account_id=${data.accountId} não pertence ao usuário`);
    }
  }

  // Validar paymentMethodId (FK para payment_methods)
  if (data.paymentMethodId) {
    const [pmRecord] = await sequelize.query(`
      SELECT id, user_id FROM payment_methods
      WHERE id = :paymentMethodId AND deleted_at IS NULL
    `, {
      replacements: { paymentMethodId: data.paymentMethodId },
      type: sequelize.QueryTypes.SELECT
    });

    if (!pmRecord) {
      errors.push(`payment_method_id=${data.paymentMethodId} não encontrado`);
    } else if (pmRecord.user_id !== userId) {
      logger.warn(`[FK SECURITY] Tentativa de FK cruzada em payment: payment_method_id=${data.paymentMethodId} pertence ao user_id=${pmRecord.user_id}, não ao user_id=${userId}`);
      errors.push(`payment_method_id=${data.paymentMethodId} não pertence ao usuário`);
    }
  }

  // Validar bankAccountId (FK para banks)
  if (data.bankAccountId) {
    const [bankRecord] = await sequelize.query(`
      SELECT id, user_id FROM banks
      WHERE id = :bankAccountId AND deleted_at IS NULL
    `, {
      replacements: { bankAccountId: data.bankAccountId },
      type: sequelize.QueryTypes.SELECT
    });

    if (!bankRecord) {
      errors.push(`bank_account_id=${data.bankAccountId} não encontrado`);
    } else if (bankRecord.user_id !== userId) {
      logger.warn(`[FK SECURITY] Tentativa de FK cruzada em payment: bank_account_id=${data.bankAccountId} pertence ao user_id=${bankRecord.user_id}, não ao user_id=${userId}`);
      errors.push(`bank_account_id=${data.bankAccountId} não pertence ao usuário`);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Mapeamento de tabelas para suas funções de validação de FK
 */
const fkValidators = {
  account_descriptions: validateAccountDescriptionFKs,
  accounts: validateAccountFKs,
  payments: validatePaymentFKs
};

/**
 * Valida FKs de um registro antes de criar/atualizar
 * @param {string} table - Nome da tabela
 * @param {Object} data - Dados do registro
 * @param {number} userId - ID do usuário autenticado
 * @returns {Promise<{valid: boolean, errors: string[]}>}
 */
async function validateFKs(table, data, userId) {
  const validator = fkValidators[table];

  if (!validator) {
    // Tabela não tem FKs que precisam de validação de ownership
    return { valid: true, errors: [] };
  }

  return validator(data, userId);
}

module.exports = {
  validateFKs,
  validateAccountTypeOwnership,
  validateAccountDescriptionOwnership,
  validateAccountDescriptionFKs,
  validateAccountFKs,
  validatePaymentFKs,
  fkValidators
};
