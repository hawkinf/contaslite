const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const crypto = require('crypto');

const RefreshToken = sequelize.define('RefreshToken', {
  id: {
    type: DataTypes.INTEGER,
    primaryKey: true,
    autoIncrement: true
  },
  user_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'users',
      key: 'id'
    },
    onDelete: 'CASCADE'
  },
  token_hash: {
    type: DataTypes.STRING(255),
    allowNull: false,
    unique: true
  },
  expires_at: {
    type: DataTypes.DATE,
    allowNull: false
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  revoked: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  device_info: {
    type: DataTypes.TEXT
  }
}, {
  tableName: 'refresh_tokens',
  timestamps: false,
  indexes: [
    { fields: ['user_id'] },
    { fields: ['token_hash'] },
    { fields: ['expires_at'] }
  ]
});

// Hash token before saving
RefreshToken.beforeCreate((token) => {
  if (token.token_hash && !token.token_hash.startsWith('$2')) {
    token.token_hash = crypto
      .createHash('sha256')
      .update(token.token_hash)
      .digest('hex');
  }
});

module.exports = RefreshToken;
