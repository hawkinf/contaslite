const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

/**
 * Modelo PaymentMethod - Métodos de pagamento
 *
 * Campos do Flutter (PaymentMethod):
 * - id, name, type, icon_code, requires_bank, is_active, usage, logo
 *
 * Usage enum:
 * - 0: pagamentos (somente pagamentos)
 * - 1: recebimentos (somente recebimentos)
 * - 2: pagamentosRecebimentos (ambos)
 */
const PaymentMethod = sequelize.define('PaymentMethod', {
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
    allowNull: false,
    comment: 'Nome do método de pagamento'
  },
  type: {
    type: DataTypes.STRING(50),
    allowNull: false,
    comment: 'Tipo do método (ex: credit_card, debit, pix, cash)'
  },
  icon_code: {
    type: DataTypes.INTEGER,
    allowNull: false,
    comment: 'Código do ícone Material Icons'
  },
  requires_bank: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
    comment: 'Se requer conta bancária associada'
  },
  is_active: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    comment: 'Se o método está ativo'
  },
  usage: {
    type: DataTypes.INTEGER,
    defaultValue: 2,
    validate: {
      isIn: [[0, 1, 2]]
    },
    comment: '0=pagamentos, 1=recebimentos, 2=ambos'
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
  tableName: 'payment_methods',
  timestamps: false,
  paranoid: true,
  deletedAt: 'deleted_at',
  indexes: [
    { fields: ['user_id'] },
    { fields: ['is_active'] },
    { fields: ['updated_at'] },
    {
      fields: ['user_id', 'name'],
      unique: true,
      where: { deleted_at: null }
    }
  ]
});

PaymentMethod.beforeUpdate((method) => {
  method.updated_at = new Date();
});

PaymentMethod.beforeCreate((method) => {
  method.created_at = new Date();
  method.updated_at = new Date();
});

/**
 * Converte dados do Flutter para o formato do banco
 */
PaymentMethod.fromFlutterData = function(data, userId) {
  return {
    user_id: userId,
    name: data.name,
    type: data.type,
    icon_code: data.icon_code || data.iconCode,
    requires_bank: data.requires_bank === 1 || data.requiresBank === 1 || data.requires_bank === true || data.requiresBank === true,
    is_active: data.is_active === 1 || data.isActive === 1 || data.is_active === true || data.isActive === true,
    usage: data.usage ?? 2,
    logo: data.logo
  };
};

/**
 * Converte dados do banco para o formato do Flutter
 */
PaymentMethod.prototype.toFlutterData = function() {
  return {
    id: this.id,
    name: this.name,
    type: this.type,
    icon_code: this.icon_code,
    requires_bank: this.requires_bank ? 1 : 0,
    is_active: this.is_active ? 1 : 0,
    usage: this.usage,
    logo: this.logo,
    updatedAt: this.updated_at ? this.updated_at.toISOString() : null,
    deletedAt: this.deleted_at ? this.deleted_at.toISOString() : null
  };
};

/**
 * Cria métodos de pagamento padrão para um novo usuário
 */
PaymentMethod.createDefaultsForUser = async function(userId) {
  const defaults = [
    { name: 'Cartão de Crédito', type: 'credit_card', icon_code: 0xe19f, requires_bank: false, usage: 0 },
    { name: 'Crédito em conta', type: 'credit', icon_code: 0xe1f5, requires_bank: true, usage: 1 },
    { name: 'Dinheiro', type: 'cash', icon_code: 0xe19e, requires_bank: false, usage: 2 },
    { name: 'Débito C/C', type: 'debit', icon_code: 0xe19f, requires_bank: true, usage: 0 },
    { name: 'Internet Banking', type: 'transfer', icon_code: 0xe157, requires_bank: true, usage: 2 },
    { name: 'PIX', type: 'pix', icon_code: 0xef6e, requires_bank: true, usage: 2 }
  ];

  const methods = [];
  for (const def of defaults) {
    const method = await PaymentMethod.create({
      user_id: userId,
      ...def
    });
    methods.push(method);
  }
  return methods;
};

module.exports = PaymentMethod;
