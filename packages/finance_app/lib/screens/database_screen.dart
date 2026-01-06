import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../database/db_helper.dart';
import '../services/database_initialization_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/database_backups_section.dart';
import 'data_explorer_screen.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  bool _isProcessingBackup = false;
  bool _isRepairing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de dados'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Backup e Restauração',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            enabled: !_isProcessingBackup,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.blue.shade50,
            leading: const Icon(Icons.upload_file, color: Colors.blue, size: 30),
            title: const Text('Exportar Banco de Dados'),
            subtitle: const Text('Gera um arquivo .db para backup manual'),
            trailing: _isProcessingBackup
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _exportDatabase,
          ),
          const SizedBox(height: 10),
          ListTile(
            enabled: !_isProcessingBackup,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.green.shade50,
            leading: const Icon(Icons.download, color: Colors.green, size: 30),
            title: const Text('Importar Banco de Dados'),
            subtitle: const Text('Substitui os dados atuais por um backup'),
            trailing: _isProcessingBackup
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _importDatabase,
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.teal.shade50,
            leading: const Icon(Icons.folder_open, color: Colors.teal, size: 30),
            title: const Text('Mostrar caminho do banco'),
            subtitle: const Text('Exibe a localização do arquivo .db'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showDatabasePath,
          ),
          const SizedBox(height: 24),
          ListTile(
            enabled: !_isRepairing,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.orange.shade50,
            leading: const Icon(Icons.build_circle, color: Colors.orange, size: 30),
            title: const Text('Reparar Banco de Dados'),
            subtitle: const Text('Executa checagem de integridade e reorganiza o arquivo'),
            trailing: _isRepairing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _repairDatabase,
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 10),
          const Text(
            'Gerenciamento de Tabelas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.indigo.shade50,
            leading: const Icon(Icons.info_outline, color: Colors.indigo, size: 30),
            title: const Text('Status das Tabelas'),
            subtitle: const Text('Verifica quantos registros existem'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showTableStatusDialog,
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.green.shade50,
            leading: const Icon(Icons.explore, color: Colors.green, size: 30),
            title: const Text('Explorador de Dados'),
            subtitle: const Text('Navegue e visualize todos os registros do banco'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataExplorerScreen()),
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.purple.shade50,
            leading: const Icon(Icons.picture_as_pdf, color: Colors.purple, size: 30),
            title: const Text('Exportar para PDF'),
            subtitle: const Text('Gera relatório com todos os dados das tabelas'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _exportDataToPdf,
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.amber.shade50,
            leading: const Icon(Icons.refresh, color: Colors.amber, size: 30),
            title: const Text('Recriar Tabelas Padrão'),
            subtitle: const Text('Apaga e recria categorias e formas de pagamento'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showRecreateTablesDialog,
          ),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 10),
          const DatabaseBackupsSection(),
          const SizedBox(height: 20),
          const Divider(thickness: 2),
          const SizedBox(height: 10),
          const Text(
            'Zona de Perigo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.red.shade50,
            leading: const Icon(Icons.delete_forever, color: Colors.red, size: 30),
            title: const Text(
              'Apagar Todo o Banco de Dados',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Essa ação é irreversível.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showWipeDatabaseDialog,
          ),
        ],
      ),
    );
  }

  Future<void> _showTableStatusDialog() async {
    final db = DatabaseHelper.instance;

    try {
      final types = await db.readAllTypes();
      final categories = await db.readAllAccountCategories();
      final methods = await db.readPaymentMethods(onlyActive: false);

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Status das Tabelas'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow('Tipos de Contas', types.length),
                _buildStatusRow('Categorias', categories.length),
                _buildStatusRow('Formas de Pagamento', methods.length),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FECHAR'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao verificar tabelas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStatusRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.green.shade700 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecreateTablesDialog() async {
    final confirmController = TextEditingController();
    final parentContext = context;

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Recriar Tabelas Padrão?',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isso apagará e recriará as categorias de contas e formas de pagamento.\n\n'
              'Seus lançamentos serão preservados.\n\n'
              'Para confirmar, digite SIM no campo abaixo:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: buildOutlinedInputDecoration(
                label: 'Confirmação',
                icon: Icons.warning_amber_rounded,
                hintText: 'SIM',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              if (confirmController.text.trim() == 'SIM') {
                Navigator.pop(dialogContext);

                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                try {
                  final db = DatabaseHelper.instance;
                  final types = await db.readAllTypes();
                  for (final type in types) {
                    await db.deleteType(type.id!);
                  }

                  final methods = await db.readPaymentMethods(onlyActive: false);
                  for (final method in methods) {
                    await db.deletePaymentMethod(method.id!);
                  }

                  await DatabaseInitializationService.instance.populateDefaultData();

                  if (!mounted) return;
                  Navigator.pop(parentContext);

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Tabelas padrão recriadas com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(parentContext);

                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao recriar tabelas: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ação abortada. Texto de confirmação incorreto.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('RECRIAR TABELAS'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWipeDatabaseDialog() async {
    final confirmController = TextEditingController();
    final parentContext = context;

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'TEM CERTEZA?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Isso apagará TODOS os seus lançamentos, tipos de contas e configurações.\n\n'
              'Para confirmar, digite SIM no campo abaixo:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: buildOutlinedInputDecoration(
                label: 'Confirmação',
                icon: Icons.warning_amber_rounded,
                hintText: 'SIM',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmController.text.trim() == 'SIM') {
                if (mounted) Navigator.pop(dialogContext);
                await _wipeAndRecreateDatabaseWithFeedback();
              } else {
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Ação abortada. Texto de confirmação incorreto.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('APAGAR TUDO'),
          ),
        ],
      ),
    );
  }

  Future<void> _wipeAndRecreateDatabaseWithFeedback() async {
    if (!mounted) return;

    final logNotifier = ValueNotifier<List<String>>([]);
    BuildContext? dialogContext;

    void addLog(String message) {
      logNotifier.value = List.of(logNotifier.value)..add(message);
    }

    await Future.microtask(() {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            title: const Text('Recriando banco de dados'),
            content: SizedBox(
              width: 360,
              child: ValueListenableBuilder<List<String>>(
                valueListenable: logNotifier,
                builder: (_, logs, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    if (logs.isEmpty)
                      const Text('Preparando...')
                    else
                      ...logs.map(
                        (msg) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(msg),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });

    await Future.delayed(const Duration(milliseconds: 120));

    try {
      addLog('Apagando tabelas e registros...');
      await DatabaseHelper.instance.clearDatabase();

      addLog('Recriando categorias e formas de pagamento padrão...');
      await DatabaseInitializationService.instance.populateDefaultData();

      addLog('Verificando consistência do banco...');
      await DatabaseInitializationService.instance.initializeDatabase();

      addLog('Processo concluído com sucesso.');
      await Future.delayed(const Duration(milliseconds: 400));

      if (dialogContext != null) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banco apagado e recriado com sucesso.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (dialogContext != null) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao recriar banco: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportDatabase() async {
    if (_isProcessingBackup) return;
    setState(() => _isProcessingBackup = true);
    try {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecione a pasta para salvar o backup',
      );
      if (directory == null) return;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'contas_backup_$timestamp.db';
      final destinationPath = p.join(directory, fileName);
      await DatabaseHelper.instance.exportDatabase(destinationPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup exportado em $fileName'),
          backgroundColor: Colors.blue.shade700,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _importDatabase() async {
    if (_isProcessingBackup) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sobrescrever dados?'),
        content: const Text(
          'Importar um backup substituirá todas as contas atuais pelo conteúdo do arquivo selecionado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessingBackup = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Selecione o arquivo de backup (.db)',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      await DatabaseHelper.instance.importDatabase(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banco importado com sucesso! Atualize as telas para ver os dados.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao importar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _exportDataToPdf() async {
    try {
      await PdfExportService.instance.exportAllDataToPdf();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF gerado e compartilhado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _repairDatabase() async {
    if (_isRepairing) return;
    setState(() => _isRepairing = true);
    try {
      await DatabaseHelper.instance.repairDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banco verificado e otimizado com sucesso!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao reparar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRepairing = false);
    }
  }

  Future<void> _showDatabasePath() async {
    try {
      final path = await DatabaseHelper.instance.getDatabaseFilePath();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Caminho do banco'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Caminho copiado para a área de transferência.'),
                  ),
                );
              },
              child: const Text('Copiar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao obter o caminho: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
// ignore_for_file: use_build_context_synchronously
