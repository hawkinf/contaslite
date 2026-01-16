const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');
const authenticate = require('../middleware/authenticate');
const { syncLimiter } = require('../middleware/rateLimiter');

/**
 * POST /api/sync/push
 * Envia alterações locais para servidor
 *
 * Body:
 * {
 *   table: 'accounts',
 *   creates: [{ ...dados }],
 *   updates: [{ server_id, ...dados }],
 *   deletes: ['server_id1', 'server_id2']
 * }
 */
router.post('/push', authenticate, syncLimiter, syncController.push);

/**
 * GET /api/sync/pull
 * Baixa alterações do servidor
 *
 * Query params:
 * - table: nome da tabela (obrigatório)
 * - since: timestamp ISO8601 (opcional)
 */
router.get('/pull', authenticate, syncLimiter, syncController.pull);

/**
 * GET /api/sync/status
 * Retorna status de sincronização do usuário
 */
router.get('/status', authenticate, syncController.status);

module.exports = router;
