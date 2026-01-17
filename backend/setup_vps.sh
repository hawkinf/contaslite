#!/bin/bash
# Script para configurar Google Auth na VPS
# Execute: bash setup_vps.sh

echo "======================================"
echo "  Configurando Google Auth na VPS    "
echo "======================================"
echo ""

# Verificar se .env existe
if [ ! -f .env ]; then
    echo "📋 Criando .env a partir de .env.example..."
    cp .env.example .env
fi

# Atualizar GOOGLE_CLIENT_ID no .env
echo "🔧 Configurando GOOGLE_CLIENT_ID..."
sed -i 's/GOOGLE_CLIENT_ID=.*/GOOGLE_CLIENT_ID=733489428773-rse8acmbhf2rgbjioteiss4jg5lhqf11.apps.googleusercontent.com/' .env

# Verificar se a linha foi adicionada
if ! grep -q "GOOGLE_CLIENT_ID" .env; then
    echo "GOOGLE_CLIENT_ID=733489428773-rse8acmbhf2rgbjioteiss4jg5lhqf11.apps.googleusercontent.com" >> .env
fi

echo "✅ GOOGLE_CLIENT_ID configurado"

# Instalar dependências
echo ""
echo "📦 Instalando dependências..."
npm install

# Executar migração
echo ""
echo "🔄 Executando migração do banco de dados..."
node -e "
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const { sequelize } = require('./src/config/database');

async function migrate() {
    try {
        await sequelize.authenticate();
        console.log('✅ Conexão com banco de dados OK');

        const migrationPath = path.join(__dirname, 'migrations', '006_add_google_auth_fields.sql');
        const sql = fs.readFileSync(migrationPath, 'utf-8');

        const statements = sql.split(';').filter(s => s.trim() && !s.trim().startsWith('--'));

        for (const statement of statements) {
            if (statement.trim()) {
                try {
                    await sequelize.query(statement + ';');
                } catch (err) {
                    if (!err.message.includes('already exists')) {
                        console.log('⚠️ ', err.message);
                    }
                }
            }
        }

        console.log('✅ Migração executada');
        await sequelize.close();
        process.exit(0);
    } catch (err) {
        console.error('❌ Erro:', err.message);
        process.exit(1);
    }
}

migrate();
"

echo ""
echo "======================================"
echo "  Configuração concluída!            "
echo "======================================"
echo ""
echo "Reinicie o servidor:"
echo "  pm2 restart contaslite-backend"
echo "  ou: systemctl restart contaslite"
echo ""
