import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Representa um conflito de dados entre dispositivo local e servidor
class ConflictItem {
  final String tableName;
  final int localId;
  final String? serverId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime? localUpdatedAt;
  final DateTime? serverUpdatedAt;

  /// Opção escolhida pelo usuário: 'local', 'server', ou null se não decidido
  String? userChoice;

  ConflictItem({
    required this.tableName,
    required this.localId,
    this.serverId,
    required this.localData,
    required this.serverData,
    this.localUpdatedAt,
    this.serverUpdatedAt,
    this.userChoice,
  });

  /// Nome amigável da tabela para exibição
  String get friendlyTableName {
    switch (tableName) {
      case 'accounts':
        return 'Conta';
      case 'account_types':
        return 'Tipo de Conta';
      case 'account_descriptions':
        return 'Categoria';
      case 'banks':
        return 'Banco';
      case 'payment_methods':
        return 'Forma de Pagamento';
      case 'payments':
        return 'Pagamento';
      default:
        return 'Registro';
    }
  }

  /// Nome/descrição do item para identificação
  String get itemName {
    // Tentar obter nome do registro local ou servidor
    final localName = localData['name'] ??
                      localData['description'] ??
                      localData['descricao'] ??
                      localData['categoria'] ??
                      localData['titulo'] ??
                      '';
    final serverName = serverData['name'] ??
                       serverData['description'] ??
                       serverData['descricao'] ??
                       serverData['categoria'] ??
                       serverData['titulo'] ??
                       '';
    return localName.toString().isNotEmpty ? localName.toString() : serverName.toString();
  }

  /// Valor principal para exibição (ex: valor monetário)
  String? get localValue {
    final value = localData['valor'] ?? localData['value'] ?? localData['amount'];
    if (value == null) return null;
    if (value is num) {
      return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
    }
    return value.toString();
  }

  String? get serverValue {
    final value = serverData['valor'] ?? serverData['value'] ?? serverData['amount'];
    if (value == null) return null;
    if (value is num) {
      return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
    }
    return value.toString();
  }
}

/// Resultado da resolução de conflitos
class ConflictResolutionResult {
  /// Itens que devem usar a versão local (enviar para servidor)
  final List<ConflictItem> useLocal;

  /// Itens que devem usar a versão do servidor (sobrescrever local)
  final List<ConflictItem> useServer;

  /// Se o usuário cancelou a operação
  final bool cancelled;

  ConflictResolutionResult({
    this.useLocal = const [],
    this.useServer = const [],
    this.cancelled = false,
  });

  factory ConflictResolutionResult.cancelled() =>
      ConflictResolutionResult(cancelled: true);
}

/// Diálogo amigável para resolução de conflitos de sincronização
class SyncConflictDialog extends StatefulWidget {
  final List<ConflictItem> conflicts;

  const SyncConflictDialog({
    super.key,
    required this.conflicts,
  });

  /// Exibe o diálogo e retorna o resultado da resolução
  static Future<ConflictResolutionResult> show(
    BuildContext context,
    List<ConflictItem> conflicts,
  ) async {
    if (conflicts.isEmpty) {
      return ConflictResolutionResult();
    }

    final result = await showDialog<ConflictResolutionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SyncConflictDialog(conflicts: conflicts),
    );

    return result ?? ConflictResolutionResult.cancelled();
  }

  @override
  State<SyncConflictDialog> createState() => _SyncConflictDialogState();
}

class _SyncConflictDialogState extends State<SyncConflictDialog> {
  late List<ConflictItem> _conflicts;
  int _currentIndex = 0;
  bool _applyToAll = false;
  String? _applyToAllChoice;

  @override
  void initState() {
    super.initState();
    _conflicts = List.from(widget.conflicts);
  }

  ConflictItem get _currentConflict => _conflicts[_currentIndex];

  bool get _allResolved => _conflicts.every((c) => c.userChoice != null);

  void _selectChoice(String choice) {
    setState(() {
      if (_applyToAll) {
        _applyToAllChoice = choice;
        for (final conflict in _conflicts) {
          conflict.userChoice = choice;
        }
      } else {
        _currentConflict.userChoice = choice;
      }
    });
  }

  void _nextConflict() {
    if (_currentIndex < _conflicts.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _previousConflict() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _finish() {
    final useLocal = <ConflictItem>[];
    final useServer = <ConflictItem>[];

    for (final conflict in _conflicts) {
      if (conflict.userChoice == 'local') {
        useLocal.add(conflict);
      } else if (conflict.userChoice == 'server') {
        useServer.add(conflict);
      }
    }

    Navigator.of(context).pop(ConflictResolutionResult(
      useLocal: useLocal,
      useServer: useServer,
    ));
  }

  void _cancel() {
    Navigator.of(context).pop(ConflictResolutionResult.cancelled());
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Data desconhecida';
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conflict = _currentConflict;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.compare_arrows, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados Diferentes Encontrados',
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  '${_currentIndex + 1} de ${_conflicts.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Descrição do conflito
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'O ${conflict.friendlyTableName.toLowerCase()} "${conflict.itemName}" '
                        'tem informações diferentes neste dispositivo e no servidor.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Opção: Manter versão deste dispositivo
              _buildOptionCard(
                title: 'Manter versão deste dispositivo',
                subtitle: 'Os dados salvos aqui serão enviados para o servidor',
                icon: Icons.phone_android,
                color: Colors.blue,
                date: conflict.localUpdatedAt,
                value: conflict.localValue,
                isSelected: conflict.userChoice == 'local',
                onTap: () => _selectChoice('local'),
              ),
              const SizedBox(height: 12),

              // Opção: Manter versão do servidor
              _buildOptionCard(
                title: 'Manter versão do servidor',
                subtitle: 'Os dados do servidor serão baixados para este dispositivo',
                icon: Icons.cloud,
                color: Colors.green,
                date: conflict.serverUpdatedAt,
                value: conflict.serverValue,
                isSelected: conflict.userChoice == 'server',
                onTap: () => _selectChoice('server'),
              ),
              const SizedBox(height: 16),

              // Checkbox para aplicar a todos
              if (_conflicts.length > 1)
                CheckboxListTile(
                  value: _applyToAll,
                  onChanged: (value) {
                    setState(() {
                      _applyToAll = value ?? false;
                      if (_applyToAll && _applyToAllChoice != null) {
                        for (final c in _conflicts) {
                          c.userChoice = _applyToAllChoice;
                        }
                      }
                    });
                  },
                  title: const Text(
                    'Aplicar esta escolha para todos os conflitos',
                    style: TextStyle(fontSize: 13),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
      actions: [
        // Botão Cancelar
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancelar Sincronização'),
        ),
        const Spacer(),
        // Navegação entre conflitos
        if (_conflicts.length > 1 && !_applyToAll) ...[
          IconButton(
            onPressed: _currentIndex > 0 ? _previousConflict : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Anterior',
          ),
          IconButton(
            onPressed: _currentIndex < _conflicts.length - 1 ? _nextConflict : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próximo',
          ),
        ],
        // Botão Concluir
        ElevatedButton(
          onPressed: _allResolved ? _finish : null,
          child: Text(_allResolved ? 'Aplicar Escolhas' : 'Escolha uma opção'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceBetween,
    );
  }

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required DateTime? date,
    required String? value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Ícone e radio button
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? color : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Última alteração: ${_formatDate(date)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Valor: $value',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Indicador de seleção
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
