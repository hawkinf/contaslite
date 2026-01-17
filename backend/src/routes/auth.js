const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authenticate = require('../middleware/authenticate');
const { loginLimiter, registerLimiter } = require('../middleware/rateLimiter');

/**
 * POST /api/auth/register
 * Registra novo usuário
 */
router.post('/register', registerLimiter, authController.register);

/**
 * POST /api/auth/login
 * Autentica usuário
 */
router.post('/login', loginLimiter, authController.login);

/**
 * POST /api/auth/refresh
 * Renova access token
 */
router.post('/refresh', authController.refresh);

/**
 * POST /api/auth/logout
 * Revoga refresh token
 */
router.post('/logout', authenticate, authController.logout);

/**
 * POST /api/auth/google
 * Autentica usuário via Google Sign-In
 */
router.post('/google', authController.googleAuth);

module.exports = router;
