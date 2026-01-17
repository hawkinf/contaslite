const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { OAuth2Client } = require('google-auth-library');
const { User, RefreshToken, AccountType, PaymentMethod } = require('../models');
const jwtConfig = require('../config/jwt');
const logger = require('../utils/logger');

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

    // Criar usuário
    const user = await User.create({
      email,
      password_hash: password, // Será hasheada no beforeCreate hook
      name
    });

    // Criar dados padrão para o novo usuário
    try {
      await createDefaultDataForUser(user.id);
      logger.info(`Default data created for user: ${user.id}`);
    } catch (defaultError) {
      logger.warn(`Failed to create default data for user ${user.id}:`, defaultError.message);
      // Não falha o registro se os dados padrão não puderem ser criados
    }

    // Gerar tokens
    const { accessToken, refreshToken, expiresIn } = await generateTokens(user.id);

    logger.info(`User registered: ${user.id} - ${user.email}`);

    return res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        createdAt: user.created_at
      },
      accessToken,
      refreshToken,
      expiresIn
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

module.exports = {
  register,
  login,
  refresh,
  logout,
  googleAuth
};
