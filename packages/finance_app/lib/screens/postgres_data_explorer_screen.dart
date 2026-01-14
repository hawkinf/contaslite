import 'package:flutter/material.dart';
import '../database/postgresql_impl.dart';
import '../services/prefs_service.dart';

class PostgresDataExplorerScreen extends StatefulWidget {
  const PostgresDataExplorerScreen({super.key});

  @override
  State<PostgresDataExplorerScreen> createState() => _PostgresDataExplorerScreenState();
}

class _PostgresDataExplorerScreenState extends State<PostgresDataExplorerScreen> {
  final PostgreSQLImpl _db = PostgreSQLImpl();
  bool _isDisposed = false;
  bool _isLoading = true;
  bool _isLoadingRows = false;
  String? _error;
  List<String> _tables = [];
  String? _selectedTable;
  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _isDisposed = true;
    _db.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final config = await PrefsService.loadDatabaseConfig();
      if (!config.enabled || !config.isComplete) {
        if (!_isDisposed) {
          setState(() {
            _error = 'Configure o PostgreSQL antes de abrir o explorador.';
            _isLoading = false;
          });
        }
        return;
      }

      _db.configure(PostgreSQLConfig(
        host: config.host,
        port: config.port,
        database: config.database,
        username: config.username,
        password: config.password,
        apiUrl: config.apiUrl,
      ));
      await _db.initialize();

      final connected = await _db.isConnected();
      if (!connected) {
        if (!_isDisposed) {
          setState(() {
            _error = 'Não foi possível conectar ao PostgreSQL. Verifique as credenciais.';
            _isLoading = false;
          });
        }
        return;
      }

      await _loadTables();
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _error = 'Erro ao inicializar: $e';
        });
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTables() async {
    if (_isDisposed) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _db.rawQuery(
        "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name",
      ) as List<dynamic>;
      final tables = result
          .map((e) => (e as Map<String, dynamic>)['table_name'] as String)
          .toList();
      if (!_isDisposed) {
        setState(() {
          _tables = tables;
          _selectedTable = tables.isNotEmpty ? tables.first : null;
          if (_selectedTable == null) {
            _rows = [];
          }
        });
      }
      if (_selectedTable != null) {
        await _loadRows();
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _error = 'Erro ao carregar tabelas: $e';
        });
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRows() async {
    if (_selectedTable == null) return;
    if (_isDisposed) return;
    setState(() {
      _isLoadingRows = true;
      _error = null;
    });
    try {
      final raw = await _db.rawQuery('SELECT * FROM "${_selectedTable!}" LIMIT 200');
      final rows = (raw as List<dynamic>).cast<Map<String, dynamic>>();
      if (!_isDisposed) {
        setState(() => _rows = rows);
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _error = 'Erro ao carregar registros: $e';
        });
      }
    } finally {
      if (!_isDisposed) {
        setState(() => _isLoadingRows = false);
      }
    }
  }

  String? _detectIdField(Iterable<String> keys) {
    if (keys.contains('id')) return 'id';
    for (final key in keys) {
      if (key.toLowerCase().endsWith('id')) return key;
    }
    return null;
  }

  Future<void> _openRowEditor(Map<String, dynamic> row) async {
    final controllers = <String, TextEditingController>{};
    for (final entry in row.entries) {
      controllers[entry.key] = TextEditingController(
        text: entry.value?.toString() ?? '',
      );
    }
    final idField = _detectIdField(row.keys);
    final idValue = idField != null ? row[idField] : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Editar registro', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (idValue != null)
                        Text('ID: $idValue', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.5,
                    child: SingleChildScrollView(
                      child: Column(
                        children: controllers.entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    labelText: entry.key,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: idField == null || idValue == null
                              ? null
                              : () async {
                                  final payload = <String, dynamic>{};
                                  controllers.forEach((key, controller) {
                                    final original = row[key];
                                    final text = controller.text;
                                    if (text != (original?.toString() ?? '')) {
                                      if (original is int) {
                                        payload[key] = int.tryParse(text) ?? text;
                                      } else if (original is double) {
                                        payload[key] = double.tryParse(text) ?? text;
                                      } else if (text.isEmpty) {
                                        payload[key] = null;
                                      } else {
                                        payload[key] = text;
                                      }
                                    }
                                  });

                                  if (payload.isEmpty) {
                                    Navigator.pop(ctx);
                                    return;
                                  }

                                  final navigator = Navigator.of(ctx);
                                  final messenger = ScaffoldMessenger.of(ctx);
                                  try {
                                    await _db.update(
                                      _selectedTable!,
                                      values: payload,
                                      where: '"$idField" = ?',
                                      whereArgs: [idValue],
                                    );
                                    if (!mounted || !ctx.mounted) return;
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Registro atualizado'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    await _loadRows();
                                  } catch (e) {
                                    if (mounted && ctx.mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Erro ao salvar: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.save),
                          label: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorador de Dados (PostgreSQL)'),
        actions: [
          IconButton(
            tooltip: 'Recarregar tabelas',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTables,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_tables.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Tabela',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedTable,
                                    items: _tables
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) async {
                                      setState(() => _selectedTable = value);
                                      await _loadRows();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _isLoadingRows ? null : _loadRows,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Recarregar'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _isLoadingRows
                          ? const Center(child: CircularProgressIndicator())
                          : _rows.isEmpty
                              ? const Center(child: Text('Nenhum registro encontrado'))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) {
                                    final row = _rows[index];
                                    final preview = row.entries
                                        .take(3)
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(' | ');
                                    return Card(
                                      child: ListTile(
                                        title: Text(_selectedTable ?? '-'),
                                        subtitle: Text(preview),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _openRowEditor(row),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}
