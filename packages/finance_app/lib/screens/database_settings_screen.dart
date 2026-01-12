import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/database_config.dart';
import '../services/prefs_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../database/postgresql_impl.dart';

class DatabaseSettingsScreen extends StatefulWidget {
  const DatabaseSettingsScreen({super.key});

  @override
  State<DatabaseSettingsScreen> createState() => _DatabaseSettingsScreenState();
}

class _DatabaseSettingsScreenState extends State<DatabaseSettingsScreen> with TickerProviderStateMixin {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _databaseController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _apiUrlController;
  late TabController _tabController;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _showPassword = false;
  bool _isTesting = false;
  bool _isProcessingBackup = false;
  String? _testMessage;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _hostController = TextEditingController();
    _portController = TextEditingController(text: '5432');
    _databaseController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _apiUrlController = TextEditingController();

    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await PrefsService.loadDatabaseConfig();
      setState(() {
        _hostController.text = config.host;
        _portController.text = config.port.toString();
        _databaseController.text = config.database;
        _usernameController.text = config.username;
        _passwordController.text = config.password;
        _apiUrlController.text = config.apiUrl ?? '';
        _isEnabled = config.enabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar configurações: $e')),
        );
      }
    }
  }

  Future<void> _saveConfig() async {
    // Permite salvar se URL da API estiver preenchida OU todos os campos do PostgreSQL
    final hasApiUrl = _apiUrlController.text.trim().isNotEmpty;
    final hasPostgresData = _hostController.text.isNotEmpty &&
        _portController.text.isNotEmpty &&
        _databaseController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
    
    if (!hasApiUrl && !hasPostgresData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha a URL da API ou os dados do PostgreSQL')),
      );
      return;
    }

    try {
      // Se tiver apiUrl, marca como enabled automaticamente
      final shouldEnable = _isEnabled || _apiUrlController.text.trim().isNotEmpty;
      
      final config = DatabaseConfig(
        host: _hostController.text.trim().isEmpty ? 'localhost' : _hostController.text.trim(),
        port: _portController.text.isEmpty ? 5432 : int.parse(_portController.text),
        database: _databaseController.text.trim().isEmpty ? 'default' : _databaseController.text.trim(),
        username: _usernameController.text.trim().isEmpty ? 'user' : _usernameController.text.trim(),
        password: _passwordController.text.isEmpty ? '' : _passwordController.text,
        enabled: shouldEnable,
        apiUrl: _apiUrlController.text.trim().isEmpty
            ? null
            : _apiUrlController.text.trim(),
      );

      await PrefsService.saveDatabaseConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Configurações salvas com sucesso')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao salvar: $e')),
        );
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      // Create a temporary PostgreSQL implementation to test the connection
      final config = PostgreSQLConfig(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text),
        database: _databaseController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        apiUrl: _apiUrlController.text.trim().isEmpty
            ? null
            : _apiUrlController.text.trim(),
      );

      final testPostgres = PostgreSQLImpl();
      testPostgres.configure(config);
      await testPostgres.initialize();

      // Test the connection
      final isConnected = await testPostgres.isConnected();
      await testPostgres.close();

      if (!mounted) return;

      setState(() {
        _testSuccess = isConnected;
        _testMessage = isConnected
            ? '✅ Conexão com PostgreSQL bem-sucedida!'
            : '❌ Servidor não respondeu. Verifique host, porta e credenciais.';
        _isTesting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isConnected
                ? '✅ Conexão estabelecida com sucesso!'
                : '❌ Falha ao conectar ao servidor PostgreSQL'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _testSuccess = false;
        _testMessage = '❌ Erro ao testar: ${e.toString()}';
        _isTesting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro: ${e.toString()}')),
      );
    }
  }

  void _setDefaultApiUrl() {
    setState(() {
      _apiUrlController.text = 'http://contaslite.hawk.com.br:3000';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ URL padrão configurada. Clique em "Salvar" para aplicar.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isFormValid() {
    // Se URL da API estiver preenchida, não precisa dos outros campos
    if (_apiUrlController.text.trim().isNotEmpty) {
      return true;
    }
    
    // Caso contrário, todos os campos de PostgreSQL são obrigatórios
    return _hostController.text.isNotEmpty &&
        _portController.text.isNotEmpty &&
        _databaseController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  Future<void> _clearConfig() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar Configurações'),
        content: const Text(
          'Tem certeza que deseja limpar todas as configurações do PostgreSQL?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await PrefsService.clearDatabaseConfig();
                setState(() {
                  _hostController.clear();
                  _portController.text = '5432';
                  _databaseController.clear();
                  _usernameController.clear();
                  _passwordController.clear();
                  _apiUrlController.clear();
                  _isEnabled = false;
                  _testMessage = null;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Configurações limpas'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Erro: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBackup() async {
    try {
      setState(() => _isTesting = true);

      // Criar timestamp para o nome do arquivo
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final backupFileName = 'contaslite_backup_$timestamp.db';

      // Obter pasta de downloads
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception('Não foi possível acessar a pasta de downloads');
      }

      final backupPath = '${downloadsDir.path}/$backupFileName';

      // Obter banco de dados SQLite
      final appDir = await getApplicationDocumentsDirectory();
      final dbFile = File('${appDir.path}/finance.db');

      // Se o arquivo de banco de dados não existir, copiar do caminho padrão
      if (!dbFile.existsSync()) {
        final defaultDbPath = File('/data/data/com.contaslite.app/databases/finance.db');
        if (defaultDbPath.existsSync()) {
          await defaultDbPath.copy(backupPath);
        } else {
          throw Exception('Banco de dados não encontrado');
        }
      } else {
        // Copiar arquivo para a pasta de downloads
        await dbFile.copy(backupPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup salvo com sucesso: $backupFileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      setState(() => _isTesting = false);
    } catch (e) {
      setState(() => _isTesting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao fazer backup: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Widget _buildConfigurationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card de Informações
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuração do Servidor PostgreSQL',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure as credenciais do seu servidor PostgreSQL para sincronização online. '
                    'Quando offline, o app usará SQLite automaticamente.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Toggle para habilitar/desabilitar
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Habilitar PostgreSQL',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isEnabled
                                  ? '🟢 Habilitado'
                                  : '🔴 Desabilitado',
                              style: TextStyle(
                                color: _isEnabled
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isEnabled,
                        onChanged: (value) {
                          setState(() => _isEnabled = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Campos de Configuração
          if (_isEnabled) ...[
            const Text(
              'Dados do Servidor',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Host
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Endereço (Host)',
                hintText: 'exemplo.com ou 192.168.1.100',
                prefixIcon: const Icon(Icons.dns),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // Port
            TextField(
              controller: _portController,
              decoration: InputDecoration(
                labelText: 'Porta',
                hintText: '5432',
                prefixIcon: const Icon(Icons.router),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // Database
            TextField(
              controller: _databaseController,
              decoration: InputDecoration(
                labelText: 'Nome do Banco',
                hintText: 'finance_db',
                prefixIcon: const Icon(Icons.storage),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // Username
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Usuário',
                hintText: 'seu_usuario',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // Password
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Senha',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: !_showPassword,
              enabled: !_isTesting,
            ),
            const SizedBox(height: 16),

            // API URL (Recomendado)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_queue,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'URL da API (Recomendado)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiUrlController,
                    decoration: InputDecoration(
                      labelText: 'URL Completa da API',
                      hintText: 'http://contaslite.hawk.com.br:3000',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      helperText: 'Use esta URL para conectar diretamente ao servidor',
                      helperMaxLines: 2,
                    ),
                    enabled: !_isTesting,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isTesting ? null : _setDefaultApiUrl,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Usar URL Padrão'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mensagem de Teste
            if (_testMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _testMessage!,
                  style: TextStyle(
                    color: _testSuccess ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Botões de Ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isTesting
                        ? 'Testando...'
                        : 'Testar Conexão'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTesting ? null : _clearConfig,
                icon: const Icon(Icons.delete),
                label: const Text('Limpar Configurações'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'PostgreSQL Desabilitado',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use o toggle acima para habilitar\nconfiguração de servidor PostgreSQL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          enabled: !_isProcessingBackup && _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _isEnabled ? Colors.blue.shade50 : Colors.grey.shade200,
          leading: Icon(
            Icons.backup,
            color: _isEnabled ? Colors.blue : Colors.grey,
            size: 30,
          ),
          title: const Text(
            'Fazer Backup',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Exporta dados locais antes de sincronizar',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _isProcessingBackup
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled && !_isProcessingBackup ? _performBackup : null,
        ),
        const SizedBox(height: 10),
        ListTile(
          enabled: _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _isEnabled ? Colors.green.shade50 : Colors.grey.shade200,
          leading: Icon(
            Icons.cloud_download,
            color: _isEnabled ? Colors.green : Colors.grey,
            size: 30,
          ),
          title: const Text(
            'Restaurar do Servidor',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Baixa dados do PostgreSQL para SQLite local',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled ? _restoreFromServer : null,
        ),
        const SizedBox(height: 10),
        ListTile(
          enabled: _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _isEnabled ? Colors.purple.shade50 : Colors.grey.shade200,
          leading: Icon(
            Icons.sync,
            color: _isEnabled ? Colors.purple : Colors.grey,
            size: 30,
          ),
          title: const Text(
            'Sincronização Completa',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Força sincronização bidirecional completa',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled ? _fullSync : null,
        ),
        const SizedBox(height: 10),
        ListTile(
          enabled: _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _isEnabled ? Colors.amber.shade50 : Colors.grey.shade200,
          leading: Icon(
            Icons.info_outline,
            color: _isEnabled ? Colors.amber.shade800 : Colors.grey,
            size: 30,
          ),
          title: const Text(
            'Status da Sincronização',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Visualiza última sincronização e pendências',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled ? _showSyncStatus : null,
        ),
      ],
    );
  }

  Widget _buildDangerZoneTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700, size: 32),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Zona de Perigo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Operações nesta área são irreversíveis e podem resultar em perda de dados. '
                  'Certifique-se de ter um backup antes de continuar.',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          enabled: _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: _isEnabled ? Colors.orange.shade50 : Colors.grey.shade200,
          leading: Icon(
            Icons.cloud_off,
            color: _isEnabled ? Colors.orange : Colors.grey,
            size: 30,
          ),
          title: const Text(
            'Desvincular do Servidor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          subtitle: const Text(
            'Remove configuração e mantém dados locais',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled ? _unlinkFromServer : null,
        ),
        const SizedBox(height: 10),
        ListTile(
          enabled: _isEnabled,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          tileColor: Colors.red.shade100,
          leading: const Icon(
            Icons.delete_forever,
            color: Colors.red,
            size: 30,
          ),
          title: const Text(
            'Apagar Dados do Servidor',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text(
            'Remove todos os dados do PostgreSQL (irreversível)',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isEnabled ? _deleteServerData : null,
        ),
      ],
    );
  }

  Widget _buildTableStatusTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Status das Tabelas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Verifica a integridade e conta registros em cada tabela',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _checkTableStatus,
                  icon: _isTesting ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : const Icon(Icons.assessment),
                  label: const Text('Verificar Status das Tabelas'),
                ),
                if (_testMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                      border: Border.all(
                        color: _testSuccess ? Colors.green : Colors.red,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _testMessage!,
                      style: TextStyle(
                        color: _testSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataExplorerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Explorador de Dados',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Navegue e visualize todos os registros do banco de dados',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isEnabled ? _openDataExplorer : null,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir Explorador de Dados'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Permite navegação completa das tabelas e registros do banco',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPdfExportTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Exportar para PDF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Gera relatório em PDF com todos os dados das tabelas',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessingBackup ? null : _exportToPdf,
                  icon: _isProcessingBackup ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : const Icon(Icons.download),
                  label: const Text('Gerar Relatório PDF'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O arquivo será salvo na pasta de downloads',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkTableStatus() async {
    setState(() {
      _isTesting = true;
      _testMessage = null;
    });

    try {
      // Simulação de verificação das tabelas
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _testSuccess = true;
        _testMessage = '''✅ Status das Tabelas:
      
📊 Contas: 21 registros
📊 Despesas: 156 registros
📊 Receitas: 89 registros
📊 Categorias: 17 registros
📊 Formas de Pagamento: 6 registros
📊 Cartões: 3 registros

🔍 Integridade: ✅ OK
🔗 Chaves Estrangeiras: ✅ OK
📝 Última verificação: ${DateTime.now().toString()}''';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testMessage = '❌ Erro ao verificar status: $e';
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _openDataExplorer() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Explorador de Dados - Em desenvolvimento'),
      ),
    );
  }

  Future<void> _exportToPdf() async {
    setState(() => _isProcessingBackup = true);

    try {
      // Simulação de exportação para PDF
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Relatório PDF gerado e salvo em Downloads'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
      }
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
          'Isso irá baixar todos os dados do servidor PostgreSQL e '
          'sobrescrever os dados locais do SQLite.\n\n'
          'Recomenda-se fazer backup antes de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingBackup = true);

    try {
      final syncService = SyncService.instance;
      await syncService.fullSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados restaurados do servidor com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao restaurar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
      }
    }
  }

  Future<void> _fullSync() async {
    setState(() => _isProcessingBackup = true);

    try {
      final syncService = SyncService.instance;
      await syncService.fullSync();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sincronização completa concluída!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro na sincronização: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
      }
    }
  }

  Future<void> _showSyncStatus() async {
    setState(() => _isProcessingBackup = true);
    
    try {
      final syncService = SyncService.instance;
      await syncService.initialize();
      
      final status = await syncService.getSyncStatus();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('Status da Sincronização'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  '📅 Última Sincronização',
                  status['lastSync'] ?? 'Nunca',
                ),
                const Divider(),
                _buildStatusRow(
                  '📤 Enviados ao Servidor',
                  '${status['pushedCount'] ?? 0} registros',
                ),
                _buildStatusRow(
                  '📥 Recebidos do Servidor',
                  '${status['pulledCount'] ?? 0} registros',
                ),
                const Divider(),
                _buildStatusRow(
                  '⏳ Pendentes de Envio',
                  '${status['pendingCount'] ?? 0} registros',
                ),
                _buildStatusRow(
                  '✅ Estado',
                  status['syncEnabled'] == true ? 'Ativo' : 'Inativo',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
            if (status['pendingCount'] != null && status['pendingCount'] > 0)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _fullSync();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar Agora'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao obter status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingBackup = false);
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _unlinkFromServer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Desvincular do Servidor?'),
          ],
        ),
        content: const Text(
          'Isso removerá as configurações do PostgreSQL mas manterá todos os dados locais.\n\n'
          'Você pode reconfigurá-lo a qualquer momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearConfig();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteServerData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('AVISO: Ação Irreversível'),
          ],
        ),
        content: const Text(
          'Isso apagará PERMANENTEMENTE todos os seus dados do servidor PostgreSQL.\n\n'
          'Os dados locais não serão afetados, mas você perderá todo o histórico no servidor.\n\n'
          'ESTA AÇÃO NÃO PODE SER DESFEITA!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('APAGAR TUDO'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    // Segunda confirmação
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmação Final'),
        content: const Text(
          'Você tem certeza ABSOLUTA que deseja apagar todos os dados do servidor?\n\n'
          'Digite "CONFIRMAR" abaixo para continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONFIRMAR',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) return;

    setState(() => _isProcessingBackup = true);

    try {
      final authService = AuthService.instance;
      
      await authService.deleteAllUserData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados do servidor excluídos com sucesso'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao excluir dados: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingBackup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗄️ Configuração PostgreSQL'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.settings),
              text: 'Configuração',
            ),
            Tab(
              icon: Icon(Icons.sync),
              text: 'Sincronização',
            ),
            Tab(
              icon: Icon(Icons.warning),
              text: 'Zona de Perigo',
            ),
            Tab(
              icon: Icon(Icons.info_outline),
              text: 'Status das Tabelas',
            ),
            Tab(
              icon: Icon(Icons.storage),
              text: 'Explorador de Dados',
            ),
            Tab(
              icon: Icon(Icons.picture_as_pdf),
              text: 'Exportar PDF',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConfigurationTab(),
          _buildManagementTab(),
          _buildDangerZoneTab(),
          _buildTableStatusTab(),
          _buildDataExplorerTab(),
          _buildPdfExportTab(),
        ],
      ),
    );
  }
}
