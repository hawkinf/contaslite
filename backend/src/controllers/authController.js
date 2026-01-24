const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { OAuth2Client } = require('google-auth-library');
const bcrypt = require('bcrypt');
const { User, RefreshToken, AccountType, PaymentMethod } = require('../models');
const jwtConfig = require('../config/jwt');
const logger = require('../utils/logger');
const emailService = require('../services/emailService');

// Cliente OAuth2 do Google para verificação de tokens
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

/**
 * POST /api/auth/register
 * Registra novo usuário
 */
const register = async (req, res) => {
  try {
    const { email, password, name } = req.body;

    // Validações básicas
    if (!email || !password || !name) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email, senha e nome são obrigatórios'
      });
    }

    // Validar formato de email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email inválido'
      });
    }

    // Validar força da senha
    if (password.length < 8) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Senha deve ter no mínimo 8 caracteres'
      });
    }

    if (!/[A-Z]/.test(password) || !/[0-9]/.test(password)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Senha deve conter pelo menos 1 letra maiúscula e 1 número'
      });
    }

    // Validar nome
    if (name.length < 2) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Nome deve ter no mínimo 2 caracteres'
      });
    }

    // Verificar se email já existe
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email já cadastrado'
      });
    }

    // Gerar token de verificação
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date();
    verificationExpires.setHours(verificationExpires.getHours() + 24); // 24 horas

    // Criar usuário
    const user = await User.create({
      email,
      password_hash: password, // Será hasheada no beforeCreate hook
      name,
      email_verified: false,
      verification_token: verificationToken,
      verification_expires: verificationExpires
    });

    // Criar dados padrão para o novo usuário
    try {
      await createDefaultDataForUser(user.id);
      logger.info(`Default data created for user: ${user.id}`);
    } catch (defaultError) {
      logger.warn(`Failed to create default data for user ${user.id}:`, defaultError.message);
    }

    // Enviar email de verificação
    try {
      emailService.initialize();
      if (emailService.isConfigured()) {
        const verificationUrl = `${process.env.APP_URL || 'contaslite://'}verify-email?token=${verificationToken}`;
        const html = generateVerificationEmailHtml(user.name, verificationToken, verificationUrl);
        await emailService.sendEmail(user.email, '📧 Confirme seu cadastro - Contaslite', html);
        logger.info(`Verification email sent to: ${user.email}`);
      } else {
        logger.warn('Email service not configured, skipping verification email');
      }
    } catch (emailError) {
      logger.error('Failed to send verification email:', emailError.message);
    }

    logger.info(`User registered (pending verification): ${user.id} - ${user.email}`);

    return res.status(201).json({
      success: true,
      message: 'Cadastro realizado! Verifique seu email para ativar sua conta.',
      requiresVerification: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        emailVerified: false
      }
    });

  } catch (error) {
    logger.error('Register error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao registrar usuário'
    });
  }
};

/**
 * POST /api/auth/login
 * Autentica usuário existente
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email e senha são obrigatórios'
      });
    }

    // Buscar usuário
    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Email ou senha incorretos'
      });
    }

    // Verificar se está ativo
    if (!user.is_active) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Conta desativada'
      });
    }

    // Verificar se email foi verificado (apenas para usuários não-Google)
    if (!user.google_id && !user.email_verified) {
      return res.status(403).json({
        error: 'EmailNotVerified',
        message: 'Email não verificado. Verifique sua caixa de entrada.',
        requiresVerification: true
      });
    }

    // Verificar senha
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Email ou senha incorretos'
      });
    }

    // Atualizar last_login
    await user.update({ last_login: new Date() });

    // Gerar tokens
    const { accessToken, refreshToken, expiresIn } = await generateTokens(user.id);

    logger.info(`User logged in: ${user.id} - ${user.email}`);

    return res.status(200).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      },
      accessToken,
      refreshToken,
      expiresIn
    });

  } catch (error) {
    logger.error('Login error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao fazer login'
    });
  }
};

/**
 * POST /api/auth/refresh
 * Renova access token usando refresh token
 */
const refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Refresh token é obrigatório'
      });
    }

    // Verificar token
    let decoded;
    try {
      decoded = jwt.verify(refreshToken, jwtConfig.refreshToken.secret);
    } catch (error) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Refresh token inválido'
      });
    }

    // Hash do token para buscar no banco
    const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

    // Buscar refresh token no banco
    const storedToken = await RefreshToken.findOne({
      where: {
        token_hash: tokenHash,
        user_id: decoded.userId
      }
    });

    if (!storedToken) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Refresh token não encontrado'
      });
    }

    if (storedToken.revoked) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Refresh token foi revogado'
      });
    }

    if (new Date() > storedToken.expires_at) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Refresh token expirado'
      });
    }

    // Gerar novos tokens
    const tokens = await generateTokens(decoded.userId);

    // Revogar token antigo
    await storedToken.update({ revoked: true });

    logger.info(`Tokens refreshed for user: ${decoded.userId}`);

    return res.status(200).json(tokens);

  } catch (error) {
    logger.error('Refresh error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao renovar token'
    });
  }
};

/**
 * POST /api/auth/logout
 * Revoga refresh token do usuário
 */
const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Refresh token é obrigatório'
      });
    }

    // Hash do token
    const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

    // Buscar e revogar token
    const storedToken = await RefreshToken.findOne({
      where: { token_hash: tokenHash }
    });

    if (storedToken) {
      await storedToken.update({ revoked: true });
      logger.info(`User logged out: ${storedToken.user_id}`);
    }

    return res.status(200).json({
      message: 'Logout realizado com sucesso'
    });

  } catch (error) {
    logger.error('Logout error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao fazer logout'
    });
  }
};

/**
 * Função auxiliar para gerar access e refresh tokens
 */
const generateTokens = async (userId) => {
  // Gerar access token
  const accessToken = jwt.sign(
    { userId },
    jwtConfig.accessToken.secret,
    {
      expiresIn: jwtConfig.accessToken.expiresIn,
      algorithm: jwtConfig.accessToken.algorithm
    }
  );

  // Gerar refresh token
  const tokenId = uuidv4();
  const refreshToken = jwt.sign(
    { userId, tokenId },
    jwtConfig.refreshToken.secret,
    {
      expiresIn: jwtConfig.refreshToken.expiresIn,
      algorithm: jwtConfig.refreshToken.algorithm
    }
  );

  // Salvar refresh token no banco
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30); // 30 dias

  await RefreshToken.create({
    user_id: userId,
    token_hash: refreshToken, // Será hasheado no beforeCreate hook
    expires_at: expiresAt
  });

  return {
    accessToken,
    refreshToken,
    expiresIn: 3600 // 1 hora em segundos
  };
};

/**
 * Cria dados padrão para um novo usuário (tipos de conta e métodos de pagamento)
 */
const createDefaultDataForUser = async (userId) => {
  // Criar tipos de conta padrão
  const defaultAccountTypes = [
    { name: 'Cartões de Crédito', logo: '💳' },
    { name: 'Consumo', logo: '🛒' },
    { name: 'Saúde', logo: '🏥' },
    { name: 'Educação', logo: '📚' },
    { name: 'Moradia', logo: '🏠' },
    { name: 'Transporte', logo: '🚗' }
  ];

  for (const type of defaultAccountTypes) {
    await AccountType.create({
      user_id: userId,
      name: type.name,
      logo: type.logo
    });
  }

  // Criar métodos de pagamento padrão
  const defaultPaymentMethods = [
    { name: 'Cartão de Crédito', type: 'credit_card', icon_code: 0xe19f, requires_bank: false, usage: 0 },
    { name: 'Crédito em conta', type: 'credit', icon_code: 0xe1f5, requires_bank: true, usage: 1 },
    { name: 'Dinheiro', type: 'cash', icon_code: 0xe19e, requires_bank: false, usage: 2 },
    { name: 'Débito C/C', type: 'debit', icon_code: 0xe19f, requires_bank: true, usage: 0 },
    { name: 'Internet Banking', type: 'transfer', icon_code: 0xe157, requires_bank: true, usage: 2 },
    { name: 'PIX', type: 'pix', icon_code: 0xef6e, requires_bank: true, usage: 2 }
  ];

  for (const method of defaultPaymentMethods) {
    await PaymentMethod.create({
      user_id: userId,
      ...method
    });
  }
};

