const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');
const authenticate = require('../middleware/authenticate');
const { syncLimiter } = require('../middleware/rateLimiter');

/**
 * POST /api/sync/push
 * Envia alterações locais para servidor
 */
router.post('/push', authenticate, syncLimiter, syncController.push);

/**
 * GET /api/sync/pull
 * Baixa alterações do servidor
 */
router.get('/pull', authenticate, syncLimiter, syncController.pull);

module.exports = router;
