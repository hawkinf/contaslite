import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/prefs_service.dart';

/// Tela para explorar e editar dados do servidor via API REST
class ApiDataExplorerScreen extends StatefulWidget {
  const ApiDataExplorerScreen({super.key});

  @override
  State<ApiDataExplorerScreen> createState() => _ApiDataExplorerScreenState();
}

class _ApiDataExplorerScreenState extends State<ApiDataExplorerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;
  String? _apiBaseUrl;

  final List<String> _tables = [
    'accounts',
    'account_types',
    'account_descriptions',
    'banks',
    'payment_methods',
    'payments',
  ];

  final Map<String, String> _tableLabels = {
    'accounts': 'Contas',
    'account_types': 'Tipos de Conta',
    'account_descriptions': 'Categorias',
    'banks': 'Bancos',
    'payment_methods': 'Formas de Pagamento',
    'payments': 'Pagamentos',
  };

  final Map<String, List<Map<String, dynamic>>> _tableData = {};
  final Map<String, bool> _tableLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tables.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final table = _tables[_tabController.index];
    if (_tableData[table] == null) {
      _loadTableData(table);
    }
  }

  Future<void> _initialize() async {
    try {
      final config = await PrefsService.loadDatabaseConfig();

      if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
        _apiBaseUrl = config.apiUrl;
      } else if (config.enabled && config.host.isNotEmpty) {
        _apiBaseUrl = 'http://${config.host}:3000';
      } else {
        _apiBaseUrl = 'http://192.227.184.162:3000';
      }

      if (!AuthService.instance.isAuthenticated) {
        setState(() {
          _error = 'Você precisa estar logado para acessar o explorador de dados.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);

      // Carregar primeira tabela
      await _loadTableData(_tables.first);
    } catch (e) {
      setState(() {
        _error = 'Erro ao inicializar: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTableData(String table) async {
    if (_apiBaseUrl == null) return;

    setState(() {
      _tableLoading[table] = true;
      _error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/sync/pull?table=$table'),
        headers: AuthService.instance.getAuthHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final records = (data['records'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ?? [];

        setState(() {
          _tableData[table] = records;
          _tableLoading[table] = false;
        });
      } else if (response.statusCode == 401) {
        // Token expirado
        final refreshed = await AuthService.instance.refreshToken();
        if (refreshed) {
          return _loadTableData(table);
        } else {
          setState(() {
            _error = 'Sessão expirada. Faça login novamente.';
            _tableLoading[table] = false;
          });
        }
      } else {
        setState(() {
          _error = 'Erro ao carregar $table: ${response.statusCode}';
          _tableLoading[table] = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro de conexão: $e';
        _tableLoading[table] = false;
      });
    }
  }

  Future<void> _refreshCurrentTable() async {
    final table = _tables[_tabController.index];
    await _loadTableData(table);
  }

  Future<void> _refreshAllTables() async {
    for (final table in _tables) {
      await _loadTableData(table);
    }
  }

  String _getRecordTitle(String table, Map<String, dynamic> record) {
    switch (table) {
      case 'accounts':
        return record['description']?.toString() ?? 'Sem descrição';
      case 'account_types':
        return '${record['logo'] ?? ''} ${record['name'] ?? 'Sem nome'}'.trim();
      case 'account_descriptions':
        return record['categoria']?.toString() ?? 'Sem categoria';
      case 'banks':
        return record['name']?.toString() ?? 'Sem nome';
      case 'payment_methods':
        return record['name']?.toString() ?? 'Sem nome';
      case 'payments':
        return 'Pagamento #${record['id']} - R\$ ${record['value']?.toString() ?? '0'}';
      default:
        return 'ID: ${record['id']}';
    }
  }

  String _getRecordSubtitle(String table, Map<String, dynamic> record) {
    switch (table) {
      case 'accounts':
        final value = record['value'];
        final cardBrand = record['cardBrand'];
        if (cardBrand != null) {
          return '💳 $cardBrand - Limite: R\$ ${record['cardLimit'] ?? 0}';
        }
        return 'R\$ ${value ?? 0} - Vence dia ${record['dueDay'] ?? '-'}';
      case 'account_types':
        return 'ID: ${record['id']}';
      case 'account_descriptions':
        return 'Tipo ID: ${record['account_type_id'] ?? '-'}';
      case 'banks':
        return 'Ag: ${record['agency'] ?? '-'} | CC: ${record['account'] ?? '-'}';
      case 'payment_methods':
        return 'Tipo: ${record['type'] ?? '-'} | Uso: ${_getUsageLabel(record['usage'])}';
      case 'payments':
        return 'Data: ${record['paymentDate'] ?? '-'}';
      default:
        return '';
    }
  }

  String _getUsageLabel(dynamic usage) {
    switch (usage) {
      case 0:
        return 'Pagamentos';
      case 1:
        return 'Recebimentos';
      case 2:
        return 'Ambos';
      default:
        return '-';
    }
  }

  IconData _getTableIcon(String table) {
    switch (table) {
      case 'accounts':
        return Icons.receipt_long;
      case 'account_types':
        return Icons.category;
      case 'account_descriptions':
        return Icons.label;
      case 'banks':
        return Icons.account_balance;
      case 'payment_methods':
        return Icons.payment;
      case 'payments':
        return Icons.check_circle;
      default:
        return Icons.table_chart;
    }
  }

  void _showRecordDetails(String table, Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(_getTableIcon(table), color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getRecordTitle(table, record),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(table, record);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(table, record),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: record.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            entry.value?.toString() ?? 'null',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(String table, Map<String, dynamic> record) {
    final controllers = <String, TextEditingController>{};
    final editableFields = _getEditableFields(table);

    for (final field in editableFields) {
      controllers[field] = TextEditingController(
        text: record[field]?.toString() ?? '',
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getTableIcon(table)),
            const SizedBox(width: 8),
            const Text('Editar Registro'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(
                      labelText: _getFieldLabel(entry.key),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: _getKeyboardType(entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateRecord(table, record, controllers);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  List<String> _getEditableFields(String table) {
    switch (table) {
      case 'accounts':
        return ['description', 'value', 'dueDay', 'month', 'year', 'observation'];
      case 'account_types':
        return ['name', 'logo'];
      case 'account_descriptions':
        return ['categoria', 'logo'];
      case 'banks':
        return ['name', 'description', 'agency', 'account'];
      case 'payment_methods':
        return ['name', 'type'];
      case 'payments':
        return ['value', 'paymentDate', 'observation'];
      default:
        return [];
    }
  }

  String _getFieldLabel(String field) {
    final labels = {
      'description': 'Descrição',
      'value': 'Valor',
      'dueDay': 'Dia de Vencimento',
      'month': 'Mês',
      'year': 'Ano',
      'observation': 'Observação',
      'name': 'Nome',
      'logo': 'Logo/Emoji',
      'categoria': 'Categoria',
      'agency': 'Agência',
      'account': 'Conta',
      'type': 'Tipo',
      'paymentDate': 'Data do Pagamento',
    };
    return labels[field] ?? field;
  }

  TextInputType _getKeyboardType(String field) {
    if (['value', 'dueDay', 'month', 'year'].contains(field)) {
      return TextInputType.number;
    }
    return TextInputType.text;
  }

  Future<void> _updateRecord(
    String table,
    Map<String, dynamic> originalRecord,
    Map<String, TextEditingController> controllers,
  ) async {
    if (_apiBaseUrl == null) return;

    final updates = <String, dynamic>{};
    for (final entry in controllers.entries) {
      final newValue = entry.value.text;
      final originalValue = originalRecord[entry.key]?.toString() ?? '';
      if (newValue != originalValue) {
        // Tentar converter para número se aplicável
        if (['value', 'dueDay', 'month', 'year'].contains(entry.key)) {
          updates[entry.key] = num.tryParse(newValue) ?? newValue;
        } else {
          updates[entry.key] = newValue.isEmpty ? null : newValue;
        }
      }
    }

    if (updates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma alteração detectada')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/sync/push'),
        headers: AuthService.instance.getAuthHeaders(),
        body: jsonEncode({
          'table': table,
          'creates': [],
          'updates': [
            {
              'server_id': originalRecord['id'].toString(),
              ...updates,
            }
          ],
          'deletes': [],
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTableData(table);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(String table, Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirmar Exclusão'),
          ],
        ),
        content: Text(
          'Deseja realmente excluir "${_getRecordTitle(table, record)}"?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Fecha dialog de confirmação
              Navigator.pop(context); // Fecha bottom sheet
              await _deleteRecord(table, record);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(String table, Map<String, dynamic> record) async {
    if (_apiBaseUrl == null) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/sync/push'),
        headers: AuthService.instance.getAuthHeaders(),
        body: jsonEncode({
          'table': table,
          'creates': [],
          'updates': [],
          'deletes': [record['id'].toString()],
        }),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTableData(table);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildTableView(String table) {
    final isLoading = _tableLoading[table] ?? false;
    final records = _tableData[table];

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (records == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Carregando dados...'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadTableData(table),
              icon: const Icon(Icons.refresh),
              label: const Text('Carregar'),
            ),
          ],
        ),
      );
    }

    if (records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Nenhum registro em ${_tableLabels[table]}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTableData(table),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final record = records[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  _getTableIcon(table),
                  color: Theme.of(context).primaryColor,
                ),
              ),
              title: Text(
                _getRecordTitle(table, record),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _getRecordSubtitle(table, record),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRecordDetails(table, record),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explorador de Dados')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _tableData.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Explorador de Dados')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorador de Dados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar tabela atual',
            onPressed: _refreshCurrentTable,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh_all') {
                _refreshAllTables();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh_all',
                child: Row(
                  children: [
                    Icon(Icons.sync),
                    SizedBox(width: 8),
                    Text('Atualizar todas as tabelas'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tables.map((table) {
            final count = _tableData[table]?.length;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getTableIcon(table), size: 18),
                  const SizedBox(width: 6),
                  Text(_tableLabels[table] ?? table),
                  if (count != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tables.map((table) => _buildTableView(table)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
