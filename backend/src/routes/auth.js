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

/**
 * POST /api/auth/verify-email
 * Verifica email do usuário com token
 */
router.post('/verify-email', authController.verifyEmail);

/**
 * POST /api/auth/resend-verification
 * Reenvia email de verificação
 */
router.post('/resend-verification', authController.resendVerification);

/**
 * POST /api/auth/forgot-password
 * Envia email de redefinição de senha
 */
router.post('/forgot-password', authController.forgotPassword);

/**
 * POST /api/auth/reset-password
 * Redefine senha com token
 */
router.post('/reset-password', authController.resetPassword);

module.exports = router;
