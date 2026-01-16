const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo Payment - Registro de pagamentos realizados
 *
 * Campos do Flutter (Payment):
 * - id, account_id, payment_method_id, bank_account_id, credit_card_id
 * - value, payment_date, observation, created_at
 */
const Payment = sequelize.define('Payment', {
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
  account_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'accounts',
      key: 'id'
    },
    onDelete: 'CASCADE',
    comment: 'Conta que foi paga'
  },
  payment_method_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'payment_methods',
      key: 'id'
    },
    onDelete: 'SET NULL',
    comment: 'Método de pagamento utilizado'
  },
  bank_account_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'banks',
      key: 'id'
    },
    onDelete: 'SET NULL',
    comment: 'Conta bancária utilizada (se aplicável)'
  },
  credit_card_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'accounts',
      key: 'id'
    },
    onDelete: 'SET NULL',
    comment: 'Cartão de crédito utilizado (referência a Account com cardBrand)'
  },
  value: {
    type: DataTypes.DECIMAL(15, 2),
    allowNull: false,
    comment: 'Valor pago'
  },
  payment_date: {
    type: DataTypes.STRING(50),
    allowNull: false,
    comment: 'Data do pagamento (formato ISO)'
  },
  observation: {
    type: DataTypes.TEXT,
    comment: 'Observações sobre o pagamento'
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
  tableName: 'payments',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['account_id'] },
    { fields: ['payment_method_id'] },
    { fields: ['bank_account_id'] },
    { fields: ['credit_card_id'] },
    { fields: ['payment_date'] },
    { fields: ['updated_at'] }
  ]
});

Payment.beforeUpdate((payment) => {
  payment.updated_at = new Date();
});

Payment.beforeCreate((payment) => {
  payment.created_at = new Date();
  payment.updated_at = new Date();
});

/**
 * Converte dados do Flutter para o formato do banco
 */
Payment.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    account_id: data.account_id || data.accountId,
    payment_method_id: data.payment_method_id || data.paymentMethodId,
    bank_account_id: data.bank_account_id || data.bankAccountId,
    credit_card_id: data.credit_card_id || data.creditCardId,
    value: data.value,
    payment_date: data.payment_date || data.paymentDate,
    observation: data.observation
  };
};

/**
 * Converte dados do banco para o formato do Flutter
 */
Payment.prototype.toFlutterData = function() {
  return {
    id: this.id,
    account_id: this.account_id,
    payment_method_id: this.payment_method_id,
    bank_account_id: this.bank_account_id,
    credit_card_id: this.credit_card_id,
    value: parseFloat(this.value) || 0,
    payment_date: this.payment_date,
    observation: this.observation,
    created_at: this.created_at ? this.created_at.toISOString() : null,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

module.exports = Payment;
