/**
 * Script de Backfill para corrigir FKs quebradas
 *
 * Problema: account_descriptions.accountId e accounts.typeId contêm IDs locais
 * do Flutter (7..12) em vez dos server_ids corretos (98..114).
 *
 * Este script tenta mapear os IDs quebrados para os corretos baseado em:
 * 1. Mapeamento por nome do tipo (se conhecemos a correspondência)
 * 2. Mapeamento por ordem (se os tipos foram criados na mesma ordem)
 * 3. Mapeamento manual (fornecido pelo usuário)
 *
 * Execução: node scripts/backfill_fk_mapping.js
 */

require('dotenv').config();
const { sequelize } = require('../src/config/database');
const readline = require('readline');

async function prompt(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

async function backfillFKMapping() {
  console.log('='.repeat(60));
  console.log('BACKFILL DE FKs - MAPEAMENTO LOCAL → SERVIDOR');
  console.log('='.repeat(60));

  try {
    // 1. Listar usuários com problemas
    const [usersWithIssues] = await sequelize.query(`
      SELECT DISTINCT u.id, u.email
      FROM users u
      WHERE EXISTS (
        SELECT 1 FROM account_descriptions ad
        LEFT JOIN account_types at ON ad.account_id = at.id
        WHERE ad.user_id = u.id AND at.id IS NULL AND ad.deleted_at IS NULL
      )
      OR EXISTS (
        SELECT 1 FROM accounts a
        LEFT JOIN account_types at ON a.type_id = at.id
        WHERE a.user_id = u.id AND at.id IS NULL AND a.deleted_at IS NULL
      )
    `);

    if (usersWithIssues.length === 0) {
      console.log('\n✅ Nenhum usuário com FKs quebradas encontrado!');
      return;
    }

    console.log(`\n📋 Usuários com FKs quebradas: ${usersWithIssues.length}`);
    usersWithIssues.forEach(u => console.log(`  - id=${u.id}: ${u.email}`));

    // 2. Para cada usuário, tentar construir o mapeamento
    for (const user of usersWithIssues) {
      console.log(`\n${'='.repeat(60)}`);
      console.log(`👤 Processando usuário ${user.id}: ${user.email}`);
      console.log('='.repeat(60));

      // Buscar account_types do usuário (os IDs corretos)
      const [userTypes] = await sequelize.query(`
        SELECT id, name FROM account_types
        WHERE user_id = ${user.id} AND deleted_at IS NULL
        ORDER BY id
      `);

      console.log(`\n📊 Account types do usuário (IDs CORRETOS no servidor):`);
      userTypes.forEach(t => console.log(`  - id=${t.id}: "${t.name}"`));

      // Buscar IDs órfãos referenciados
      const [orphanIds] = await sequelize.query(`
        SELECT DISTINCT account_id AS orphan_id, 'account_descriptions' AS source
        FROM account_descriptions
        WHERE user_id = ${user.id}
          AND deleted_at IS NULL
          AND account_id NOT IN (SELECT id FROM account_types WHERE user_id = ${user.id})
        UNION
        SELECT DISTINCT type_id AS orphan_id, 'accounts' AS source
        FROM accounts
        WHERE user_id = ${user.id}
          AND deleted_at IS NULL
          AND type_id NOT IN (SELECT id FROM account_types WHERE user_id = ${user.id})
        ORDER BY orphan_id
      `);

      if (orphanIds.length === 0) {
        console.log('  ✅ Nenhuma FK órfã para este usuário');
        continue;
      }

      console.log(`\n🔴 IDs ÓRFÃOS referenciados (IDs locais do Flutter):`);
      orphanIds.forEach(o => console.log(`  - id=${o.orphan_id} (usado em ${o.source})`));

      // 3. Tentar mapeamento automático por ordem
      console.log('\n🔄 Tentando mapeamento automático por ordem...');
      const orphanIdsSorted = [...new Set(orphanIds.map(o => o.orphan_id))].sort((a, b) => a - b);
      const serverIdsSorted = userTypes.map(t => t.id).sort((a, b) => a - b);

      // Verificar se a quantidade bate
      if (orphanIdsSorted.length <= serverIdsSorted.length) {
        console.log('\n📌 PROPOSTA DE MAPEAMENTO (por ordem):');
        const mapping = {};
        orphanIdsSorted.forEach((orphanId, idx) => {
          if (idx < serverIdsSorted.length) {
            mapping[orphanId] = serverIdsSorted[idx];
            const typeName = userTypes.find(t => t.id === serverIdsSorted[idx])?.name || '?';
            console.log(`  ${orphanId} → ${serverIdsSorted[idx]} (${typeName})`);
          }
        });

        const confirm = await prompt('\nAplicar este mapeamento? (s/n): ');
        if (confirm.toLowerCase() === 's' || confirm.toLowerCase() === 'y') {
          // Aplicar mapeamento
          for (const [oldId, newId] of Object.entries(mapping)) {
            // Atualizar account_descriptions
            const [descResult] = await sequelize.query(`
              UPDATE account_descriptions
              SET account_id = ${newId}, updated_at = NOW()
              WHERE user_id = ${user.id} AND account_id = ${oldId}
            `);

            // Atualizar accounts
            const [accResult] = await sequelize.query(`
              UPDATE accounts
              SET type_id = ${newId}, updated_at = NOW()
              WHERE user_id = ${user.id} AND type_id = ${oldId}
            `);

            console.log(`  ✅ Mapeado ${oldId} → ${newId}`);
          }
          console.log('  ✅ Mapeamento aplicado com sucesso!');
        } else {
          console.log('  ⏭️ Pulando usuário...');
        }
      } else {
        console.log(`  ⚠️ Não foi possível mapear automaticamente:`);
        console.log(`     ${orphanIdsSorted.length} IDs órfãos vs ${serverIdsSorted.length} tipos disponíveis`);
        console.log('  ℹ️ Requer mapeamento manual.');

        // Permitir mapeamento manual
        const doManual = await prompt('\nDeseja fazer mapeamento manual? (s/n): ');
        if (doManual.toLowerCase() === 's' || doManual.toLowerCase() === 'y') {
          console.log('\nPara cada ID órfão, digite o ID correto do servidor:');
          for (const orphanId of orphanIdsSorted) {
            const newId = await prompt(`  ${orphanId} → `);
            if (newId && !isNaN(parseInt(newId))) {
              await sequelize.query(`
                UPDATE account_descriptions
                SET account_id = ${parseInt(newId)}, updated_at = NOW()
                WHERE user_id = ${user.id} AND account_id = ${orphanId}
              `);
              await sequelize.query(`
                UPDATE accounts
                SET type_id = ${parseInt(newId)}, updated_at = NOW()
                WHERE user_id = ${user.id} AND type_id = ${orphanId}
              `);
              console.log(`    ✅ ${orphanId} → ${newId}`);
            } else {
              console.log(`    ⏭️ Pulando ${orphanId}`);
            }
          }
        }
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('BACKFILL CONCLUÍDO');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('\n❌ Erro no backfill:', error);
  } finally {
    await sequelize.close();
  }
}

backfillFKMapping();
