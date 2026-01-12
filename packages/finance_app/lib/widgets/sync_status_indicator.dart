import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../database/sync_helpers.dart';

/// Widget que exibe o status de sincronização na AppBar
class SyncStatusIndicator extends StatelessWidget {
  /// Se deve mostrar o texto junto com o ícone
  final bool showLabel;

  /// Se deve permitir toque para sincronização manual
  final bool allowManualSync;

  const SyncStatusIndicator({
    super.key,
    this.showLabel = false,
    this.allowManualSync = true,
  });

  @override
  Widget build(BuildContext context) {
    // Só mostra se estiver autenticado
    return ValueListenableBuilder<AuthState>(
      valueListenable: AuthService.instance.authStateNotifier,
      builder: (context, authState, _) {
        if (authState != AuthState.authenticated) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<SyncState>(
          valueListenable: SyncService.instance.syncStateNotifier,
          builder: (context, syncState, _) {
            return _buildIndicator(context, syncState);
          },
        );
      },
    );
  }

  Widget _buildIndicator(BuildContext context, SyncState state) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon;
    Color color;
    String tooltip;
    bool isAnimating = false;

    switch (state) {
      case SyncState.idle:
        icon = Icons.cloud_done_outlined;
        color = Colors.green;
        tooltip = 'Sincronizado';
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        tooltip = 'Sincronizando...';
        isAnimating = true;
        break;
      case SyncState.error:
        icon = Icons.cloud_off;
        color = Colors.red;
        tooltip = 'Erro na sincronização';
        break;
      case SyncState.offline:
        icon = Icons.cloud_off_outlined;
        color = Colors.grey;
        tooltip = 'Offline';
        break;
    }

    Widget iconWidget = Icon(
      icon,
      size: 20,
      color: isDark ? color.withValues(alpha: 0.9) : color,
    );

    if (isAnimating) {
      iconWidget = _AnimatedSyncIcon(color: color);
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            tooltip,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ],
    );

    if (allowManualSync && state != SyncState.syncing) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => _showSyncMenu(context, state),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: content,
          ),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: content,
      ),
    );
  }

  void _showSyncMenu(BuildContext context, SyncState state) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SyncMenuSheet(state: state),
    );
  }
}

/// Ícone animado de sincronização
class _AnimatedSyncIcon extends StatefulWidget {
  final Color color;

  const _AnimatedSyncIcon({required this.color});

  @override
  State<_AnimatedSyncIcon> createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<_AnimatedSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Icon(
            Icons.sync,
            size: 20,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Menu de opções de sincronização
class _SyncMenuSheet extends StatelessWidget {
  final SyncState state;

  const _SyncMenuSheet({required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Título
            Text(
              'Sincronização',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Status atual
            _buildStatusCard(context),
            const SizedBox(height: 16),

            // Última sincronização
            ValueListenableBuilder<DateTime?>(
              valueListenable: SyncService.instance.lastSyncNotifier,
              builder: (context, lastSync, _) {
                if (lastSync == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Última sincronização: ${_formatDateTime(lastSync)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            // Botão de sincronização
            if (state != SyncState.syncing) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await SyncService.instance.fullSync();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar Agora'),
              ),
              const SizedBox(height: 8),
            ],

            // Registros pendentes
            FutureBuilder<int>(
              future: SyncService.instance.getPendingCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$count registro(s) pendente(s) de sincronização',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    IconData icon;
    Color color;
    String title;
    String description;

    switch (state) {
      case SyncState.idle:
        icon = Icons.cloud_done;
        color = Colors.green;
        title = 'Sincronizado';
        description = 'Todos os dados estão atualizados';
        break;
      case SyncState.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        title = 'Sincronizando';
        description = 'Transferindo dados...';
        break;
      case SyncState.error:
        icon = Icons.error_outline;
        color = Colors.red;
        title = 'Erro';
        description = SyncService.instance.lastErrorNotifier.value ?? 'Erro desconhecido';
        break;
      case SyncState.offline:
        icon = Icons.cloud_off;
        color = Colors.grey;
        title = 'Offline';
        description = 'Sem conexão com a internet';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} minuto(s)';
    } else if (diff.inHours < 24) {
      return 'Há ${diff.inHours} hora(s)';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}
