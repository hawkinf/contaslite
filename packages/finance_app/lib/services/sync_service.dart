import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/db_helper.dart';
import '../database/sync_helpers.dart';
import 'auth_service.dart';
import 'prefs_service.dart';

/// Serviço de sincronização bidirecional com o servidor PostgreSQL
class SyncService {
  static final SyncService instance = SyncService._();

  SyncService._();

  /// Notificador do estado de sincronização
  final ValueNotifier<SyncState> syncStateNotifier = ValueNotifier(SyncState.idle);

  /// Notificador do progresso de sincronização (0.0 a 1.0)
  final ValueNotifier<double> syncProgressNotifier = ValueNotifier(0.0);

  /// Notificador do último erro
  final ValueNotifier<String?> lastErrorNotifier = ValueNotifier(null);

  /// Notificador da última sincronização bem sucedida
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  Timer? _backgroundSyncTimer;
  http.Client? _httpClient;
  String? _apiBaseUrl;
  bool _isSyncing = false;

  final _db = DatabaseHelper.instance;

  /// Inicializa o serviço de sincronização
  Future<void> initialize() async {
    _httpClient = http.Client();

    // Carregar URL da API das configurações
    final config = await PrefsService.loadDatabaseConfig();
    if (config.enabled && config.host.isNotEmpty) {
      _apiBaseUrl = config.apiUrl ?? 'http://${config.host}:8080';
    }

    // Verificar conectividade inicial
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      syncStateNotifier.value = SyncState.offline;
    }

    // Escutar mudanças de conectividade
    Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  /// Configura a URL da API manualmente
  void setApiUrl(String url) {
    _apiBaseUrl = url;
  }

  /// Inicia sincronização em background
  void startBackgroundSync({Duration interval = const Duration(minutes: 5)}) {
    stopBackgroundSync();

    _backgroundSyncTimer = Timer.periodic(interval, (_) async {
      if (!AuthService.instance.isAuthenticated) return;
      if (_isSyncing) return;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        syncStateNotifier.value = SyncState.offline;
        return;
      }

      await incrementalSync();
    });

