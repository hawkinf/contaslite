const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const { testConnection } = require('./config/database');
const logger = require('./utils/logger');

// Carregar modelos (inicializa associações)
const { sequelize } = require('./models');

// Routes
const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de segurança
app.use(helmet());

// CORS
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/health/db', async (req, res) => {
  try {
    const { sequelize } = require('./config/database');
    await sequelize.authenticate();
    res.status(200).json({
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/sync', syncRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'Endpoint não encontrado'
  });
});

// Error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' 
      ? 'Erro interno do servidor' 
      : err.message
  });
});

// Iniciar servidor
const startServer = async () => {
  try {
    // Testar conexão com banco
    await testConnection();

    // Sincronizar modelos (apenas em dev, em prod use migrations)
    if (process.env.NODE_ENV === 'development') {
      await sequelize.sync({ alter: true });
      logger.info('Database models synchronized');
    }

    // Iniciar servidor
    app.listen(PORT, () => {
      logger.info(`🚀 Server running on port ${PORT}`);
      logger.info(`📝 Environment: ${process.env.NODE_ENV}`);
      logger.info(`🔗 Health check: http://localhost:${PORT}/health`);
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();

module.exports = app;
