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
      
      if (!File(dbPath).existsSync()) {
        debugPrint('❌ Arquivo do banco de dados não encontrado: $dbPath');
        return;
      }

      // Criar diretório de backups se não existir
      final backupDir = Directory(path.join(
        path.dirname(dbPath),
        'backups'
      ));
      
      if (!backupDir.existsSync()) {
        backupDir.createSync(recursive: true);
        debugPrint('📁 Diretório de backups criado: ${backupDir.path}');
      }

      // Gerar nome do arquivo de backup com timestamp
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final backupFileName = 'finance_backup_$timestamp.db';
      final backupPath = path.join(backupDir.path, backupFileName);

      // Copiar arquivo do banco de dados
      final sourceFile = File(dbPath);
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
      final files = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.db'))
          .toList();

      // Ordenar por data de modificação (mais recentes primeiro)
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      // Deletar backups antigos (manter apenas os últimos 10)
      if (files.length > 10) {
        for (int i = 10; i < files.length; i++) {
          files[i].deleteSync();
          debugPrint('🗑️  Backup antigo removido: ${path.basename(files[i].path)}');
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

      if (backupDir.existsSync()) {
        return backupDir
            .listSync()
            .where((f) => f.path.endsWith('.db'))
            .toList()
              ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
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
