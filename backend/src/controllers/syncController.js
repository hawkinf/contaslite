const { Op } = require('sequelize');
const Account = require('../models/Account');
const logger = require('../utils/logger');

/**
 * POST /api/sync/push
 * Envia alterações locais para o servidor
 */
const push = async (req, res) => {
  try {
    const userId = req.userId;
    const { changes } = req.body;

    if (!changes || typeof changes !== 'object') {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Formato de changes inválido'
      });
    }

    const processed = {};
    const conflicts = [];
    const serverTimestamp = new Date();

    // Processar contas (accounts)
    if (changes.accounts && Array.isArray(changes.accounts)) {
      processed.accounts = [];

      for (const change of changes.accounts) {
        try {
          const result = await processAccountChange(userId, change, serverTimestamp, conflicts);
          if (result) {
            processed.accounts.push(result);
          }
        } catch (error) {
          logger.error(`Error processing account change:`, error);
          // Continuar processando outros registros
        }
      }
    }

    // TODO: Processar outras tabelas (categories, payment_methods, etc.)

    logger.info(`Sync push completed for user ${userId}: ${processed.accounts?.length || 0} accounts processed`);

    return res.status(200).json({
      processed,
      conflicts,
      serverTimestamp: serverTimestamp.toISOString()
    });

  } catch (error) {
    logger.error('Sync push error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao processar sincronização'
    });
  }
};

/**
 * GET /api/sync/pull?since={timestamp}
 * Baixa alterações do servidor desde último sync
 */
const pull = async (req, res) => {
  try {
    const userId = req.userId;
    const since = req.query.since;

    // Validar timestamp
    let sinceDate = null;
    if (since) {
      sinceDate = new Date(since);
      if (isNaN(sinceDate.getTime())) {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Formato de timestamp inválido (use ISO 8601)'
        });
      }
    }

    const whereClause = {
      user_id: userId
    };

    // Filtrar por data se fornecida
    if (sinceDate) {
      whereClause.updated_at = {
        [Op.gt]: sinceDate
      };
    }

    // Buscar contas (incluindo deletadas para soft delete)
    const accounts = await Account.findAll({
      where: whereClause,
      paranoid: false, // Incluir registros com deleted_at
      order: [['updated_at', 'ASC']],
      limit: 1000 // Paginação
    });

    // TODO: Buscar outras tabelas (categories, payment_methods, etc.)

    const data = {
      accounts: accounts.map(acc => ({
        id: acc.id,
        typeId: acc.type_id,
        categoryId: acc.category_id,
        subcategoryId: acc.subcategory_id,
        paymentMethodId: acc.payment_method_id,
        description: acc.description,
        amount: parseFloat(acc.amount),
        dueDate: acc.due_date,
        paymentDate: acc.payment_date,
        status: acc.status,
        notes: acc.notes,
        updatedAt: acc.updated_at.toISOString(),
        deletedAt: acc.deleted_at ? acc.deleted_at.toISOString() : null
      }))
    };

    const serverTimestamp = new Date();
    const hasMore = accounts.length >= 1000;

    logger.info(`Sync pull completed for user ${userId}: ${accounts.length} accounts returned`);

    return res.status(200).json({
      data,
      serverTimestamp: serverTimestamp.toISOString(),
      hasMore
    });

  } catch (error) {
    logger.error('Sync pull error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao buscar sincronização'
    });
  }
};

/**
 * Processa uma mudança individual de conta
 */
const processAccountChange = async (userId, change, serverTimestamp, conflicts) => {
  const { localId, serverId, action, data, updatedAt } = change;

  // CREATE
  if (action === 'create') {
    const newAccount = await Account.create({
      user_id: userId,
      ...data,
      created_at: serverTimestamp,
      updated_at: serverTimestamp
    });

    return {
      localId,
      serverId: newAccount.id,
      action: 'created',
      serverTimestamp: serverTimestamp.toISOString()
    };
  }

  // UPDATE
  if (action === 'update') {
    if (!serverId) {
      throw new Error('serverId é obrigatório para updates');
    }

    const account = await Account.findOne({
      where: { id: serverId, user_id: userId }
    });

    if (!account) {
      throw new Error(`Conta ${serverId} não encontrada`);
    }

    // Detectar conflito: server-wins
    const clientUpdatedAt = new Date(updatedAt);
    if (account.updated_at > clientUpdatedAt) {
      // Conflito! Servidor tem versão mais recente
      conflicts.push({
        localId,
        serverId,
        table: 'accounts',
        reason: 'Server version is newer',
        serverVersion: {
          id: account.id,
          status: account.status,
          updatedAt: account.updated_at.toISOString()
        },
        resolution: 'server_wins'
      });

      return {
        localId,
        serverId,
        action: 'conflict',
        serverTimestamp: account.updated_at.toISOString()
      };
    }

    // Sem conflito, aplicar update
    await account.update({
      ...data,
      updated_at: serverTimestamp
    });

    return {
      localId,
      serverId,
      action: 'updated',
      serverTimestamp: serverTimestamp.toISOString()
    };
  }

  // DELETE
  if (action === 'delete') {
    if (!serverId) {
      throw new Error('serverId é obrigatório para deletes');
    }

    const account = await Account.findOne({
      where: { id: serverId, user_id: userId }
    });

    if (account) {
      // Soft delete
      await account.update({
        deleted_at: serverTimestamp,
        updated_at: serverTimestamp
      });
    }

    return {
      localId,
      serverId,
      action: 'deleted',
      serverTimestamp: serverTimestamp.toISOString()
    };
  }

  throw new Error(`Ação inválida: ${action}`);
};

module.exports = {
  push,
  pull
};
