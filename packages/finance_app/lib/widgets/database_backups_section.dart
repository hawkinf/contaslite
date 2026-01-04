import 'package:flutter/material.dart';
import '../models/database_backup.dart';
import '../models/integrity_check_result.dart';
import '../services/database_protection_service.dart';

class DatabaseBackupsSection extends StatefulWidget {
  const DatabaseBackupsSection({super.key});

  @override
  State<DatabaseBackupsSection> createState() => _DatabaseBackupsSectionState();
}

class _DatabaseBackupsSectionState extends State<DatabaseBackupsSection> {
  List<DatabaseBackup> backups = [];
  IntegrityCheckResult? lastIntegrityCheck;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // NÃO carregar na inicialização para evitar travamento
    // O carregamento será feito quando o usuário expandir a seção
  }

  Future<void> _loadBackups() async {
    if (!mounted) return;

    setState(() => isLoading = true);
    try {
      final loadedBackups =
          await DatabaseProtectionService.instance.listBackups();
      if (!mounted) return;
      setState(() => backups = loadedBackups);
    } catch (e) {
      debugPrint('Erro ao carregar backups: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar backups: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _checkIntegrity() async {
    setState(() => isLoading = true);
    try {
      final result =
          await DatabaseProtectionService.instance.validateIntegrity();
      setState(() => lastIntegrityCheck = result);

      if (!mounted) return;

      if (result.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.summary),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showIntegrityErrorDialog(result);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showIntegrityErrorDialog(IntegrityCheckResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Problemas Detectados'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.summary,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (result.errors.isNotEmpty) ...[
                const Text(
                  'Erros:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                ...result.errors.map(
                  (error) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child: Text('• $error', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              if (result.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Avisos:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                ...result.warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                    child:
                        Text('• $warning', style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(DatabaseBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: Text(
          'Restaurar backup de ${backup.displayName}?\n\nO banco de dados atual será sobrescrito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restaurando backup...')),
    );

    final success =
        await DatabaseProtectionService.instance.restoreBackup(backup);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restaurado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadBackups();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao restaurar backup'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteBackup(DatabaseBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Backup'),
        content: Text('Deletar backup de ${backup.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await DatabaseProtectionService.instance.deleteBackup(backup);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup deletado')),
    );

    _loadBackups();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Backups Automáticos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status do Banco',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (lastIntegrityCheck == null)
                          const Text(
                            'Não verificado',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                lastIntegrityCheck!.isValid
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: lastIntegrityCheck!.isValid
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lastIntegrityCheck!.summary,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: lastIntegrityCheck!.isValid
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _checkIntegrity,
                      icon: const Icon(Icons.check),
                      label: const Text('Verificar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Backups Disponíveis (${backups.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!isLoading)
                ElevatedButton.icon(
                  onPressed: _loadBackups,
                  icon: Icon(backups.isEmpty ? Icons.download : Icons.refresh, size: 16),
                  label: Text(backups.isEmpty ? 'Carregar' : 'Atualizar'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else if (backups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Clique em "Carregar" para listar os backups disponíveis',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadBackups,
                  icon: const Icon(Icons.download),
                  label: const Text('Carregar Backups'),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: backups.length,
            itemBuilder: (context, index) {
              final backup = backups[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 4.0,
                ),
                child: ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(backup.displayName),
                  subtitle: Text(
                    'v${backup.schemaVersion} | ${backup.formattedSize} | ${backup.isValid ? "✓ Íntegro" : "⚠️ Problemas"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: backup.isValid ? Colors.green : Colors.orange,
                    ),
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () {
                          Future.microtask(
                            () => _restoreBackup(backup),
                          );
                        },
                        child: const Text('Restaurar'),
                      ),
                      PopupMenuItem(
                        onTap: () {
                          Future.microtask(
                            () => _deleteBackup(backup),
                          );
                        },
                        child: const Text('Deletar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
