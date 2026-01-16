const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo AccountType - Tipos de conta (ex: Cartões de Crédito, Consumo, Saúde, etc.)
 *
 * No Flutter, os tipos são globais (compartilhados entre usuários).
 * No backend, mantemos por usuário para isolamento de dados em multi-tenant.
 */
const AccountType = sequelize.define('AccountType', {
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
  name: {
    type: DataTypes.STRING(100),
    allowNull: false
  },
  logo: {
    type: DataTypes.STRING(255),
    comment: 'Emoji ou identificador visual'
  },
  created_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  updated_at: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW
  },
  deleted_at: {
    type: DataTypes.DATE
  }
}, {
  tableName: 'account_types',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['name'] },
    { fields: ['updated_at'] },
    {
      fields: ['user_id', 'name'],
      unique: true,
      where: { deleted_at: null }
    }
  ]
});

AccountType.beforeUpdate((type) => {
  type.updated_at = new Date();
});

AccountType.beforeCreate((type) => {
  type.created_at = new Date();
  type.updated_at = new Date();
});

/**
 * Converte dados do Flutter para o formato do banco
 */
AccountType.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    name: data.name,
    logo: data.logo
  };
};

/**
 * Converte dados do banco para o formato do Flutter
 */
AccountType.prototype.toFlutterData = function() {
  return {
    id: this.id,
    name: this.name,
    logo: this.logo,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

/**
 * Cria tipos padrão para um novo usuário
 */
AccountType.createDefaultsForUser = async function(userId) {
  const defaults = [
    { name: 'Cartões de Crédito', logo: '💳' },
    { name: 'Consumo', logo: '🛒' },
    { name: 'Saúde', logo: '🏥' },
    { name: 'Educação', logo: '📚' },
    { name: 'Moradia', logo: '🏠' },
    { name: 'Transporte', logo: '🚗' }
  ];

  const types = [];
  for (const def of defaults) {
    const type = await AccountType.create({
      user_id: userId,
      name: def.name,
      logo: def.logo
    });
    types.push(type);
  }
  return types;
};

module.exports = AccountType;
