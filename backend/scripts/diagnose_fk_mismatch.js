/**
 * Script de diagnóstico para verificar inconsistência de FKs no sync
 *
 * Problema: account_types retorna id=98..114, mas account_descriptions
 * e accounts referenciam accountId/typeId=7..12
 *
 * Execução: node scripts/diagnose_fk_mismatch.js
 */

require('dotenv').config();
const { sequelize } = require('../src/config/database');

async function diagnose() {
  console.log('='.repeat(60));
  console.log('DIAGNÓSTICO DE INCONSISTÊNCIA DE FKs');
  console.log('='.repeat(60));

  try {
    // 1. Listar todos os usuários
    const [users] = await sequelize.query(`
      SELECT id, email, name FROM users ORDER BY id
    `);
    console.log('\n📋 USUÁRIOS:');
    users.forEach(u => console.log(`  - id=${u.id}: ${u.email} (${u.name})`));

    // 2. Para cada usuário, mostrar seus account_types
    console.log('\n📊 ACCOUNT_TYPES POR USUÁRIO:');
    for (const user of users) {
      const [types] = await sequelize.query(`
        SELECT id, name, user_id FROM account_types
        WHERE user_id = ${user.id} AND deleted_at IS NULL
        ORDER BY id
      `);
      console.log(`\n  👤 Usuário ${user.id} (${user.email}):`);
      types.forEach(t => console.log(`    - id=${t.id}: "${t.name}"`));
      console.log(`    Total: ${types.length} tipos`);
    }

    // 3. Verificar account_descriptions com FKs inválidos
    console.log('\n🔍 VERIFICANDO FKs DE ACCOUNT_DESCRIPTIONS:');
    const [invalidDescFKs] = await sequelize.query(`
      SELECT
        ad.id AS desc_id,
        ad.description,
        ad.account_id AS accountId,
        ad.user_id AS desc_user_id,
        at.id AS type_id,
        at.name AS type_name,
        at.user_id AS type_user_id
      FROM account_descriptions ad
      LEFT JOIN account_types at ON ad.account_id = at.id
      WHERE ad.deleted_at IS NULL
      ORDER BY ad.user_id, ad.id
    `);

    let invalidCount = 0;
    let crossUserCount = 0;
    for (const row of invalidDescFKs) {
      if (!row.type_id) {
        console.log(`  ❌ account_descriptions.id=${row.desc_id} → accountId=${row.accountId} NÃO EXISTE em account_types`);
        invalidCount++;
      } else if (row.desc_user_id !== row.type_user_id) {
        console.log(`  ⚠️ account_descriptions.id=${row.desc_id} (user=${row.desc_user_id}) → accountId=${row.accountId} pertence a user=${row.type_user_id}`);
        crossUserCount++;
      }
    }
    if (invalidCount === 0 && crossUserCount === 0) {
      console.log('  ✅ Todas as FKs de account_descriptions estão válidas');
    } else {
      console.log(`\n  📌 Resumo: ${invalidCount} FKs inválidos, ${crossUserCount} cross-user`);
    }

    // 4. Verificar accounts com FKs inválidos
    console.log('\n🔍 VERIFICANDO FKs DE ACCOUNTS (typeId):');
    const [invalidAccountFKs] = await sequelize.query(`
      SELECT
        a.id AS account_id,
        a.description,
        a.type_id AS typeId,
        a.user_id AS account_user_id,
        at.id AS type_exists_id,
        at.name AS type_name,
        at.user_id AS type_user_id
      FROM accounts a
      LEFT JOIN account_types at ON a.type_id = at.id
      WHERE a.deleted_at IS NULL
      ORDER BY a.user_id, a.id
      LIMIT 100
    `);

    invalidCount = 0;
    crossUserCount = 0;
    for (const row of invalidAccountFKs) {
      if (!row.type_exists_id) {
        console.log(`  ❌ accounts.id=${row.account_id} "${row.description}" → typeId=${row.typeId} NÃO EXISTE em account_types`);
        invalidCount++;
      } else if (row.account_user_id !== row.type_user_id) {
        console.log(`  ⚠️ accounts.id=${row.account_id} (user=${row.account_user_id}) → typeId=${row.typeId} pertence a user=${row.type_user_id}`);
        crossUserCount++;
      }
    }
    if (invalidCount === 0 && crossUserCount === 0) {
      console.log('  ✅ Todas as FKs de accounts estão válidas');
    } else {
      console.log(`\n  📌 Resumo: ${invalidCount} FKs inválidos, ${crossUserCount} cross-user`);
    }

    // 5. Mostrar range de IDs por tabela
    console.log('\n📈 RANGE DE IDs POR TABELA:');
    const tables = ['account_types', 'account_descriptions', 'accounts'];
    for (const table of tables) {
      const [[range]] = await sequelize.query(`
        SELECT MIN(id) as min_id, MAX(id) as max_id, COUNT(*) as total
        FROM ${table} WHERE deleted_at IS NULL
      `);
      console.log(`  ${table}: id=${range.min_id}..${range.max_id} (${range.total} registros)`);
    }

    // 6. Mostrar FKs referenciadas que não existem
    console.log('\n🎯 FKs REFERENCIADAS MAS INEXISTENTES:');
    const [missingTypes] = await sequelize.query(`
      SELECT DISTINCT ad.account_id AS missing_type_id, 'account_descriptions' as source
      FROM account_descriptions ad
      LEFT JOIN account_types at ON ad.account_id = at.id
      WHERE at.id IS NULL AND ad.deleted_at IS NULL
      UNION
      SELECT DISTINCT a.type_id AS missing_type_id, 'accounts' as source
      FROM accounts a
      LEFT JOIN account_types at ON a.type_id = at.id
      WHERE at.id IS NULL AND a.deleted_at IS NULL
      ORDER BY missing_type_id
    `);
    if (missingTypes.length > 0) {
      console.log('  IDs de account_types que são referenciados mas não existem:');
      missingTypes.forEach(m => console.log(`  - id=${m.missing_type_id} (referenciado por ${m.source})`));
    } else {
      console.log('  ✅ Nenhuma FK órfã encontrada');
    }

    console.log('\n' + '='.repeat(60));
    console.log('DIAGNÓSTICO CONCLUÍDO');
    console.log('='.repeat(60));

  } catch (error) {
    console.error('Erro no diagnóstico:', error);
  } finally {
    await sequelize.close();
  }
}

diagnose();
