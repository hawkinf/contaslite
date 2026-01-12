#!/bin/bash
# Script para restaurar backup do PostgreSQL
# Uso: ./restore.sh contaslite_20260112_020000.sql.gz

if [ -z "$1" ]; then
    echo "❌ Erro: Especifique o arquivo de backup"
    echo "Uso: ./restore.sh <arquivo_backup.sql.gz>"
    echo ""
    echo "Backups disponíveis:"
    ls -1 /var/backups/contaslite/
    exit 1
fi

# Configurações
DB_NAME="contaslite"
DB_USER="contaslite_user"
BACKUP_FILE="$1"

# Verificar se arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    BACKUP_FILE="/var/backups/contaslite/$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "❌ Erro: Arquivo de backup não encontrado: $1"
        exit 1
    fi
fi

# Confirmar restauração
echo "⚠️  ATENÇÃO: Esta operação irá sobrescrever o banco de dados atual!"
echo "Banco: $DB_NAME"
echo "Backup: $BACKUP_FILE"
read -p "Deseja continuar? (sim/não): " confirm

if [ "$confirm" != "sim" ]; then
    echo "❌ Restauração cancelada"
    exit 0
fi

# Fazer backup do estado atual antes de restaurar
echo "🔄 Criando backup de segurança do estado atual..."
SAFETY_BACKUP="/var/backups/contaslite/pre-restore_$(date +%Y%m%d_%H%M%S).sql"
pg_dump -U $DB_USER -h localhost $DB_NAME > $SAFETY_BACKUP
gzip $SAFETY_BACKUP
echo "✅ Backup de segurança: ${SAFETY_BACKUP}.gz"

# Descomprimir backup se necessário
if [[ $BACKUP_FILE == *.gz ]]; then
    echo "🔄 Descomprimindo backup..."
    TEMP_FILE="${BACKUP_FILE%.gz}"
    gunzip -c $BACKUP_FILE > $TEMP_FILE
    RESTORE_FILE=$TEMP_FILE
else
    RESTORE_FILE=$BACKUP_FILE
fi

# Restaurar backup
echo "🔄 Restaurando backup..."
psql -U $DB_USER -h localhost $DB_NAME < $RESTORE_FILE

# Limpar arquivo temporário
if [ ! -z "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
    rm $TEMP_FILE
fi

echo "✅ Backup restaurado com sucesso!"
echo "📝 Se houver problemas, restaure o backup de segurança: ${SAFETY_BACKUP}.gz"
