import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/db_helper.dart';

/// Serviço para verificar e reparar esquema do banco de dados
class DatabaseRepairService {
  static Future<void> checkAndRepairSchema() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Verificar versão do banco
      final version = await db.getVersion();
      debugPrint('🔍 Versão do banco de dados: v$version');
      
      // Verificar se as tabelas têm a coluna logo
      final hasTables = await _checkAndAddLogoColumns(db);
      
      if (hasTables) {
        debugPrint('✅ Esquema do banco de dados verificado e corrigido');
      } else {
        debugPrint('⚠️ Falha ao verificar/corrigir esquema');
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar/reparar esquema: $e');
      rethrow;
    }
  }

  static Future<bool> _checkAndAddLogoColumns(Database db) async {
    final tables = ['account_types', 'accounts', 'account_descriptions'];
    bool allSuccess = true;

    for (final table in tables) {
      try {
        // Verificar se a coluna logo existe
        final result = await db.rawQuery('PRAGMA table_info($table)');
        final hasLogo = result.any((col) => col['name'] == 'logo');

        if (!hasLogo) {
          debugPrint('⚙️ Adicionando coluna logo em $table...');
          await db.execute('ALTER TABLE $table ADD COLUMN logo TEXT');
          debugPrint('✅ Coluna logo adicionada em $table');
        } else {
          debugPrint('✓ Coluna logo já existe em $table');
        }
      } catch (e) {
        debugPrint('❌ Erro ao verificar/adicionar coluna logo em $table: $e');
        allSuccess = false;
      }
    }

    return allSuccess;
  }

  /// Força a atualização do número de versão do banco
  static Future<void> updateDatabaseVersion(int newVersion) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.setVersion(newVersion);
      debugPrint('✅ Versão do banco atualizada para v$newVersion');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar versão: $e');
      rethrow;
    }
  }
}
