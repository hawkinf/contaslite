/**
 * Rotas para configurações de email
 */
const express = require('express');
const authenticate = require('../middleware/authenticate');
const emailController = require('../controllers/emailController');

const router = express.Router();

// Todas as rotas requerem autenticação
router.use(authenticate);

// GET /api/email/settings - Obtém configurações
router.get('/settings', emailController.getSettings);

// PUT /api/email/settings - Atualiza configurações
router.put('/settings', emailController.updateSettings);

// POST /api/email/test - Envia email de teste
router.post('/test', emailController.sendTestEmail);

// GET /api/email/status - Status do serviço
router.get('/status', emailController.getStatus);

module.exports = router;