    debugPrint('⏰ Sync em background iniciado (intervalo: ${interval.inMinutes} min)');
  }

  /// Para sincronização em background
  void stopBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
  }

  /// Executa sincronização completa (pull + push)
  Future<SyncResult> fullSync() async {
    if (!_canSync()) {
      return SyncResult.failed('Não é possível sincronizar no momento');
    }

    _isSyncing = true;
    syncStateNotifier.value = SyncState.syncing;
    syncProgressNotifier.value = 0.0;
    lastErrorNotifier.value = null;

    int totalPushed = 0;
    int totalPulled = 0;
    int totalConflicts = 0;

    try {
      // 1. Push local changes first
      debugPrint('🔄 Iniciando push de mudanças locais...');
      syncProgressNotifier.value = 0.1;
      final pushResult = await _pushChanges();
      totalPushed = pushResult.recordsPushed;
      totalConflicts = pushResult.conflictsResolved;

      // 2. Pull server changes
      debugPrint('🔄 Iniciando pull de mudanças do servidor...');
      syncProgressNotifier.value = 0.5;
      final pullResult = await _pullChanges();
      totalPulled = pullResult.recordsPulled;

      // 3. Cleanup deleted records
      debugPrint('🔄 Limpando registros deletados...');
      syncProgressNotifier.value = 0.9;
      await _cleanupDeleted();

      syncProgressNotifier.value = 1.0;
      syncStateNotifier.value = SyncState.idle;
      lastSyncNotifier.value = DateTime.now();

      final result = SyncResult.successful(
        pushed: totalPushed,
        pulled: totalPulled,
        conflicts: totalConflicts,
      );

      debugPrint('✅ Sync completo: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Erro no sync: $e');
      syncStateNotifier.value = SyncState.error;
      lastErrorNotifier.value = e.toString();
      return SyncResult.failed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Executa sincronização incremental (apenas mudanças desde último sync)
  Future<SyncResult> incrementalSync() async {
    if (!_canSync()) {
      return SyncResult.failed('Não é possível sincronizar no momento');
    }

    _isSyncing = true;
    syncStateNotifier.value = SyncState.syncing;

    try {
      // Push pending changes
      final pushResult = await _pushChanges();

      // Pull changes since last sync
      final pullResult = await _pullChanges(incremental: true);

      syncStateNotifier.value = SyncState.idle;
      lastSyncNotifier.value = DateTime.now();

      return SyncResult.successful(
        pushed: pushResult.recordsPushed,
        pulled: pullResult.recordsPulled,
        conflicts: pushResult.conflictsResolved,
      );
    } catch (e) {
      debugPrint('❌ Erro no sync incremental: $e');
      syncStateNotifier.value = SyncState.error;
      lastErrorNotifier.value = e.toString();
      return SyncResult.failed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Força push de mudanças pendentes
  Future<SyncResult> pushPendingChanges() async {
    if (!_canSync()) {
      return SyncResult.failed('Não é possível sincronizar no momento');
    }

    _isSyncing = true;
    syncStateNotifier.value = SyncState.syncing;

    try {
      final result = await _pushChanges();
      syncStateNotifier.value = SyncState.idle;
      return result;
    } catch (e) {
      syncStateNotifier.value = SyncState.error;
      lastErrorNotifier.value = e.toString();
      return SyncResult.failed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Força pull de mudanças do servidor
  Future<SyncResult> pullServerChanges() async {
    if (!_canSync()) {
      return SyncResult.failed('Não é possível sincronizar no momento');
    }

    _isSyncing = true;
    syncStateNotifier.value = SyncState.syncing;

    try {
      final result = await _pullChanges();
      syncStateNotifier.value = SyncState.idle;
      lastSyncNotifier.value = DateTime.now();
      return result;
    } catch (e) {
      syncStateNotifier.value = SyncState.error;
      lastErrorNotifier.value = e.toString();
      return SyncResult.failed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Verifica se pode sincronizar
  bool _canSync() {
    if (_isSyncing) {
      debugPrint('⚠️ Sync já em progresso');
      return false;
    }
    if (_apiBaseUrl == null) {
      debugPrint('⚠️ API não configurada');
      return false;
    }
    if (!AuthService.instance.isAuthenticated) {
      debugPrint('⚠️ Usuário não autenticado');
      return false;
    }
    return true;
  }

  /// Push de mudanças locais para o servidor
  Future<SyncResult> _pushChanges() async {
    int totalPushed = 0;
    int totalConflicts = 0;

    for (final table in SyncTables.orderedForPush) {
      try {
        // Buscar registros pendentes
        final creates = await _db.getPendingCreates(table);
        final updates = await _db.getPendingUpdates(table);
        final deletes = await _db.getPendingDeletes(table);

        if (creates.isEmpty && updates.isEmpty && deletes.isEmpty) {
          continue;
        }

        debugPrint('📤 Push $table: ${creates.length} creates, ${updates.length} updates, ${deletes.length} deletes');

        // Enviar para o servidor
        final response = await _httpClient!
            .post(
              Uri.parse('$_apiBaseUrl/api/sync/push'),
              headers: AuthService.instance.getAuthHeaders(),
              body: jsonEncode({
                'table': table,
                'creates': creates,
                'updates': updates,
                'deletes': deletes.map((d) => d['server_id']).where((id) => id != null).toList(),
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          // Processar registros criados (receber server_id)
          final created = data['created'] as List<dynamic>? ?? [];
          for (final item in created) {
            final localId = item['local_id'] as int?;
            final serverId = item['server_id'] as String?;
            if (localId != null && serverId != null) {
              await _db.markAsSynced(table, localId, serverId);
              totalPushed++;
            }
          }

          // Processar registros atualizados
          final updated = data['updated'] as List<dynamic>? ?? [];
          for (final item in updated) {
            final localId = item['local_id'] as int?;
            final serverId = item['server_id'] as String?;
            if (localId != null && serverId != null) {
              await _db.markAsSynced(table, localId, serverId);
              totalPushed++;
            }
          }

          // Processar conflitos (server wins)
          final conflicts = data['conflicts'] as List<dynamic>? ?? [];
          for (final conflict in conflicts) {
            final serverData = conflict['server_data'] as Map<String, dynamic>?;
            if (serverData != null) {
              await _db.applyServerData(table, serverData);
              totalConflicts++;
            }
          }

          // Remover registros deletados localmente após confirmação
          if (deletes.isNotEmpty) {
            await _db.purgePendingDeletes(table);
          }
        } else if (response.statusCode == 401) {
          // Token expirado, tentar refresh
          final refreshed = await AuthService.instance.refreshToken();
          if (!refreshed) {
            throw Exception('Sessão expirada. Faça login novamente.');
          }
          // Retry
          return _pushChanges();
        } else {
          debugPrint('❌ Erro no push de $table: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Erro ao fazer push de $table: $e');
        // Continua com próxima tabela
      }
    }

    return SyncResult.successful(pushed: totalPushed, conflicts: totalConflicts);
  }

  /// Pull de mudanças do servidor
  Future<SyncResult> _pullChanges({bool incremental = false}) async {
    int totalPulled = 0;

    for (final table in SyncTables.orderedForPull) {
      try {
        // Buscar último timestamp de sync
        String? since;
        if (incremental) {
          final metadata = await _db.getSyncMetadata(table);
          since = metadata?.lastServerTimestamp;
        }

        final uri = Uri.parse('$_apiBaseUrl/api/sync/pull').replace(
          queryParameters: {
            'table': table,
            if (since != null) 'since': since,
          },
        );

        final response = await _httpClient!
            .get(uri, headers: AuthService.instance.getAuthHeaders())
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final records = data['records'] as List<dynamic>? ?? [];
          final serverTimestamp = data['server_timestamp'] as String?;
          final deleted = data['deleted'] as List<dynamic>? ?? [];

          // Aplicar registros do servidor (server wins)
          for (final record in records) {
            await _db.applyServerData(table, record as Map<String, dynamic>);
            totalPulled++;
          }

          // Deletar registros que foram deletados no servidor
          for (final serverId in deleted) {
            if (serverId is String) {
              await _db.deleteByServerId(table, serverId);
            }
          }

          // Atualizar metadata de sync
          if (serverTimestamp != null) {
            await _db.updateSyncMetadata(
              table,
              serverTimestamp,
              userId: AuthService.instance.currentUser?.id,
            );
          }

          debugPrint('📥 Pull $table: ${records.length} registros, ${deleted.length} deletados');
        } else if (response.statusCode == 401) {
          final refreshed = await AuthService.instance.refreshToken();
          if (!refreshed) {
            throw Exception('Sessão expirada. Faça login novamente.');
          }
          return _pullChanges(incremental: incremental);
        } else {
          debugPrint('❌ Erro no pull de $table: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Erro ao fazer pull de $table: $e');
      }
    }

    return SyncResult.successful(pulled: totalPulled);
  }

  /// Limpa registros marcados para exclusão
  Future<void> _cleanupDeleted() async {
    for (final table in SyncTables.all) {
      try {
        await _db.purgePendingDeletes(table);
      } catch (e) {
        debugPrint('⚠️ Erro ao limpar deletes de $table: $e');
      }
    }
  }

  /// Lida com mudanças de conectividade
  void _handleConnectivityChange(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      syncStateNotifier.value = SyncState.offline;
      debugPrint('📴 Offline - sync pausado');
    } else {
      if (syncStateNotifier.value == SyncState.offline) {
        syncStateNotifier.value = SyncState.idle;
        debugPrint('📶 Online - sync disponível');

        // Auto-sync ao reconectar
        if (AuthService.instance.isAuthenticated) {
          incrementalSync();
        }
      }
    }
  }

  /// Retorna quantidade de registros pendentes de sync
  Future<int> getPendingCount() async {
    return await _db.countPendingSync();
  }

  /// Reseta todos os dados de sync (usado no logout)
  Future<void> resetSync() async {
    stopBackgroundSync();
    await _db.resetAllSyncStatus();
    syncStateNotifier.value = SyncState.idle;
    syncProgressNotifier.value = 0.0;
    lastErrorNotifier.value = null;
    lastSyncNotifier.value = null;
    debugPrint('🔄 Sync resetado');
  }

  /// Libera recursos
  void dispose() {
    stopBackgroundSync();
    _httpClient?.close();
  }
}
