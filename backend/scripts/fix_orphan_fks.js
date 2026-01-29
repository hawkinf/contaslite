/**
 * Script para corrigir FKs órfãs no banco de dados
 *
 * Problema: account_descriptions e accounts têm FKs apontando para
 * account_types que não existem (IDs locais do Flutter foram enviados
 * em vez dos server_ids corretos)
 *
 * Execução: node scripts/fix_orphan_fks.js
 *
 * ATENÇÃO: Faça backup antes de executar!
 */

require('dotenv').config();
const { sequelize } = require('../src/config/database');
const readline = require('readline');

async function promptConfirm(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question(`${message} (s/n): `, (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === 's' || answer.toLowerCase() === 'y');
    });
  });
}

async function fixOrphanFKs() {
  console.log('='.repeat(60));
  console.log('CORREÇÃO DE FKs ÓRFÃS');
  console.log('='.repeat(60));

  try {
    // 1. Identificar registros órfãos em account_descriptions
    console.log('\n🔍 Buscando account_descriptions com FKs órfãs...');
    const [orphanDescs] = await sequelize.query(`
      SELECT
        ad.id,
        ad.description,
        ad.account_id AS orphan_account_id,
        ad.user_id
      FROM account_descriptions ad
      LEFT JOIN account_types at ON ad.account_id = at.id
      WHERE at.id IS NULL AND ad.deleted_at IS NULL
    `);
    console.log(`  Encontrados: ${orphanDescs.length} registros órfãos`);

    // 2. Identificar registros órfãos em accounts
    console.log('\n🔍 Buscando accounts com FKs órfãs...');
    const [orphanAccounts] = await sequelize.query(`
      SELECT
        a.id,
        a.description,
        a.type_id AS orphan_type_id,
        a.user_id
      FROM accounts a
      LEFT JOIN account_types at ON a.type_id = at.id
      WHERE at.id IS NULL AND a.deleted_at IS NULL
    `);
    console.log(`  Encontrados: ${orphanAccounts.length} registros órfãos`);

    if (orphanDescs.length === 0 && orphanAccounts.length === 0) {
      console.log('\n✅ Nenhuma FK órfã encontrada. Banco de dados consistente!');
      return;
    }

    // 3. Mostrar detalhes
    if (orphanDescs.length > 0) {
      console.log('\n📋 Account descriptions órfãs:');
      orphanDescs.slice(0, 10).forEach(d => {
        console.log(`  - id=${d.id}: "${d.description}" (user=${d.user_id}, account_id órfão=${d.orphan_account_id})`);
      });
      if (orphanDescs.length > 10) console.log(`  ... e mais ${orphanDescs.length - 10} registros`);
    }

    if (orphanAccounts.length > 0) {
      console.log('\n📋 Accounts órfãs:');
      orphanAccounts.slice(0, 10).forEach(a => {
        console.log(`  - id=${a.id}: "${a.description}" (user=${a.user_id}, type_id órfão=${a.orphan_type_id})`);
      });
      if (orphanAccounts.length > 10) console.log(`  ... e mais ${orphanAccounts.length - 10} registros`);
    }

    // 4. Opções de correção
    console.log('\n📌 OPÇÕES DE CORREÇÃO:');
    console.log('  1) Soft delete (marcar como deletados)');
    console.log('  2) Reassociar ao primeiro account_type do usuário');
    console.log('  3) Cancelar');

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    const option = await new Promise((resolve) => {
      rl.question('\nEscolha uma opção (1/2/3): ', resolve);
    });
    rl.close();

    if (option === '3') {
      console.log('\n❌ Operação cancelada.');
      return;
    }

    if (option === '1') {
      // Soft delete
      console.log('\n🗑️ Marcando registros órfãos como deletados...');

      if (orphanDescs.length > 0) {
        const descIds = orphanDescs.map(d => d.id).join(',');
        await sequelize.query(`
          UPDATE account_descriptions
          SET deleted_at = NOW(), updated_at = NOW()
          WHERE id IN (${descIds})
        `);
        console.log(`  ✅ ${orphanDescs.length} account_descriptions marcadas como deletadas`);
      }

      if (orphanAccounts.length > 0) {
        const accountIds = orphanAccounts.map(a => a.id).join(',');
        await sequelize.query(`
          UPDATE accounts
          SET deleted_at = NOW(), updated_at = NOW()
          WHERE id IN (${accountIds})
        `);
        console.log(`  ✅ ${orphanAccounts.length} accounts marcadas como deletadas`);
      }

    } else if (option === '2') {
      // Reassociar
      console.log('\n🔗 Reassociando registros órfãos...');

      // Agrupar por usuário
      const userIds = new Set([
        ...orphanDescs.map(d => d.user_id),
        ...orphanAccounts.map(a => a.user_id)
      ]);

      for (const userId of userIds) {
        // Buscar primeiro account_type do usuário
        const [[firstType]] = await sequelize.query(`
          SELECT id, name FROM account_types
          WHERE user_id = ${userId} AND deleted_at IS NULL
          ORDER BY id LIMIT 1
        `);

        if (!firstType) {
          console.log(`  ⚠️ Usuário ${userId} não tem account_types válidos, pulando...`);
          continue;
        }

        console.log(`  👤 Usuário ${userId}: reassociando ao type id=${firstType.id} "${firstType.name}"`);

        // Atualizar account_descriptions
        const userOrphanDescs = orphanDescs.filter(d => d.user_id === userId);
        if (userOrphanDescs.length > 0) {
          const descIds = userOrphanDescs.map(d => d.id).join(',');
          await sequelize.query(`
            UPDATE account_descriptions
            SET account_id = ${firstType.id}, updated_at = NOW()
            WHERE id IN (${descIds})
          `);
          console.log(`    ✅ ${userOrphanDescs.length} account_descriptions reassociadas`);
        }

        // Atualizar accounts
        const userOrphanAccounts = orphanAccounts.filter(a => a.user_id === userId);
        if (userOrphanAccounts.length > 0) {
          const accountIds = userOrphanAccounts.map(a => a.id).join(',');
          await sequelize.query(`
            UPDATE accounts
            SET type_id = ${firstType.id}, updated_at = NOW()
            WHERE id IN (${accountIds})
          `);
          console.log(`    ✅ ${userOrphanAccounts.length} accounts reassociadas`);
        }
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('CORREÇÃO CONCLUÍDA');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n❌ Erro na correção:', error);
  } finally {
    await sequelize.close();
  }
}

fixOrphanFKs();
