/**
 * Índice de modelos - Exporta todos os modelos e configura associações
 */
const { sequelize } = require('../config/database');

// Importar modelos
const User = require('./User');
const RefreshToken = require('./RefreshToken');
const Account = require('./Account');
const AccountType = require('./AccountType');
const AccountDescription = require('./AccountDescription');
const Bank = require('./Bank');
const PaymentMethod = require('./PaymentMethod');
const Payment = require('./Payment');
const EmailSchedule = require('./EmailSchedule');

// Configurar associações

// User -> RefreshToken (1:N)
User.hasMany(RefreshToken, {
  foreignKey: 'user_id',
  as: 'refreshTokens'
});
RefreshToken.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// User -> Account (1:N)
User.hasMany(Account, {
  foreignKey: 'user_id',
  as: 'accounts'
});
Account.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// User -> AccountType (1:N)
User.hasMany(AccountType, {
  foreignKey: 'user_id',
  as: 'accountTypes'
});
AccountType.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// User -> AccountDescription (1:N)
User.hasMany(AccountDescription, {
  foreignKey: 'user_id',
  as: 'accountDescriptions'
});
AccountDescription.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// AccountType -> AccountDescription (1:N)
AccountType.hasMany(AccountDescription, {
  foreignKey: 'account_id',
  as: 'descriptions'
});
AccountDescription.belongsTo(AccountType, {
  foreignKey: 'account_id',
  as: 'accountType'
});

// AccountType -> Account (1:N)
AccountType.hasMany(Account, {
  foreignKey: 'type_id',
  as: 'accounts'
});
Account.belongsTo(AccountType, {
  foreignKey: 'type_id',
  as: 'accountType'
});

// AccountDescription -> Account (1:N)
AccountDescription.hasMany(Account, {
  foreignKey: 'category_id',
  as: 'accounts'
});
Account.belongsTo(AccountDescription, {
  foreignKey: 'category_id',
  as: 'category'
});

// User -> Bank (1:N)
User.hasMany(Bank, {
  foreignKey: 'user_id',
  as: 'banks'
});
Bank.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// User -> PaymentMethod (1:N)
User.hasMany(PaymentMethod, {
  foreignKey: 'user_id',
  as: 'paymentMethods'
});
PaymentMethod.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// User -> Payment (1:N)
User.hasMany(Payment, {
  foreignKey: 'user_id',
  as: 'payments'
});
Payment.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

// Account -> Payment (1:N)
Account.hasMany(Payment, {
  foreignKey: 'account_id',
  as: 'payments'
});
Payment.belongsTo(Account, {
  foreignKey: 'account_id',
  as: 'account'
});

// PaymentMethod -> Payment (1:N)
PaymentMethod.hasMany(Payment, {
  foreignKey: 'payment_method_id',
  as: 'payments'
});
Payment.belongsTo(PaymentMethod, {
  foreignKey: 'payment_method_id',
  as: 'paymentMethod'
});

// Bank -> Payment (1:N)
Bank.hasMany(Payment, {
  foreignKey: 'bank_account_id',
  as: 'payments'
});
Payment.belongsTo(Bank, {
  foreignKey: 'bank_account_id',
  as: 'bankAccount'
});

// Account (cartão) -> Account (despesas do cartão)
Account.hasMany(Account, {
  foreignKey: 'card_id',
  as: 'cardExpenses'
});
Account.belongsTo(Account, {
  foreignKey: 'card_id',
  as: 'creditCard'
});

// Account -> Account (recorrência pai/filho)
Account.hasMany(Account, {
  foreignKey: 'recurrence_id',
  as: 'recurrences'
});
Account.belongsTo(Account, {
  foreignKey: 'recurrence_id',
  as: 'recurrenceParent'
});

// User -> EmailSchedule (1:1)
User.hasOne(EmailSchedule, {
  foreignKey: 'user_id',
  as: 'emailSchedule'
});
EmailSchedule.belongsTo(User, {
  foreignKey: 'user_id',
  as: 'user'
});

/**
 * Mapeamento de nomes de tabelas para modelos
 * Usado pelo syncController para processar diferentes tabelas
 */
const modelsByTableName = {
  accounts: Account,
  account_types: AccountType,
  account_descriptions: AccountDescription,
  banks: Bank,
  payment_methods: PaymentMethod,
  payments: Payment
};

/**
 * Ordem de sincronização (respeitando dependências de FK)
 * Push: tabelas sem FK primeiro
 * Pull: pode ser em qualquer ordem
 */
const syncOrderPush = [
  'account_types',
  'account_descriptions',
  'banks',
  'payment_methods',
  'accounts',
  'payments'
];

const syncOrderPull = [
  'payment_methods',
  'account_types',
  'account_descriptions',
  'banks',
  'accounts',
  'payments'
];

module.exports = {
  sequelize,
  User,
  RefreshToken,
  Account,
  AccountType,
  AccountDescription,
  Bank,
  PaymentMethod,
  Payment,
  EmailSchedule,
  modelsByTableName,
  syncOrderPush,
  syncOrderPull
};
