const { Op } = require('sequelize');
const { modelsByTableName } = require('../models');
const logger = require('../utils/logger');
const { validateFKs } = require('../utils/fkValidator');

/**
 * Tabelas suportadas para sincronização
 */
const SUPPORTED_TABLES = [
  'accounts',
  'account_types',
  'account_descriptions',
  'banks',
  'payment_methods',
  'payments'
];

/**
 * POST /api/sync/push
 * Recebe alterações do cliente e processa no servidor
 *
 * Body esperado:
 * {
 *   table: 'accounts',
 *   creates: [{ ...dados }],
 *   updates: [{ id, ...dados }],
 *   deletes: ['server_id1', 'server_id2']
 * }
 *
 * Resposta:
 * {
 *   created: [{ local_id, server_id }],
 *   updated: [{ local_id, server_id }],
 *   conflicts: [{ server_data }],
 *   serverTimestamp: 'ISO8601'
 * }
 */
const push = async (req, res) => {
  try {
    const userId = req.userId;
    const { table, creates, updates, deletes } = req.body;

    // Validar tabela
    if (!table || !SUPPORTED_TABLES.includes(table)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Tabela inválida: ${table}. Tabelas suportadas: ${SUPPORTED_TABLES.join(', ')}`
      });
    }

    const Model = modelsByTableName[table];
    if (!Model) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Modelo não encontrado para tabela: ${table}`
      });
    }

    const serverTimestamp = new Date();
    const result = {
      created: [],
      updated: [],
      conflicts: [],
      serverTimestamp: serverTimestamp.toISOString()
    };

    // LOG DIAGNÓSTICO: Verificar FKs recebidas do Flutter
    if (table === 'account_descriptions') {
      if (creates && creates.length > 0) {
        logger.info(`[FK DIAG] account_descriptions creates[0]: accountId=${creates[0].accountId}, description="${creates[0].description}"`);
      }
      if (updates && updates.length > 0) {
        logger.info(`[FK DIAG] account_descriptions updates[0]: accountId=${updates[0].accountId}, server_id=${updates[0].server_id}`);
      }
    } else if (table === 'accounts') {
      if (creates && creates.length > 0) {
        logger.info(`[FK DIAG] accounts creates[0]: typeId=${creates[0].typeId}, categoryId=${creates[0].categoryId}, description="${creates[0].description}"`);
      }
      if (updates && updates.length > 0) {
        logger.info(`[FK DIAG] accounts updates[0]: typeId=${updates[0].typeId}, categoryId=${updates[0].categoryId}, server_id=${updates[0].server_id}`);
      }
    }

    // Processar criações
    if (creates && Array.isArray(creates)) {
      for (const data of creates) {
        try {
          const localId = data.id || data.local_id;

          // TRAVA DE SEGURANÇA: Validar FKs pertencem ao mesmo usuário
          const fkValidation = await validateFKs(table, data, userId);
          if (!fkValidation.valid) {
            logger.warn(`[${table}] FK REJEITADA (create): local_id=${localId}, erros: ${fkValidation.errors.join(', ')}`);
            result.rejected = result.rejected || [];
            result.rejected.push({
              local_id: localId,
              reason: 'FK_VALIDATION_FAILED',
              errors: fkValidation.errors
            });
            continue;
          }

          const modelData = Model.fromFlutterData ? Model.fromFlutterData(data, userId) : { ...data, user_id: userId };

          // Remover id local para não conflitar
          delete modelData.id;
          delete modelData.local_id;

          const record = await Model.create(modelData);

          result.created.push({
            local_id: localId,
            server_id: String(record.id)
          });

          logger.debug(`[${table}] Criado: local_id=${localId}, server_id=${record.id}`);
        } catch (error) {
          logger.error(`[${table}] Erro ao criar registro:`, error.message);
        }
      }
    }

    // Processar atualizações
    if (updates && Array.isArray(updates)) {
      for (const data of updates) {
        try {
          const localId = data.local_id || data.id;
          const serverId = data.server_id;

          if (!serverId) {
            logger.warn(`[${table}] Update sem server_id ignorado: local_id=${localId}`);
            continue;
          }

          // TRAVA DE SEGURANÇA: Validar FKs pertencem ao mesmo usuário
          const fkValidation = await validateFKs(table, data, userId);
          if (!fkValidation.valid) {
            logger.warn(`[${table}] FK REJEITADA (update): server_id=${serverId}, erros: ${fkValidation.errors.join(', ')}`);
            result.rejected = result.rejected || [];
            result.rejected.push({
              local_id: localId,
              server_id: serverId,
              reason: 'FK_VALIDATION_FAILED',
              errors: fkValidation.errors
            });
            continue;
          }

          const record = await Model.findOne({
            where: { id: serverId, user_id: userId },
            paranoid: false
          });

          if (!record) {
            logger.warn(`[${table}] Registro não encontrado: server_id=${serverId}`);
            continue;
          }

          // Verificar conflito (server-wins)
          const clientUpdatedAt = data.updated_at ? new Date(data.updated_at) : null;
          if (clientUpdatedAt && record.updated_at && record.updated_at > clientUpdatedAt) {
            // Conflito: servidor tem versão mais recente
            result.conflicts.push({
              local_id: localId,
              server_id: serverId,
              server_data: record.toFlutterData ? record.toFlutterData() : record.toJSON()
            });
            logger.debug(`[${table}] Conflito detectado: server_id=${serverId}`);
            continue;
          }

          // Aplicar atualização
          const modelData = Model.fromFlutterData ? Model.fromFlutterData(data, userId) : data;
          delete modelData.id;
          delete modelData.user_id;
          delete modelData.server_id;
          delete modelData.local_id;

          await record.update(modelData);

          result.updated.push({
            local_id: localId,
            server_id: serverId
          });

          logger.debug(`[${table}] Atualizado: server_id=${serverId}`);
        } catch (error) {
          logger.error(`[${table}] Erro ao atualizar registro:`, error.message);
        }
      }
    }

    // Processar exclusões (soft delete)
    if (deletes && Array.isArray(deletes)) {
      for (const serverId of deletes) {
        try {
          if (!serverId) continue;

          const record = await Model.findOne({
            where: { id: serverId, user_id: userId },
            paranoid: false
          });

          if (record) {
            await record.update({
              deleted_at: serverTimestamp,
              updated_at: serverTimestamp
            });
            logger.debug(`[${table}] Deletado: server_id=${serverId}`);
          }
        } catch (error) {
          logger.error(`[${table}] Erro ao deletar registro:`, error.message);
        }
      }
    }

    logger.info(`[SYNC PUSH] ${table}: ${result.created.length} criados, ${result.updated.length} atualizados, ${deletes?.length || 0} deletados, ${result.conflicts.length} conflitos, ${result.rejected?.length || 0} rejeitados por FK`);

    return res.status(200).json(result);

  } catch (error) {
    logger.error('Sync push error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao processar sincronização'
    });
  }
};

