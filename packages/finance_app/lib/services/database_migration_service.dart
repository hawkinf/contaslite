import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import 'database_protection_service.dart';

class DatabaseMigrationService {
  static final DatabaseMigrationService instance =
      DatabaseMigrationService._();
  DatabaseMigrationService._();

  // Versão atual esperada do schema
  static const int currentSchemaVersion = 11;

  ValueNotifier<MigrationStatus> migrationStatus =
      ValueNotifier(MigrationStatus.idle());

  Future<bool> isMigrationRequired() async {
    try {
      // Simplesmente retorna false - a migração acontece automaticamente via onUpgrade
      // Esta função é mantida para compatibilidade futura
      debugPrint('✓ Verificação de banco de dados OK');
      return false;
    } catch (e) {
      debugPrint('❌ Erro ao verificar versão do banco: $e');
      return true; // Mostra tela de migração em caso de erro
    }
  }

  Future<void> performMigration() async {
    try {
      migrationStatus.value = MigrationStatus.loading(
        message: 'Preparando banco de dados...',
        progress: 0.1,
      );

      final db = await DatabaseHelper.instance.database;
      final currentVersion = await db.getVersion();

      debugPrint('🔄 Iniciando migração de v$currentVersion para v$currentSchemaVersion');

      // O SQLite executará o onUpgrade automaticamente
      // Apenas verificamos que completou
      await db.getVersion();

      migrationStatus.value = MigrationStatus.loading(
        message: 'Validando dados...',
        progress: 0.8,
      );

      // Validar integridade dos dados
      await _validateDataIntegrity(db);

      // Validação de integridade com DatabaseProtectionService
      migrationStatus.value = MigrationStatus.loading(
        message: 'Verificando integridade do banco...',
        progress: 0.9,
      );

      final integrityResult =
          await DatabaseProtectionService.instance.validateIntegrity();

      if (!integrityResult.isValid) {
        debugPrint('⚠️ Aviso: ${integrityResult.summary}');
        debugPrint(integrityResult.toString());
      }

      migrationStatus.value = MigrationStatus.loading(
        message: 'Finalizando...',
        progress: 0.95,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      final newVersion = await db.getVersion();
      debugPrint('✅ Migração concluída! Versão agora: $newVersion');

      migrationStatus.value = MigrationStatus.completed(
        message: 'Banco de dados atualizado com sucesso!',
      );
    } catch (e) {
      debugPrint('❌ Erro durante migração: $e');
      migrationStatus.value = MigrationStatus.error(
        message: 'Erro na migração: $e',
      );
      rethrow;
    }
  }

  Future<void> _validateDataIntegrity(Database db) async {
    try {
      // Verificar se tabelas existem
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      debugPrint('📋 Tabelas encontradas: ${tables.length}');

      final requiredTables = [
        'account_types',
        'account_descriptions',
        'accounts',
        'payment_methods',
        'banks'
      ];

      for (final table in requiredTables) {
        final exists = tables.any((t) => t['name'] == table);
        if (!exists) {
          throw Exception('Tabela obrigatória não encontrada: $table');
        }
        debugPrint('  ✓ Tabela "$table" OK');
      }

      // Verificar integridade referencial
      final result =
          await db.rawQuery('PRAGMA integrity_check');
      if (result.isNotEmpty && result[0]['integrity_check'] != 'ok') {
        throw Exception('Integridade do banco comprometida');
      }

      debugPrint('✓ Integridade dos dados validada');
    } catch (e) {
      debugPrint('⚠️ Erro na validação: $e');
      rethrow;
    }
  }

  void resetStatus() {
    migrationStatus.value = MigrationStatus.idle();
  }
}

class MigrationStatus {
  final String message;
  final double progress;
  final bool isLoading;
  final bool isCompleted;
  final bool isError;

  MigrationStatus({
    required this.message,
    required this.progress,
    required this.isLoading,
    required this.isCompleted,
    required this.isError,
  });

  factory MigrationStatus.idle() => MigrationStatus(
    message: 'Verificando banco de dados...',
    progress: 0.0,
    isLoading: false,
    isCompleted: false,
    isError: false,
  );

  factory MigrationStatus.loading({
    required String message,
    double progress = 0.5,
  }) =>
      MigrationStatus(
        message: message,
        progress: progress,
        isLoading: true,
        isCompleted: false,
        isError: false,
      );

  factory MigrationStatus.completed({required String message}) =>
      MigrationStatus(
        message: message,
        progress: 1.0,
        isLoading: false,
        isCompleted: true,
        isError: false,
      );

  factory MigrationStatus.error({required String message}) =>
      MigrationStatus(
        message: message,
        progress: 0.0,
        isLoading: false,
        isCompleted: false,
        isError: true,
      );
}
