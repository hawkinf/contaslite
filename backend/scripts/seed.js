#!/usr/bin/env node
/**
 * Script de seed - Cria dados de teste no banco de dados
 *
 * Uso:
 *   node scripts/seed.js             # Cria usuário e dados de teste
 *   node scripts/seed.js --clean     # Limpa dados e recria
 */

require('dotenv').config();

const { sequelize, User, AccountType, AccountDescription, Bank, PaymentMethod, Account, Payment } = require('../src/models');

// Dados de teste
const TEST_USER = {
  email: 'teste@contaslite.com',
  password_hash: 'Teste123!', // Será hasheado pelo hook
  name: 'Usuário Teste'
};

const DEFAULT_ACCOUNT_TYPES = [
  { name: 'Cartões de Crédito', logo: '💳' },
  { name: 'Consumo', logo: '🛒' },
  { name: 'Saúde', logo: '🏥' },
  { name: 'Educação', logo: '📚' },
  { name: 'Moradia', logo: '🏠' },
  { name: 'Transporte', logo: '🚗' }
];

const DEFAULT_PAYMENT_METHODS = [
  { name: 'Cartão de Crédito', type: 'credit_card', icon_code: 0xe19f, requires_bank: false, usage: 0 },
  { name: 'Crédito em conta', type: 'credit', icon_code: 0xe1f5, requires_bank: true, usage: 1 },
  { name: 'Dinheiro', type: 'cash', icon_code: 0xe19e, requires_bank: false, usage: 2 },
  { name: 'Débito C/C', type: 'debit', icon_code: 0xe19f, requires_bank: true, usage: 0 },
  { name: 'Internet Banking', type: 'transfer', icon_code: 0xe157, requires_bank: true, usage: 2 },
  { name: 'PIX', type: 'pix', icon_code: 0xef6e, requires_bank: true, usage: 2 }
];

const SAMPLE_ACCOUNTS = [
  {
    description: 'Netflix',
    value: 55.90,
    due_day: 15,
    month: 1,
    year: 2026,
    is_recurrent: true,
    pay_in_advance: false,
    typeIndex: 1, // Consumo
    logo: '📺'
  },
  {
    description: 'Spotify',
    value: 21.90,
    due_day: 10,
    month: 1,
    year: 2026,
    is_recurrent: true,
    pay_in_advance: false,
    typeIndex: 1, // Consumo
    logo: '🎵'
  },
  {
    description: 'Aluguel',
    value: 1500.00,
    due_day: 5,
    month: 1,
    year: 2026,
    is_recurrent: true,
    pay_in_advance: false,
    typeIndex: 4, // Moradia
    logo: '🏠'
  },
  {
    description: 'Conta de Luz',
    value: 180.00,
    estimated_value: 200.00,
    due_day: 20,
    month: 1,
    year: 2026,
    is_recurrent: true,
    pay_in_advance: false,
    typeIndex: 4, // Moradia
    logo: '💡'
  },
  {
    description: 'Nubank',
    card_brand: 'Mastercard',
    card_bank: 'Nubank',
    card_limit: 5000.00,
    card_color: 0xFF8A2BE2,
    value: 0,
    due_day: 27,
    best_buy_day: 20,
    month: null,
    year: null,
    is_recurrent: false,
    pay_in_advance: false,
    typeIndex: 0, // Cartões de Crédito
    logo: '💳'
  }
];

async function cleanDatabase(userId) {
  console.log('🧹 Limpando dados existentes...');

  await Payment.destroy({ where: { user_id: userId }, force: true });
  await Account.destroy({ where: { user_id: userId }, force: true });
  await AccountDescription.destroy({ where: { user_id: userId }, force: true });
  await Bank.destroy({ where: { user_id: userId }, force: true });
  await PaymentMethod.destroy({ where: { user_id: userId }, force: true });
  await AccountType.destroy({ where: { user_id: userId }, force: true });

  console.log('✅ Dados limpos');
}

