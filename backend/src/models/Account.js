const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Account = sequelize.define('Account', {
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
  type_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'account_types',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },
  category_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'categories',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },
  subcategory_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'subcategories',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },
  payment_method_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'payment_methods',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  amount: {
    type: DataTypes.DECIMAL(15, 2),
    allowNull: false
  },
  due_date: {
    type: DataTypes.DATEONLY,
    allowNull: false
  },
  payment_date: {
    type: DataTypes.DATEONLY
  },
  status: {
    type: DataTypes.STRING(20),
    allowNull: false,
    defaultValue: 'pending',
    validate: {
      isIn: [['pending', 'paid', 'overdue', 'cancelled']]
    }
  },
  notes: {
    type: DataTypes.TEXT
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
  tableName: 'accounts',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['type_id'] },
    { fields: ['category_id'] },
    { fields: ['due_date'] },
    { fields: ['status'] },
    { fields: ['updated_at'] },
    { fields: ['deleted_at'] }
  ]
});

Account.beforeUpdate((account) => {
  account.updated_at = new Date();
});

module.exports = Account;
