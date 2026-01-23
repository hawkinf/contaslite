import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/db_helper.dart';
import '../models/database_backup.dart';
import '../models/integrity_check_result.dart';

class DatabaseProtectionService {
  static final DatabaseProtectionService instance =
      DatabaseProtectionService._init();

  DatabaseProtectionService._init();

  static const int _maxBackups = 5;
  static const String _backupDirName = 'ContasLite/Backups';
  static const String _logsDirName = 'ContasLite/Logs';

  Future<Directory> getBackupDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(documentsDir.path, _backupDirName));

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    return backupDir;
  }

  Future<Directory> getLogsDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(path.join(documentsDir.path, _logsDirName));

    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    return logsDir;
  }

  Future<void> _writeLog(String message) async {
    try {
      final logsDir = await getLogsDirectory();
      final logFile = File(
        path.join(logsDir.path, 'database_operations.log'),
      );

      final timestamp =
          DateTime.now().toIso8601String().replaceAll('T', ' ');
      final logMessage = '[$timestamp] $message\n';

      await logFile.writeAsString(logMessage, mode: FileMode.append);
    } catch (e) {
      debugPrint('Erro ao escrever log: $e');
    }
  }

  Future<DatabaseBackup?> createBackup(String reason, {Database? databaseOverride}) async {
    try {
      final db = databaseOverride ?? await DatabaseHelper.instance.database;

      // Obter versão do banco
      final version = await db.getVersion();

      // Obter caminho do banco original
      final dbPath = await getDatabasesPath();
      final originalFile = File(path.join(dbPath, 'finance_v62.db'));

      if (!await originalFile.exists()) {
        _writeLog('❌ Arquivo do banco não encontrado: ${originalFile.path}');
        return null;
      }

      // Criar diretório de backups
      final backupDir = await getBackupDirectory();

      // Gerar nome do arquivo de backup
      final timestamp = DateTime.now();
      final timestampStr =
          '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
      final backupFilename = 'contas_v${version}_${timestampStr}_$reason.db';
      final backupFile = File(path.join(backupDir.path, backupFilename));

      // Calcular checksum do arquivo original
      final checksum = await _calculateChecksum(originalFile);

      // Copiar arquivo
      await originalFile.copy(backupFile.path);

      // Obter tamanho do arquivo
      final fileSize = await backupFile.length();

      // Criar arquivo de metadados
      final backup = DatabaseBackup(
        filename: backupFilename,
        timestamp: timestamp,
        schemaVersion: version,
        reason: reason,
        fileSizeBytes: fileSize,
        checksum: checksum,
        file: backupFile,
        metadataFile: File('${backupFile.path}.json'),
        isValid: true,
      );

      await _saveBackupMetadata(backup);

      _writeLog(
        '✓ Backup criado: $backupFilename (v$version, ${backup.formattedSize})',
      );

      // Rotacionar backups antigos
      await rotateBackups();

      return backup;
    } catch (e) {
      _writeLog('❌ Erro ao criar backup: $e');
      debugPrint('Erro ao criar backup: $e');
      return null;
    }
  }

  Future<String> _calculateChecksum(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      debugPrint('Erro ao calcular checksum: $e');
      return '';
    }
  }

  Future<void> _saveBackupMetadata(DatabaseBackup backup) async {
    try {
      final metadata = backup.toJson();
      final jsonString = jsonEncode(metadata);
      await backup.metadataFile.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Erro ao salvar metadados do backup: $e');
    }
  }

  Future<List<DatabaseBackup>> listBackups() async {
    try {
      final backupDir = await getBackupDirectory();
      final backups = <DatabaseBackup>[];

      if (!await backupDir.exists()) {
        return backups;
      }

      // Usar list() assíncrono em vez de listSync() para não bloquear
      await for (final entity in backupDir.list()) {
        if (entity is File) {
          final file = entity;
          if (file.path.endsWith('.db')) {
            final metadataFile = File('${file.path}.json');

            if (await metadataFile.exists()) {
              try {
                final jsonString = await metadataFile.readAsString();
                final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

                final backup = DatabaseBackup.fromJson(jsonData);
                backups.add(
                  DatabaseBackup(
                    filename: backup.filename,
                    timestamp: backup.timestamp,
                    schemaVersion: backup.schemaVersion,
                    reason: backup.reason,
                    fileSizeBytes: backup.fileSizeBytes,
                    checksum: backup.checksum,
                    file: file,
                    metadataFile: metadataFile,
                    isValid: backup.isValid,
                  ),
                );
              } catch (e) {
                debugPrint('Erro ao ler metadados de ${file.path}: $e');
              }
            }
          }
        }
      }

      // Ordenar por data (mais recente primeiro)
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return backups;
    } catch (e) {
      debugPrint('Erro ao listar backups: $e');
      return [];
    }
  }

  Future<void> rotateBackups() async {
    try {
      final backups = await listBackups();

      if (backups.length <= _maxBackups) {
        return;
      }

      // Manter apenas os _maxBackups mais recentes
      final backupsToDelete = backups.sublist(_maxBackups);

      for (final backup in backupsToDelete) {
        try {
          if (await backup.file.exists()) {
            await backup.file.delete();
          }
          if (await backup.metadataFile.exists()) {
            await backup.metadataFile.delete();
          }
          _writeLog('🗑️ Backup antigo removido: ${backup.filename}');
        } catch (e) {
          debugPrint('Erro ao remover backup antigo: $e');
        }
      }
    } catch (e) {
      debugPrint('Erro ao fazer rotação de backups: $e');
    }
  }

  Future<bool> restoreBackup(DatabaseBackup backup) async {
    try {
      final dbPath = await getDatabasesPath();
      final currentDbPath = path.join(dbPath, 'finance_v62.db');
      final currentDbFile = File(currentDbPath);

      // Fechar banco de dados
      await DatabaseHelper.instance.closeDatabase();

      // Remover banco atual
      if (await currentDbFile.exists()) {
        await currentDbFile.delete();
      }

      // Restaurar backup
      await backup.file.copy(currentDbPath);

      _writeLog('✓ Banco restaurado do backup: ${backup.filename}');

      // Reabrir banco
      await DatabaseHelper.instance.reopenDatabase();

      return true;
    } catch (e) {
      _writeLog('❌ Erro ao restaurar backup: $e');
      debugPrint('Erro ao restaurar backup: $e');

      // Tentar reabrir banco mesmo que deu erro
      try {
        await DatabaseHelper.instance.reopenDatabase();
      } catch (reopenError) {
        debugPrint('Erro ao reabrir banco após falha de restauração: $reopenError');
      }

      return false;
    }
  }

  Future<IntegrityCheckResult> validateIntegrity() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final errors = <String>[];
      final warnings = <String>[];
      final details = <String, dynamic>{};

      // 1. PRAGMA integrity_check
      debugPrint('Executando PRAGMA integrity_check...');
      final integrityResult =
          await db.rawQuery('PRAGMA integrity_check');

      if (integrityResult.isNotEmpty) {
        final result = integrityResult.first['integrity_check'] as String?;
        details['integrity_check'] = result;

        if (result != 'ok') {
          errors.add('Integridade do banco comprometida: $result');
        }
      }

      // 2. PRAGMA foreign_key_check
      debugPrint('Executando PRAGMA foreign_key_check...');
      final fkResult = await db.rawQuery('PRAGMA foreign_key_check');

      if (fkResult.isNotEmpty) {
        details['foreign_key_violations'] = fkResult.length;
        errors.add('${fkResult.length} violações de chave estrangeira detectadas');
      }

      // 3. Verificar tabelas obrigatórias
      debugPrint('Verificando tabelas obrigatórias...');
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final requiredTables = [
        'account_types',
        'account_descriptions',
        'accounts',
        'payment_methods',
        'banks',
        'payments',
      ];

      final existingTables =
          tables.map((t) => t['name'] as String).toSet();
      final missingTables =
          requiredTables.where((t) => !existingTables.contains(t)).toList();

      if (missingTables.isNotEmpty) {
        errors.add('Tabelas obrigatórias faltando: ${missingTables.join(", ")}');
      }

      details['total_tables'] = tables.length;

      // 4. Verificar consistência de dados
      debugPrint('Verificando consistência de dados...');

      // Contas sem tipo existente
      final orphanAccounts = await db.rawQuery('''
        SELECT COUNT(*) as count FROM accounts a
        LEFT JOIN account_types at ON a.typeId = at.id
        WHERE at.id IS NULL
      ''');

      final orphanAccountCount = orphanAccounts.first['count'] as int? ?? 0;
      if (orphanAccountCount > 0) {
        errors.add('$orphanAccountCount contas com tipo inválido');
      }

      // Pagamentos sem conta
      final orphanPayments = await db.rawQuery('''
        SELECT COUNT(*) as count FROM payments p
        LEFT JOIN accounts a ON p.account_id = a.id
        WHERE a.id IS NULL
      ''');

      final orphanPaymentCount =
          orphanPayments.first['count'] as int? ?? 0;
      if (orphanPaymentCount > 0) {
        errors.add('$orphanPaymentCount pagamentos órfãos (sem conta)');
      }

      details['orphan_accounts'] = orphanAccountCount;
      details['orphan_payments'] = orphanPaymentCount;

      final isValid = errors.isEmpty;

      _writeLog(
        isValid
            ? '✓ Validação de integridade: OK'
            : '❌ Validação de integridade: ${errors.length} erro(s)',
      );

      return IntegrityCheckResult(
        isValid: isValid,
        errors: errors,
        warnings: warnings,
        checkedAt: DateTime.now(),
        details: details,
      );
    } catch (e) {
      _writeLog('❌ Erro ao validar integridade: $e');
      debugPrint('Erro ao validar integridade: $e');

      return IntegrityCheckResult(
        isValid: false,
        errors: ['Erro durante validação: $e'],
        warnings: [],
        checkedAt: DateTime.now(),
      );
    }
  }

  Future<void> deleteBackup(DatabaseBackup backup) async {
    try {
      if (await backup.file.exists()) {
        await backup.file.delete();
      }
      if (await backup.metadataFile.exists()) {
        await backup.metadataFile.delete();
      }
      _writeLog('🗑️ Backup deletado: ${backup.filename}');
    } catch (e) {
      _writeLog('❌ Erro ao deletar backup: $e');
      debugPrint('Erro ao deletar backup: $e');
    }
  }
}
