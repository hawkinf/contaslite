import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../database/db_helper.dart';

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  Future<void> createBackup() async {
    try {
      debugPrint('💾 Iniciando backup do banco de dados...');

      // Obter caminho do banco de dados
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;

      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        debugPrint('❌ Arquivo do banco de dados não encontrado: $dbPath');
        return;
      }

      // Criar diretório de backups se não existir
      final backupDir = Directory(path.join(
        path.dirname(dbPath),
        'backups'
      ));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        debugPrint('📁 Diretório de backups criado: ${backupDir.path}');
      }

      // Gerar nome do arquivo de backup com timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupFileName = 'finance_backup_$timestamp.db';
      final backupPath = path.join(backupDir.path, backupFileName);

      // Copiar arquivo do banco de dados
      final backupFile = await sourceFile.copy(backupPath);

      debugPrint('✅ Backup criado com sucesso: ${backupFile.path}');

      // Limpar backups antigos (manter apenas os últimos 10)
      await _cleanOldBackups(backupDir);

    } catch (e) {
      debugPrint('❌ Erro ao criar backup: $e');
    }
  }

  Future<void> _cleanOldBackups(Directory backupDir) async {
    try {
      final files = <File>[];

      // Usar list() assíncrono em vez de listSync()
      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }

      // Ordenar por data de modificação (mais recentes primeiro)
      // Construir lista com timestamps para evitar múltiplas chamadas a stat()
      final filesWithDates = <(File file, DateTime modified)>[];
      for (final file in files) {
        final stat = await file.stat();
        filesWithDates.add((file, stat.modified));
      }

      // Ordenar por data (mais recentes primeiro)
      filesWithDates.sort((a, b) => b.$2.compareTo(a.$2));

      // Deletar backups antigos (manter apenas os últimos 10)
      if (filesWithDates.length > 10) {
        for (int i = 10; i < filesWithDates.length; i++) {
          await filesWithDates[i].$1.delete();
          debugPrint('🗑️  Backup antigo removido: ${path.basename(filesWithDates[i].$1.path)}');
        }
      }
    } catch (e) {
      debugPrint('⚠️  Erro ao limpar backups antigos: $e');
    }
  }

  Future<List<FileSystemEntity>> listBackups() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;
      final backupDir = Directory(path.join(
        path.dirname(dbPath),
        'backups'
      ));

      if (await backupDir.exists()) {
        final files = <(FileSystemEntity file, DateTime modified)>[];

        // Usar list() assíncrono em vez de listSync()
        await for (final entity in backupDir.list()) {
          if (entity is File && entity.path.endsWith('.db')) {
            final stat = await entity.stat();
            files.add((entity, stat.modified));
          }
        }

        // Ordenar por data (mais recentes primeiro)
        files.sort((a, b) => b.$2.compareTo(a.$2));

        // Retornar apenas os arquivos
        return files.map((f) => f.$1).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Erro ao listar backups: $e');
      return [];
    }
  }

  Future<bool> restoreBackup(String backupPath) async {
    try {
      debugPrint('🔄 Restaurando backup: $backupPath');
      
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;
      
      // Fechar banco de dados antes de restaurar
      await db.close();
      
      // Aguardar um pouco para garantir que o arquivo foi fechado
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Copiar arquivo de backup para substituir o banco de dados
      final backupFile = File(backupPath);
      
      if (!backupFile.existsSync()) {
        debugPrint('❌ Arquivo de backup não encontrado: $backupPath');
        return false;
      }
      
      await backupFile.copy(dbPath);
      
      debugPrint('✅ Backup restaurado com sucesso');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao restaurar backup: $e');
      return false;
    }
  }
}
