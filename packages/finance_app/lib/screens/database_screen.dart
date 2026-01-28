import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import '../models/database_config.dart';
import '../services/auth_service.dart';
import '../services/database_initialization_service.dart';
import '../services/pdf_export_service.dart';
import '../services/prefs_service.dart';
import '../services/sync_service.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/database_backups_section.dart';
import '../widgets/sync_conflict_dialog.dart';
import 'data_explorer_screen.dart';

class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({super.key});

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _apiUrlController;
  bool _isProcessingBackup = false;
  bool _isRepairing = false;
  bool _isTesting = false;
  bool _serverEnabled = false;
  String? _testMessage;
  bool _testSuccess = false;
 
  Color _tileBackgroundColor(BuildContext context, Color lightColor) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }
    return lightColor;
  }

  Color _tileIconColor(BuildContext context, Color lightColor) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return Theme.of(context).colorScheme.primary;
    }
    return lightColor;
  }

  TextStyle _tileTitleStyle(BuildContext context, {FontWeight weight = FontWeight.w600}) {
    final base = Theme.of(context).textTheme.titleMedium;
    return (base ?? const TextStyle()).copyWith(
      fontWeight: weight,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  TextStyle _tileSubtitleStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall;
    return (base ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _apiUrlController = TextEditingController();
    _loadServerConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadServerConfig() async {
    try {
      final config = await PrefsService.loadDatabaseConfig();
      setState(() {
        _apiUrlController.text = config.apiUrl ?? '';
        _serverEnabled = config.enabled;
      });
    } catch (e) {
      // Ignore errors loading config
    }
  }

  Widget _buildBackupTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          enabled: !_isProcessingBackup,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _tileBackgroundColor(context, Colors.blue.shade50),
          leading: Icon(Icons.upload_file, color: _tileIconColor(context, Colors.blue), size: 30),
          title: Text('Exportar Banco de Dados', style: _tileTitleStyle(context)),
          subtitle: Text('Gera um arquivo .db para backup manual', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
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
          tileColor: _tileBackgroundColor(context, Colors.green.shade50),
          leading: Icon(Icons.download, color: _tileIconColor(context, Colors.green), size: 30),
          title: Text('Importar Banco de Dados', style: _tileTitleStyle(context)),
          subtitle: Text('Substitui os dados atuais por um backup', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
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
          tileColor: _tileBackgroundColor(context, Colors.teal.shade50),
          leading: Icon(Icons.folder_open, color: _tileIconColor(context, Colors.teal), size: 30),
          title: Text('Mostrar caminho do banco', style: _tileTitleStyle(context)),
          subtitle: Text('Exibe a localização do arquivo .db', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showDatabasePath,
        ),
        const SizedBox(height: 10),
        ListTile(
          enabled: !_isRepairing,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _tileBackgroundColor(context, Colors.orange.shade50),
          leading: Icon(Icons.build_circle, color: _tileIconColor(context, Colors.orange), size: 30),
          title: Text('Reparar Banco de Dados', style: _tileTitleStyle(context)),
          subtitle: Text('Executa checagem de integridade e reorganiza o arquivo', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
          trailing: _isRepairing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _repairDatabase,
        ),
      ],
    );
  }

  Widget _buildManagementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _tileBackgroundColor(context, Colors.indigo.shade50),
          leading: Icon(Icons.info_outline, color: _tileIconColor(context, Colors.indigo), size: 30),
          title: Text('Status das Tabelas', style: _tileTitleStyle(context)),
          subtitle: Text('Verifica quantos registros existem', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showTableStatusDialog,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _tileBackgroundColor(context, Colors.green.shade50),
          leading: Icon(Icons.explore, color: _tileIconColor(context, Colors.green), size: 30),
          title: Text('Explorador de Dados', style: _tileTitleStyle(context)),
          subtitle: Text('Navegue e visualize todos os registros do banco', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
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
          tileColor: _tileBackgroundColor(context, Colors.purple.shade50),
          leading: Icon(Icons.picture_as_pdf, color: _tileIconColor(context, Colors.purple), size: 30),
          title: Text('Exportar para PDF', style: _tileTitleStyle(context)),
          subtitle: Text('Gera relatório com todos os dados das tabelas', maxLines: 2, overflow: TextOverflow.ellipsis, style: _tileSubtitleStyle(context)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _exportDataToPdf,
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _tileBackgroundColor(context, Colors.amber.shade50),
          leading: Icon(Icons.refresh, color: _tileIconColor(context, Colors.amber), size: 30),
          title: Text('Recriar Tabelas Padrão', style: _tileTitleStyle(context)),
          subtitle: Text('Apaga e recria categorias e formas de pagamento', style: _tileSubtitleStyle(context)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _showRecreateTablesDialog,
        ),
      ],
    );
  }

  Widget _buildAutomaticBackupsTab() {
    return const SingleChildScrollView(
      child: DatabaseBackupsSection(),
    );
  }

  Widget _buildDangerZoneTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
    );
  }

  Widget _buildServerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Sincronização com Servidor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure a URL da API para sincronizar seus dados online.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                // Toggle
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Habilitar Sincronização', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            _serverEnabled ? 'Habilitado' : 'Desabilitado',
                            style: TextStyle(
                              color: _serverEnabled ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _serverEnabled,
                      onChanged: (value) => setState(() => _serverEnabled = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        if (_serverEnabled) ...[
          // API URL field
          TextField(
            controller: _apiUrlController,
            decoration: InputDecoration(
              labelText: 'URL da API',
              hintText: 'http://192.227.184.162:3000',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              helperText: 'URL completa do servidor de sincronização',
            ),
            enabled: !_isTesting,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isTesting ? null : () {
              setState(() {
                _apiUrlController.text = 'http://192.227.184.162:3000';
              });
            },
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Usar URL Padrão'),
          ),
          const SizedBox(height: 16),

          // Test message
          if (_testMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _testSuccess ? Colors.green : Colors.red),
              ),
              child: Text(
                _testMessage!,
                style: TextStyle(color: _testSuccess ? Colors.green.shade700 : Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testServerConnection,
                  icon: _isTesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isTesting ? 'Testando...' : 'Testar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTesting ? null : _saveServerConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sync operations
          const Divider(),
          const SizedBox(height: 8),
          Text('Operações de Sincronização', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 12),

          ListTile(
            enabled: !_isProcessingBackup,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: _tileBackgroundColor(context, Colors.green.shade50),
            leading: Icon(Icons.cloud_download, color: _tileIconColor(context, Colors.green), size: 30),
            title: Text('Restaurar do Servidor', style: _tileTitleStyle(context)),
            subtitle: Text('Baixa dados do servidor para o dispositivo', style: _tileSubtitleStyle(context)),
            trailing: _isProcessingBackup
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _restoreFromServer,
          ),
          const SizedBox(height: 10),
          ListTile(
            enabled: !_isProcessingBackup,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: _tileBackgroundColor(context, Colors.purple.shade50),
            leading: Icon(Icons.sync, color: _tileIconColor(context, Colors.purple), size: 30),
            title: Text('Sincronização Completa', style: _tileTitleStyle(context)),
            subtitle: Text('Sincroniza dados entre dispositivo e servidor', style: _tileSubtitleStyle(context)),
            trailing: _isProcessingBackup
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _fullSync,
          ),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Sincronização Desabilitada',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ative o toggle acima para configurar\na sincronização com o servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _testServerConnection() async {
    if (_apiUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha a URL da API')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      final apiUrl = _apiUrlController.text.trim();
      final uri = Uri.parse('$apiUrl/health');
      final response = await HttpClient().getUrl(uri).then((req) => req.close());
      final isConnected = response.statusCode == 200;

      if (!mounted) return;
      setState(() {
        _testSuccess = isConnected;
        _testMessage = isConnected ? 'Conexão bem-sucedida!' : 'Servidor não respondeu';
        _isTesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testMessage = 'Erro: ${e.toString()}';
        _isTesting = false;
      });
    }
  }

  Future<void> _saveServerConfig() async {
    try {
      final config = DatabaseConfig(
        host: 'localhost',
        port: 5432,
        database: 'default',
        username: 'user',
        password: '',
        enabled: _serverEnabled,
        apiUrl: _apiUrlController.text.trim().isEmpty ? null : _apiUrlController.text.trim(),
      );

      await PrefsService.saveDatabaseConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas com sucesso'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performAutoBackup() async {
    try {
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final backupFileName = 'contaslite_autobackup_$timestamp.db';

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) return;

      final backupPath = '${downloadsDir.path}/$backupFileName';
      final appDir = await getApplicationDocumentsDirectory();
      final dbFile = File('${appDir.path}/finance.db');

      if (dbFile.existsSync()) {
        await dbFile.copy(backupPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup automático criado: $backupFileName'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      // Ignore backup errors
    }
  }

  Future<void> _restoreFromServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Restaurar do Servidor?'),
          ],
        ),
        content: const Text(
          'Isso irá baixar todos os dados do servidor e sobrescrever os dados locais.\n\n'
          'Um backup automático será criado antes de continuar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restaurar')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingBackup = true);
    await _performAutoBackup();

    try {
      await SyncService.instance.fullSync();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados restaurados com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Future<void> _fullSync() async {
    setState(() => _isProcessingBackup = true);
    await _performAutoBackup();

    try {
      // Usar sincronização com resolução de conflitos pelo usuário
      final result = await SyncService.instance.fullSyncWithUserResolution(
        conflictResolver: (conflicts) async {
          if (!mounted) return ConflictResolutionResult.cancelled();
          return await SyncConflictDialog.show(context, conflicts);
        },
      );

      if (mounted) {
        final message = result.success
            ? 'Sincronização concluída! ${result.recordsPushed} enviados, ${result.recordsPulled} recebidos'
            : 'Sincronização concluída com avisos';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banco de Dados'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.backup), text: 'Local'),
            Tab(icon: Icon(Icons.cloud), text: 'Servidor'),
            Tab(icon: Icon(Icons.table_chart), text: 'Gerenciamento'),
            Tab(icon: Icon(Icons.schedule), text: 'Automático'),
            Tab(icon: Icon(Icons.warning), text: 'Crítico'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBackupTab(),
          _buildServerTab(),
          _buildManagementTab(),
          _buildAutomaticBackupsTab(),
          _buildDangerZoneTab(),
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
                _buildStatusRow('Formas de Pagamento/Recebimento', methods.length),
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
    String tipoPessoa = 'Ambos (PF e PJ)';

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                'Seus lançamentos serão preservados.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: tipoPessoa,
                decoration: buildOutlinedInputDecoration(
                  label: 'Tipo de Pessoa',
                  icon: Icons.person_outline,
                ),
                items: const [
                  DropdownMenuItem(value: 'Pessoa Física', child: Text('Pessoa Física')),
                  DropdownMenuItem(value: 'Pessoa Jurídica', child: Text('Pessoa Jurídica')),
                  DropdownMenuItem(value: 'Ambos (PF e PJ)', child: Text('Ambos (PF e PJ)')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoPessoa = value ?? 'Ambos (PF e PJ)';
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text(
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
                  final selectedTipoPessoa = tipoPessoa;
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

                    await DatabaseInitializationService.instance.populateDefaultData(
                      tipoPessoa: selectedTipoPessoa,
                    );

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
      ),
    );
  }

  Future<void> _showWipeDatabaseDialog() async {
    final confirmController = TextEditingController();
    final parentContext = context;
    String tipoPessoa = 'Ambos (PF e PJ)';
    bool alsoDeleteFromServer = false;
    final isAuthenticated = AuthService.instance.isAuthenticated;

    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                'Após apagar, as tabelas padrão serão recriadas.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: tipoPessoa,
                decoration: buildOutlinedInputDecoration(
                  label: 'Tipo de Pessoa',
                  icon: Icons.person_outline,
                ),
                items: const [
                  DropdownMenuItem(value: 'Pessoa Física', child: Text('Pessoa Física')),
                  DropdownMenuItem(value: 'Pessoa Jurídica', child: Text('Pessoa Jurídica')),
                  DropdownMenuItem(value: 'Ambos (PF e PJ)', child: Text('Ambos (PF e PJ)')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tipoPessoa = value ?? 'Ambos (PF e PJ)';
                  });
                },
              ),
              if (isAuthenticated) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: alsoDeleteFromServer,
                  onChanged: (value) {
                    setDialogState(() {
                      alsoDeleteFromServer = value ?? false;
                    });
                  },
                  title: const Text(
                    'Também apagar do servidor PostgreSQL',
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Remove os dados sincronizados na nuvem',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.red,
                ),
              ],
              const SizedBox(height: 16),
              const Text(
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
                  final selectedTipoPessoa = tipoPessoa;
                  final deleteFromServer = alsoDeleteFromServer;
                  if (mounted) Navigator.pop(dialogContext);
                  await _wipeAndRecreateDatabaseWithFeedback(
                    tipoPessoa: selectedTipoPessoa,
                    alsoDeleteFromServer: deleteFromServer,
                  );
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
      ),
    );
  }

  Future<void> _wipeAndRecreateDatabaseWithFeedback({
    String tipoPessoa = 'Ambos (PF e PJ)',
    bool alsoDeleteFromServer = false,
  }) async {
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
      // Se solicitado, apagar dados do servidor primeiro
      if (alsoDeleteFromServer) {
        addLog('Apagando dados do servidor PostgreSQL...');
        try {
          await AuthService.instance.deleteAllUserData();
          addLog('Dados do servidor apagados com sucesso.');
        } catch (e) {
          addLog('Erro ao apagar do servidor: $e');
          // Continua mesmo com erro no servidor
        }
      }

      addLog('Apagando tabelas e registros locais...');
      await DatabaseHelper.instance.clearDatabase();

      // Limpa metadados de sincronização
      addLog('Limpando metadados de sincronização...');
      await DatabaseHelper.instance.clearSyncMetadata();

      addLog('Recriando categorias e formas de pagamento padrão...');
      await DatabaseInitializationService.instance.populateDefaultData(tipoPessoa: tipoPessoa);

      addLog('Verificando consistência do banco...');
      await DatabaseInitializationService.instance.initializeDatabase();

      addLog('Processo concluído com sucesso.');
      await Future.delayed(const Duration(milliseconds: 400));

      if (dialogContext != null) {
        Navigator.of(dialogContext!, rootNavigator: true).pop();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alsoDeleteFromServer
            ? 'Banco local e servidor apagados e recriados com sucesso.'
            : 'Banco apagado e recriado com sucesso.'),
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
      final directory = await FilePicker.getDirectoryPath(
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
      final result = await FilePicker.pickFiles(
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
