import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/database_config.dart';
import '../services/prefs_service.dart';
import '../database/postgresql_impl.dart';

class DatabaseSettingsScreen extends StatefulWidget {
  const DatabaseSettingsScreen({super.key});

  @override
  State<DatabaseSettingsScreen> createState() => _DatabaseSettingsScreenState();
}

class _DatabaseSettingsScreenState extends State<DatabaseSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _databaseController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _apiUrlController;

  bool _isEnabled = false;
  bool _isLoading = true;
  bool _showPassword = false;
  bool _isTesting = false;
  String? _testMessage;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
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
    if (!_isFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos')),
      );
      return;
    }

    try {
      final config = DatabaseConfig(
        host: _hostController.text.trim(),
        port: int.parse(_portController.text),
        database: _databaseController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        enabled: _isEnabled,
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
        _testMessage = '❌ Erro: $e';
        _isTesting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao conectar: $e')),
        );
      }
    }
  }

  bool _isFormValid() {
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
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
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
      ),
      body: SingleChildScrollView(
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

              // API URL (Optional)
              TextField(
                controller: _apiUrlController,
                decoration: InputDecoration(
                  labelText: 'URL da API (Opcional)',
                  hintText: 'https://contaslite.hawk.com.br/api',
                  prefixIcon: const Icon(Icons.cloud_queue),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'Deixe em branco para usar host:8080',
                ),
                enabled: !_isTesting,
                keyboardType: TextInputType.url,
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
                  onPressed: _isTesting ? null : _performBackup,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.backup),
                  label: Text(_isTesting ? 'Fazendo Backup...' : 'Fazer Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
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
      ),
    );
  }
}