async function seedUser() {
  let user = await User.findOne({ where: { email: TEST_USER.email } });

  if (!user) {
    console.log('👤 Criando usuário de teste...');
    user = await User.create(TEST_USER);
    console.log(`✅ Usuário criado: ${user.email} (ID: ${user.id})`);
  } else {
    console.log(`👤 Usuário existente: ${user.email} (ID: ${user.id})`);
  }

  return user;
}

async function seedAccountTypes(userId) {
  console.log('📁 Criando tipos de conta...');
  const types = [];

  for (const type of DEFAULT_ACCOUNT_TYPES) {
    const created = await AccountType.create({
      user_id: userId,
      ...type
    });
    types.push(created);
    console.log(`   ✓ ${type.name}`);
  }

  return types;
}

async function seedPaymentMethods(userId) {
  console.log('💳 Criando métodos de pagamento...');
  const methods = [];

  for (const method of DEFAULT_PAYMENT_METHODS) {
    const created = await PaymentMethod.create({
      user_id: userId,
      ...method
    });
    methods.push(created);
    console.log(`   ✓ ${method.name}`);
  }

  return methods;
}

async function seedBanks(userId) {
  console.log('🏦 Criando contas bancárias...');

  const banks = [
    { code: 260, name: 'Nubank', description: 'Conta Principal', agency: '0001', account: '12345678-9', color: 0xFF8A2BE2 },
    { code: 341, name: 'Itaú', description: 'Conta Salário', agency: '1234', account: '56789-0', color: 0xFFFF6600 }
  ];

  const created = [];
  for (const bank of banks) {
    const b = await Bank.create({ user_id: userId, ...bank });
    created.push(b);
    console.log(`   ✓ ${bank.name}`);
  }

  return created;
}

async function seedAccounts(userId, types) {
  console.log('📝 Criando contas de exemplo...');
  const accounts = [];

  for (const acc of SAMPLE_ACCOUNTS) {
    const typeId = types[acc.typeIndex].id;
    const { typeIndex, ...data } = acc;

    const created = await Account.create({
      user_id: userId,
      type_id: typeId,
      ...data
    });
    accounts.push(created);
    console.log(`   ✓ ${acc.description}`);
  }

  return accounts;
}

async function main() {
  const args = process.argv.slice(2);
  const shouldClean = args.includes('--clean');

  console.log('\n🌱 Contaslite - Script de Seed');
  console.log('==============================\n');

  try {
    // Conectar ao banco
    console.log('📡 Conectando ao banco de dados...');
    await sequelize.authenticate();
    console.log('✅ Conexão estabelecida\n');

    // Criar ou obter usuário
    const user = await seedUser();

    // Limpar se solicitado
    if (shouldClean) {
      await cleanDatabase(user.id);
    }

    // Verificar se já tem dados
    const existingTypes = await AccountType.count({ where: { user_id: user.id } });
    if (existingTypes > 0 && !shouldClean) {
      console.log('\n⚠️  Usuário já possui dados. Use --clean para recriar.');
      process.exit(0);
    }

    // Criar dados
    const types = await seedAccountTypes(user.id);
    await seedPaymentMethods(user.id);
    await seedBanks(user.id);
    await seedAccounts(user.id, types);

    console.log('\n🎉 Seed concluído com sucesso!');
    console.log('\n📋 Resumo:');
    console.log(`   - Email: ${TEST_USER.email}`);
    console.log(`   - Senha: ${TEST_USER.password_hash}`);
    console.log(`   - ${DEFAULT_ACCOUNT_TYPES.length} tipos de conta`);
    console.log(`   - ${DEFAULT_PAYMENT_METHODS.length} métodos de pagamento`);
    console.log(`   - 2 contas bancárias`);
    console.log(`   - ${SAMPLE_ACCOUNTS.length} contas de exemplo`);

    process.exit(0);

  } catch (error) {
    console.error('\n❌ Erro:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main();