/**
 * GET /api/sync/pull
 * Retorna alterações do servidor desde último sync
 *
 * Query params:
 * - table: nome da tabela (obrigatório)
 * - since: timestamp ISO8601 (opcional, retorna tudo se não fornecido)
 *
 * Resposta:
 * {
 *   records: [{ id, ...dados }],
 *   deleted: ['server_id1', 'server_id2'],
 *   server_timestamp: 'ISO8601'
 * }
 */
const pull = async (req, res) => {
  try {
    const userId = req.userId;
    const { table, since } = req.query;

    // Validar tabela
    if (!table || !SUPPORTED_TABLES.includes(table)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Tabela inválida: ${table}. Tabelas suportadas: ${SUPPORTED_TABLES.join(', ')}`
      });
    }

    const Model = modelsByTableName[table];
    if (!Model) {
      return res.status(400).json({
        error: 'Bad Request',
        message: `Modelo não encontrado para tabela: ${table}`
      });
    }

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

    // Construir query
    const whereClause = { user_id: userId };

    if (sinceDate) {
      whereClause.updated_at = { [Op.gt]: sinceDate };
    }

    // Buscar registros (incluindo deletados para soft delete)
    const allRecords = await Model.findAll({
      where: whereClause,
      paranoid: false,
      order: [['updated_at', 'ASC']],
      limit: 1000
    });

    // Separar registros ativos e deletados
    const records = [];
    const deleted = [];

    for (const record of allRecords) {
      if (record.deleted_at) {
        deleted.push(String(record.id));
      } else {
        const data = record.toFlutterData ? record.toFlutterData() : record.toJSON();
        records.push(data);
      }
    }

    const serverTimestamp = new Date().toISOString();

    logger.info(`[SYNC PULL] ${table}: ${records.length} registros, ${deleted.length} deletados (since: ${since || 'início'})`);

    return res.status(200).json({
      records,
      deleted,
      server_timestamp: serverTimestamp,
      user_id: userId
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
 * GET /api/sync/status
 * Retorna status da sincronização para o usuário
 */
const status = async (req, res) => {
  try {
    const userId = req.userId;
    const stats = {};

    for (const table of SUPPORTED_TABLES) {
      const Model = modelsByTableName[table];
      if (Model) {
        const count = await Model.count({
          where: { user_id: userId }
        });
        stats[table] = count;
      }
    }

    return res.status(200).json({
      user_id: userId,
      tables: stats,
      supported_tables: SUPPORTED_TABLES,
      server_time: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Sync status error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao obter status de sincronização'
    });
  }
};

module.exports = {
  push,
  pull,
  status
};
