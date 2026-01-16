const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo Account - Representa contas a pagar/receber, cartões de crédito e suas despesas
 *
 * Campos específicos para cartões de crédito:
 * - cardBrand != null indica que é um cartão de crédito
 * - cardId indica uma despesa vinculada a um cartão
 * - purchaseUuid agrupa parcelas de uma mesma compra
 * - recurrenceId indica o ID do registro pai para contas recorrentes
 */
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

  // Referências para classificação
  type_id: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: {
      model: 'account_types',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },
  category_id: {
    type: DataTypes.INTEGER,
    references: {
      model: 'account_descriptions',
      key: 'id'
    },
    onDelete: 'SET NULL'
  },

  // Dados principais
  description: {
    type: DataTypes.TEXT,
    allowNull: false
  },
  value: {
    type: DataTypes.DECIMAL(15, 2),
    allowNull: false,
    defaultValue: 0
  },
  estimated_value: {
    type: DataTypes.DECIMAL(15, 2),
    comment: 'Valor previsto/médio para recorrências'
  },

  // Data de vencimento (dia + mês + ano)
  due_day: {
    type: DataTypes.INTEGER,
    allowNull: false,
    validate: {
      min: 1,
      max: 31
    }
  },
  month: {
    type: DataTypes.INTEGER,
    validate: {
      min: 1,
      max: 12
    }
  },
  year: {
    type: DataTypes.INTEGER,
    validate: {
      min: 2000,
      max: 2100
    }
  },

  // Recorrência
  is_recurrent: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  pay_in_advance: {
    type: DataTypes.BOOLEAN,
    defaultValue: false
  },
  recurrence_id: {
    type: DataTypes.INTEGER,
    comment: 'ID do registro pai para contas recorrentes'
  },

  // Parcelamento
  installment_index: {
    type: DataTypes.INTEGER,
    comment: 'Número da parcela atual (1, 2, 3...)'
  },
  installment_total: {
    type: DataTypes.INTEGER,
    comment: 'Total de parcelas'
  },
  purchase_uuid: {
    type: DataTypes.STRING(36),
    comment: 'UUID que agrupa todas as parcelas de uma compra'
  },

  // Campos específicos para cartão de crédito
  best_buy_day: {
    type: DataTypes.INTEGER,
    validate: {
      min: 1,
      max: 31
    },
    comment: 'Melhor dia para compras (ciclo do cartão)'
  },
  card_brand: {
    type: DataTypes.STRING(50),
    comment: 'Bandeira do cartão (Visa, Mastercard, etc.) - se preenchido, é um cartão'
  },
  card_bank: {
    type: DataTypes.STRING(100),
    comment: 'Banco emissor do cartão'
  },
  card_limit: {
    type: DataTypes.DECIMAL(15, 2),
    comment: 'Limite do cartão de crédito'
  },
  card_color: {
    type: DataTypes.BIGINT,
    comment: 'Cor do cartão (código hexadecimal)'
  },

  // Rastreamento de despesas do cartão
  card_id: {
    type: DataTypes.INTEGER,
    comment: 'ID do cartão ao qual esta despesa pertence'
  },

  // Campos adicionais
  logo: {
    type: DataTypes.STRING(255),
    comment: 'Emoji ou identificador visual'
  },
  observation: {
    type: DataTypes.TEXT,
    comment: 'Observações/notas'
  },
  establishment: {
    type: DataTypes.STRING(255),
    comment: 'Nome do estabelecimento'
  },
  purchase_date: {
    type: DataTypes.STRING(50),
    comment: 'Data da compra (formato ISO)'
  },
  creation_date: {
    type: DataTypes.STRING(50),
    comment: 'Data de criação do registro (formato ISO)'
  },

  // Timestamps e soft delete
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
    { fields: ['month', 'year'] },
    { fields: ['card_id'] },
    { fields: ['purchase_uuid'] },
    { fields: ['recurrence_id'] },
    { fields: ['is_recurrent'] },
    { fields: ['updated_at'] },
    { fields: ['deleted_at'] }
  ]
});

Account.beforeUpdate((account) => {
  account.updated_at = new Date();
});

Account.beforeCreate((account) => {
  account.created_at = new Date();
  account.updated_at = new Date();
});

/**
 * Converte dados do Flutter (camelCase) para o formato do banco (snake_case)
 */
Account.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    type_id: data.typeId,
    category_id: data.categoryId,
    description: data.description,
    value: data.value,
    estimated_value: data.estimatedValue,
    due_day: data.dueDay,
    month: data.month,
    year: data.year,
    is_recurrent: data.isRecurrent === 1 || data.isRecurrent === true,
    pay_in_advance: data.payInAdvance === 1 || data.payInAdvance === true,
    recurrence_id: data.recurrenceId,
    installment_index: data.installmentIndex,
    installment_total: data.installmentTotal,
    purchase_uuid: data.purchaseUuid,
    best_buy_day: data.bestBuyDay,
    card_brand: data.cardBrand,
    card_bank: data.cardBank,
    card_limit: data.cardLimit,
    card_color: data.cardColor,
    card_id: data.cardId,
    logo: data.logo,
    observation: data.observation,
    establishment: data.establishment,
    purchase_date: data.purchaseDate,
    creation_date: data.creationDate
  };
};

/**
 * Converte dados do banco para o formato do Flutter (camelCase)
 */
Account.prototype.toFlutterData = function() {
  return {
    id: this.id,
    typeId: this.type_id,
    categoryId: this.category_id,
    description: this.description,
    value: parseFloat(this.value) || 0,
    estimatedValue: this.estimated_value ? parseFloat(this.estimated_value) : null,
    dueDay: this.due_day,
    month: this.month,
    year: this.year,
    isRecurrent: this.is_recurrent ? 1 : 0,
    payInAdvance: this.pay_in_advance ? 1 : 0,
    recurrenceId: this.recurrence_id,
    installmentIndex: this.installment_index,
    installmentTotal: this.installment_total,
    purchaseUuid: this.purchase_uuid,
    bestBuyDay: this.best_buy_day,
    cardBrand: this.card_brand,
    cardBank: this.card_bank,
    cardLimit: this.card_limit ? parseFloat(this.card_limit) : null,
    cardColor: this.card_color,
    cardId: this.card_id,
    logo: this.logo,
    observation: this.observation,
    establishment: this.establishment,
    purchaseDate: this.purchase_date,
    creationDate: this.creation_date,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

module.exports = Account;
