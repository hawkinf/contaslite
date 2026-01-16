#!/usr/bin/env node
/**
 * Script de migração - Executa migrações SQL no PostgreSQL
 *
 * Uso:
 *   node scripts/migrate.js          # Executa migração 005
 *   node scripts/migrate.js --all    # Executa todas as migrações
 *   node scripts/migrate.js --reset  # Dropa e recria tudo (CUIDADO!)
 */

const fs = require('fs');
const path = require('path');
require('dotenv').config();

const { sequelize } = require('../src/config/database');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'migrations');

async function runMigration(filename) {
  const filepath = path.join(MIGRATIONS_DIR, filename);
  const sql = fs.readFileSync(filepath, 'utf-8');

  console.log(`\n📦 Executando migração: ${filename}`);

  try {
    // Dividir por comandos (alguns comandos não podem ser combinados em uma transação)
    const statements = sql
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const statement of statements) {
      if (statement.trim()) {
        await sequelize.query(statement + ';');
      }
    }

    console.log(`✅ Migração ${filename} executada com sucesso`);
  } catch (error) {
    console.error(`❌ Erro na migração ${filename}:`, error.message);
    throw error;
  }
}

async function runAllMigrations() {
  const files = fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();

  console.log(`\n📚 Encontradas ${files.length} migrações:`);
  files.forEach(f => console.log(`   - ${f}`));

  for (const file of files) {
    await runMigration(file);
  }
}

async function runLatestMigration() {
  // Executa a migração 005 que tem o schema compatível com Flutter
  await runMigration('005_flutter_compatible_schema.sql');
}

async function main() {
  const args = process.argv.slice(2);

  console.log('🔄 Contaslite - Sistema de Migrações');
  console.log('====================================');

  try {
    // Testar conexão
    console.log('\n📡 Conectando ao banco de dados...');
    await sequelize.authenticate();
    console.log('✅ Conexão estabelecida');

    if (args.includes('--all')) {
      await runAllMigrations();
    } else if (args.includes('--reset')) {
      console.log('\n⚠️  ATENÇÃO: --reset vai dropar TODAS as tabelas e recriar!');
      console.log('   Pressione Ctrl+C para cancelar ou aguarde 5 segundos...\n');
      await new Promise(r => setTimeout(r, 5000));
      await runMigration('005_flutter_compatible_schema.sql');
    } else {
      await runLatestMigration();
    }

    console.log('\n🎉 Migrações concluídas com sucesso!');
    process.exit(0);

  } catch (error) {
    console.error('\n❌ Erro fatal:', error.message);
    process.exit(1);
  }
}

main();
