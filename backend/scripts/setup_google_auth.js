#!/usr/bin/env node
/**
 * Script para configurar Google Auth no backend
 *
 * Uso:
 *   node scripts/setup_google_auth.js
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (prompt) => new Promise((resolve) => rl.question(prompt, resolve));

async function main() {
  console.log('');
  console.log('====================================');
  console.log('  Configuração do Google Sign-In   ');
  console.log('====================================');
  console.log('');

  const envPath = path.join(__dirname, '..', '.env');

  // Verificar se .env existe
  if (!fs.existsSync(envPath)) {
    const envExamplePath = path.join(__dirname, '..', '.env.example');
    if (fs.existsSync(envExamplePath)) {
      console.log('📋 Criando .env a partir de .env.example...');
      fs.copyFileSync(envExamplePath, envPath);
    } else {
      console.log('❌ Arquivo .env.example não encontrado!');
      process.exit(1);
    }
  }

  // Ler .env atual
  let envContent = fs.readFileSync(envPath, 'utf-8');

  // Perguntar Google Client ID
  console.log('');
  console.log('📝 Você precisa do Google Client ID do tipo "Web Application"');
  console.log('   Obtenha em: https://console.cloud.google.com/apis/credentials');
  console.log('');

  const clientId = await question('Digite o Google Client ID: ');

  if (!clientId || !clientId.includes('.apps.googleusercontent.com')) {
    console.log('');
    console.log('⚠️  Client ID inválido. Deve terminar com .apps.googleusercontent.com');
    console.log('');
    rl.close();
    process.exit(1);
  }

  // Atualizar ou adicionar GOOGLE_CLIENT_ID
  if (envContent.includes('GOOGLE_CLIENT_ID=')) {
    envContent = envContent.replace(
      /GOOGLE_CLIENT_ID=.*/,
      `GOOGLE_CLIENT_ID=${clientId}`
    );
  } else {
    envContent += `\n# Google OAuth (for Google Sign-In)\nGOOGLE_CLIENT_ID=${clientId}\n`;
  }

  // Salvar .env
  fs.writeFileSync(envPath, envContent);
  console.log('');
  console.log('✅ Arquivo .env atualizado com GOOGLE_CLIENT_ID');

  // Executar migração
  console.log('');
  console.log('🔄 Executando migração do banco de dados...');

  try {
    require('dotenv').config({ path: envPath });
    const { sequelize } = require('../src/config/database');

    await sequelize.authenticate();
    console.log('✅ Conexão com banco de dados OK');

    const migrationPath = path.join(__dirname, '..', 'migrations', '006_add_google_auth_fields.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');

    const statements = migrationSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const statement of statements) {
      if (statement.trim()) {
        try {
          await sequelize.query(statement + ';');
        } catch (err) {
          // Ignorar erros de "já existe" (colunas/índices)
          if (!err.message.includes('already exists') &&
              !err.message.includes('já existe')) {
            console.log(`⚠️  Aviso: ${err.message}`);
          }
        }
      }
    }

    console.log('✅ Migração executada com sucesso');
    await sequelize.close();

  } catch (err) {
    console.log(`⚠️  Erro na migração: ${err.message}`);
    console.log('   Execute manualmente: node scripts/migrate.js');
  }

  console.log('');
  console.log('====================================');
  console.log('  Configuração concluída!          ');
  console.log('====================================');
  console.log('');
  console.log('Próximos passos:');
  console.log('1. Reinicie o servidor: pm2 restart contaslite-backend');
  console.log('2. Configure o mesmo Client ID no Flutter');
  console.log('');

  rl.close();
}

main().catch(err => {
  console.error('Erro:', err);
  rl.close();
  process.exit(1);
});
