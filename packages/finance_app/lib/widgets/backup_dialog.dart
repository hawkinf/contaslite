import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/database_backup.dart';
import '../services/database_protection_service.dart';

class BackupDialogHelper {
  const BackupDialogHelper._();

  static Future<void> showBackupDialog(State state) async {
    try {
      final backups = await DatabaseProtectionService.instance.listBackups();
      if (!state.mounted) return;

      String lastBackupText = 'Nenhum backup encontrado';
      if (backups.isNotEmpty) {
        final lastBackup = backups.first;
        final formattedDate =
            DateFormat('dd/MM/yyyy HH:mm:ss').format(lastBackup.timestamp);
        lastBackupText =
            'Último backup: $formattedDate\nTamanho: ${lastBackup.formattedSize}';
      }

      if (!state.mounted) return;

      await showDialog<void>(
        context: state.context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('💾 Backup do Banco de Dados'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lastBackupText),
                const SizedBox(height: 16),
                Text(
                  'Total de backups mantidos: ${backups.length}/5',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continuar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await performBackupNow(state);
              },
              child: const Text('Fazer Backup Agora'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Erro ao mostrar dialog de backup: $e');
    }
  }

  static Future<void> performBackupNow(State state) async {
    try {
      if (!state.mounted) return;

      showDialog<void>(
        context: state.context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Criando backup...'),
            ],
          ),
        ),
      );

      final DatabaseBackup? backup =
          await DatabaseProtectionService.instance.createBackup('manual');

      if (!state.mounted) return;
      Navigator.pop(state.context);

      final String message;
      if (backup != null) {
        message =
            '✅ Backup criado com sucesso!\n\nArquivo: ${backup.filename}\nTamanho: ${backup.formattedSize}';
      } else {
        message = '❌ Erro ao criar backup. Tente novamente.';
      }

      if (!state.mounted) return;
      await showDialog<void>(
        context: state.context,
        builder: (context) => AlertDialog(
          title: const Text('Resultado do Backup'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Erro ao fazer backup: $e');
      if (!state.mounted) return;
      Navigator.pop(state.context);
      ScaffoldMessenger.of(state.context).showSnackBar(
        SnackBar(content: Text('Erro ao criar backup: $e')),
      );
    }
  }
}
