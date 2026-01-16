const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo AccountDescription - Subcategorias de tipos de conta
 *
 * No Flutter: account_descriptions (subcategorias vinculadas a account_types)
 * Campos: id, accountId (FK para account_types), description, logo
 */
const AccountDescription = sequelize.define('AccountDescription', {
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
  account_type_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    field: 'account_id',
    references: {
      model: 'account_types',
      key: 'id'
    },
    onDelete: 'CASCADE',
    comment: 'FK para account_types (Flutter chama de accountId)'
  },
  description: {
    type: DataTypes.STRING(255),
    allowNull: false,
    comment: 'Nome da subcategoria (Flutter chama de categoria)'
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
  tableName: 'account_descriptions',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['account_id'] },
    { fields: ['updated_at'] },
    {
      fields: ['user_id', 'account_id', 'description'],
      unique: true,
      where: { deleted_at: null }
    }
  ]
});

AccountDescription.beforeUpdate((desc) => {
  desc.updated_at = new Date();
});

AccountDescription.beforeCreate((desc) => {
  desc.created_at = new Date();
  desc.updated_at = new Date();
});

/**
 * Converte dados do Flutter para o formato do banco
 * Flutter envia: { accountId, description (como 'categoria'), logo }
 */
AccountDescription.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    account_type_id: data.accountId,
    description: data.description || data.categoria,
    logo: data.logo
  };
};

/**
 * Converte dados do banco para o formato do Flutter
 * Flutter espera: { id, accountId, description, logo }
 */
AccountDescription.prototype.toFlutterData = function() {
  return {
    id: this.id,
    accountId: this.account_type_id,
    description: this.description,
    logo: this.logo,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

module.exports = AccountDescription;
