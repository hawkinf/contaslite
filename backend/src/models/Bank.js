const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo Bank - Contas bancárias do usuário
 *
 * Campos do Flutter (BankAccount):
 * - id, code, name, description, agency, account, color
 */
const Bank = sequelize.define('Bank', {
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
  code: {
    type: DataTypes.INTEGER,
    allowNull: false,
    comment: 'Código do banco (ex: 001 para BB, 341 para Itaú)'
  },
  name: {
    type: DataTypes.STRING(100),
    allowNull: false,
    comment: 'Nome do banco'
  },
  description: {
    type: DataTypes.STRING(255),
    defaultValue: '',
    comment: 'Descrição/apelido da conta'
  },
  agency: {
    type: DataTypes.STRING(20),
    allowNull: false,
    comment: 'Número da agência'
  },
  account: {
    type: DataTypes.STRING(30),
    allowNull: false,
    comment: 'Número da conta'
  },
  color: {
    type: DataTypes.BIGINT,
    defaultValue: 0xFF1565C0,
    comment: 'Cor para exibição (código hexadecimal)'
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
  tableName: 'banks',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['code'] },
    { fields: ['updated_at'] },
    {
      fields: ['user_id', 'agency', 'account'],
      unique: true,
      where: { deleted_at: null }
    }
  ]
});

Bank.beforeUpdate((bank) => {
  bank.updated_at = new Date();
});

Bank.beforeCreate((bank) => {
  bank.created_at = new Date();
  bank.updated_at = new Date();
});

/**
 * Converte dados do Flutter para o formato do banco
 */
Bank.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    code: data.code,
    name: data.name,
    description: data.description || '',
    agency: data.agency,
    account: data.account,
    color: data.color || 0xFF1565C0
  };
};

/**
 * Converte dados do banco para o formato do Flutter
 */
Bank.prototype.toFlutterData = function() {
  return {
    id: this.id,
    code: this.code,
    name: this.name,
    description: this.description,
    agency: this.agency,
    account: this.account,
    color: this.color,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

module.exports = Bank;