/**
 * POST /api/auth/google
 * Autentica usuário via Google Sign-In
 */
const googleAuth = async (req, res) => {
  try {
    const { idToken, email, name, photoUrl } = req.body;

    if (!idToken) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'ID Token do Google é obrigatório'
      });
    }

    // Verificar o token do Google
    let googlePayload;
    try {
      const ticket = await googleClient.verifyIdToken({
        idToken: idToken,
        audience: process.env.GOOGLE_CLIENT_ID
      });
      googlePayload = ticket.getPayload();
    } catch (verifyError) {
      logger.warn('Google token verification failed:', verifyError.message);
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Token do Google inválido ou expirado'
      });
    }

    // Extrair informações do token verificado
    const googleEmail = googlePayload.email;
    const googleName = googlePayload.name || name;
    const googlePicture = googlePayload.picture || photoUrl;
    const googleSub = googlePayload.sub; // ID único do Google

    if (!googleEmail) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email não encontrado no token do Google'
      });
    }

    // Buscar ou criar usuário
    let user = await User.findOne({ where: { email: googleEmail } });
    let isNewUser = false;

    if (!user) {
      // Criar novo usuário (sem senha, pois usa Google)
      isNewUser = true;
      user = await User.create({
        email: googleEmail,
        password_hash: null, // Usuários Google não têm senha
        name: googleName || googleEmail.split('@')[0],
        google_id: googleSub,
        photo_url: googlePicture,
        is_active: true
      });

      // Criar dados padrão para o novo usuário
      try {
        await createDefaultDataForUser(user.id);
        logger.info(`Default data created for Google user: ${user.id}`);
      } catch (defaultError) {
        logger.warn(`Failed to create default data for user ${user.id}:`, defaultError.message);
      }

      logger.info(`New user registered via Google: ${user.id} - ${user.email}`);
    } else {
      // Atualizar informações do Google se necessário
      const updates = {};
      if (!user.google_id && googleSub) {
        updates.google_id = googleSub;
      }
      if (googlePicture && user.photo_url !== googlePicture) {
        updates.photo_url = googlePicture;
      }
      if (googleName && !user.name) {
        updates.name = googleName;
      }
      updates.last_login = new Date();

      if (Object.keys(updates).length > 0) {
        await user.update(updates);
      }

      logger.info(`User logged in via Google: ${user.id} - ${user.email}`);
    }

    // Verificar se está ativo
    if (!user.is_active) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Conta desativada'
      });
    }

    // Gerar tokens JWT do nosso sistema
    const { accessToken, refreshToken, expiresIn } = await generateTokens(user.id);

    const statusCode = isNewUser ? 201 : 200;

    return res.status(statusCode).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        photoUrl: user.photo_url,
        createdAt: user.created_at
      },
      accessToken,
      refreshToken,
      expiresIn,
      isNewUser
    });

  } catch (error) {
    logger.error('Google Auth error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao autenticar com Google'
    });
  }
};

/**
 * Gera HTML do email de verificação
 */
