#!/bin/bash
# Script de backup automático do PostgreSQL
# Uso: ./backup.sh
# Agendar com cron: 0 2 * * * /var/www/contaslite-backend/backend/scripts/backup.sh

# Configurações
DB_NAME="contaslite"
DB_USER="contaslite_user"
BACKUP_DIR="/var/backups/contaslite"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/contaslite_$DATE.sql"
RETENTION_DAYS=7  # Manter backups dos últimos 7 dias

# Criar diretório de backup se não existir
mkdir -p $BACKUP_DIR

# Fazer backup
echo "🔄 Iniciando backup do banco de dados..."
pg_dump -U $DB_USER -h localhost $DB_NAME > $BACKUP_FILE

# Comprimir backup
gzip $BACKUP_FILE
echo "✅ Backup criado: ${BACKUP_FILE}.gz"

# Remover backups antigos
echo "🗑️  Removendo backups com mais de $RETENTION_DAYS dias..."
find $BACKUP_DIR -name "contaslite_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Listar backups disponíveis
echo "📋 Backups disponíveis:"
ls -lh $BACKUP_DIR

echo "✅ Backup concluído!"