const generateVerificationEmailHtml = (userName, token, verificationUrl) => {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Confirme seu cadastro</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px;">📧 Contaslite</h1>
      <p style="color: rgba(255,255,255,0.9); margin-top: 10px;">Confirme seu cadastro</p>
    </div>

    <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
      <p style="font-size: 16px; color: #333;">Olá <strong>${userName}</strong>,</p>

      <p style="font-size: 14px; color: #666; line-height: 1.6;">
        Obrigado por se cadastrar no Contaslite! Para ativar sua conta, clique no botão abaixo:
      </p>

      <div style="text-align: center; margin: 30px 0;">
        <a href="${verificationUrl}" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">
          ✓ Confirmar Email
        </a>
      </div>

      <p style="font-size: 12px; color: #999; line-height: 1.6;">
        Se o botão não funcionar, copie e cole este link no seu navegador:<br>
        <a href="${verificationUrl}" style="color: #667eea; word-break: break-all;">${verificationUrl}</a>
      </p>

      <p style="font-size: 12px; color: #999; margin-top: 20px;">
        <strong>Código de verificação:</strong> ${token.substring(0, 8)}...
      </p>

      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">

      <p style="font-size: 12px; color: #999; text-align: center;">
        Este link expira em 24 horas.<br>
        Se você não criou esta conta, ignore este email.
      </p>
    </div>

    <p style="text-align: center; color: #999; font-size: 11px; margin-top: 20px;">
      © ${new Date().getFullYear()} Contaslite - Gerenciamento Financeiro
    </p>
  </div>
</body>
</html>
  `;
};

/**
 * Gera HTML do email de reset de senha
 */
const generatePasswordResetEmailHtml = (userName, token, resetUrl) => {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Redefinir senha</title>
</head>
<body style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
      <h1 style="color: white; margin: 0; font-size: 28px;">🔐 Contaslite</h1>
      <p style="color: rgba(255,255,255,0.9); margin-top: 10px;">Redefinição de Senha</p>
    </div>

    <div style="background: white; padding: 30px; border-radius: 0 0 10px 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">
      <p style="font-size: 16px; color: #333;">Olá <strong>${userName}</strong>,</p>

      <p style="font-size: 14px; color: #666; line-height: 1.6;">
        Recebemos uma solicitação para redefinir a senha da sua conta. Clique no botão abaixo para criar uma nova senha:
      </p>

      <div style="text-align: center; margin: 30px 0;">
        <a href="${resetUrl}" style="display: inline-block; background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 15px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 16px;">
          🔑 Redefinir Senha
        </a>
      </div>

      <p style="font-size: 12px; color: #999; line-height: 1.6;">
        Se o botão não funcionar, copie e cole este link no seu navegador:<br>
        <a href="${resetUrl}" style="color: #f5576c; word-break: break-all;">${resetUrl}</a>
      </p>

      <div style="background: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 8px; margin-top: 20px;">
        <p style="font-size: 12px; color: #856404; margin: 0;">
          <strong>⚠️ Atenção:</strong> Este link expira em 1 hora por motivos de segurança.
        </p>
      </div>

      <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">

      <p style="font-size: 12px; color: #999; text-align: center;">
        Se você não solicitou a redefinição de senha, ignore este email.<br>
        Sua senha permanecerá inalterada.
      </p>
    </div>

    <p style="text-align: center; color: #999; font-size: 11px; margin-top: 20px;">
      © ${new Date().getFullYear()} Contaslite - Gerenciamento Financeiro
    </p>
  </div>
</body>
</html>
  `;
};

/**
 * POST /api/auth/verify-email
 * Verifica email do usuário com o token
 */
const verifyEmail = async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Token de verificação é obrigatório'
      });
    }

    // Buscar usuário pelo token
    const user = await User.findOne({
      where: { verification_token: token }
    });

    if (!user) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Token de verificação inválido'
      });
    }

    // Verificar se token expirou
    if (new Date() > user.verification_expires) {
      return res.status(400).json({
        error: 'TokenExpired',
        message: 'Token de verificação expirado. Solicite um novo email de verificação.'
      });
    }

    // Atualizar usuário como verificado
    await user.update({
      email_verified: true,
      verification_token: null,
      verification_expires: null
    });

    logger.info(`Email verified for user: ${user.id} - ${user.email}`);

    return res.status(200).json({
      success: true,
      message: 'Email verificado com sucesso! Você já pode fazer login.'
    });

  } catch (error) {
    logger.error('Verify email error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao verificar email'
    });
  }
};

/**
 * POST /api/auth/resend-verification
 * Reenvia email de verificação
 */
const resendVerification = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email é obrigatório'
      });
    }

    const user = await User.findOne({ where: { email } });

    if (!user) {
      // Por segurança, não revelamos se o email existe ou não
      return res.status(200).json({
        success: true,
        message: 'Se o email estiver cadastrado, você receberá um email de verificação.'
      });
    }

    // Se já verificado
    if (user.email_verified) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Este email já foi verificado. Faça login normalmente.'
      });
    }

    // Se é usuário Google
    if (user.google_id) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Contas Google não precisam de verificação de email.'
      });
    }

    // Gerar novo token
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationExpires = new Date();
    verificationExpires.setHours(verificationExpires.getHours() + 24);

    await user.update({
      verification_token: verificationToken,
      verification_expires: verificationExpires
    });

    // Enviar email
    try {
      emailService.initialize();
      if (emailService.isConfigured()) {
        const verificationUrl = `${process.env.APP_URL || 'contaslite://'}verify-email?token=${verificationToken}`;
        const html = generateVerificationEmailHtml(user.name, verificationToken, verificationUrl);
        await emailService.sendEmail(user.email, '📧 Confirme seu cadastro - Contaslite', html);
        logger.info(`Verification email resent to: ${user.email}`);
      }
    } catch (emailError) {
      logger.error('Failed to resend verification email:', emailError.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Se o email estiver cadastrado, você receberá um email de verificação.'
    });

  } catch (error) {
    logger.error('Resend verification error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao reenviar email de verificação'
    });
  }
};

/**
 * POST /api/auth/forgot-password
 * Envia email de redefinição de senha
 */
const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Email é obrigatório'
      });
    }

    const user = await User.findOne({ where: { email } });

    // Por segurança, sempre retornamos sucesso
    if (!user) {
      return res.status(200).json({
        success: true,
        message: 'Se o email estiver cadastrado, você receberá instruções para redefinir sua senha.'
      });
    }

    // Se é usuário Google (não tem senha)
    if (user.google_id && !user.password_hash) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Esta conta usa login com Google. Use o botão "Entrar com Google" para acessar.'
      });
    }

    // Gerar token de reset
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetExpires = new Date();
    resetExpires.setHours(resetExpires.getHours() + 1); // 1 hora

    await user.update({
      reset_token: resetToken,
      reset_token_expires: resetExpires
    });

    // Enviar email
    try {
      emailService.initialize();
      if (emailService.isConfigured()) {
        const resetUrl = `${process.env.APP_URL || 'contaslite://'}reset-password?token=${resetToken}`;
        const html = generatePasswordResetEmailHtml(user.name, resetToken, resetUrl);
        await emailService.sendEmail(user.email, '🔐 Redefinir senha - Contaslite', html);
        logger.info(`Password reset email sent to: ${user.email}`);
      } else {
        logger.warn('Email service not configured, cannot send password reset');
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Serviço de email não configurado. Entre em contato com o suporte.'
        });
      }
    } catch (emailError) {
      logger.error('Failed to send password reset email:', emailError.message);
      return res.status(500).json({
        error: 'Internal Server Error',
        message: 'Erro ao enviar email de redefinição'
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Se o email estiver cadastrado, você receberá instruções para redefinir sua senha.'
    });

  } catch (error) {
    logger.error('Forgot password error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao processar solicitação'
    });
  }
};

/**
 * POST /api/auth/reset-password
 * Redefine a senha usando o token
 */
const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Token e nova senha são obrigatórios'
      });
    }

    // Validar força da senha
    if (newPassword.length < 8) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Senha deve ter no mínimo 8 caracteres'
      });
    }

    if (!/[A-Z]/.test(newPassword) || !/[0-9]/.test(newPassword)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Senha deve conter pelo menos 1 letra maiúscula e 1 número'
      });
    }

    // Buscar usuário pelo token
    const user = await User.findOne({
      where: { reset_token: token }
    });

    if (!user) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Token de redefinição inválido'
      });
    }

    // Verificar se token expirou
    if (new Date() > user.reset_token_expires) {
      return res.status(400).json({
        error: 'TokenExpired',
        message: 'Token de redefinição expirado. Solicite uma nova redefinição de senha.'
      });
    }

    // Atualizar senha (será hasheada no beforeUpdate hook se existir, ou manualmente)
    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await user.update({
      password_hash: hashedPassword,
      reset_token: null,
      reset_token_expires: null,
      email_verified: true // Se conseguiu redefinir senha via email, o email é válido
    });

    logger.info(`Password reset for user: ${user.id} - ${user.email}`);

    return res.status(200).json({
      success: true,
      message: 'Senha redefinida com sucesso! Você já pode fazer login.'
    });

  } catch (error) {
    logger.error('Reset password error:', error);
    return res.status(500).json({
      error: 'Internal Server Error',
      message: 'Erro ao redefinir senha'
    });
  }
};

module.exports = {
  register,
  login,
  refresh,
  logout,
  googleAuth,
  verifyEmail,
  resendVerification,
  forgotPassword,
  resetPassword
};
