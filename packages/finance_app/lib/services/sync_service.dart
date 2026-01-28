import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../database/db_helper.dart';
import '../database/sync_helpers.dart';
import '../widgets/sync_conflict_dialog.dart';
import 'auth_service.dart';
import 'prefs_service.dart';

/// Callback para resolver conflitos - retorna resultado da escolha do usuário
typedef ConflictResolver = Future<ConflictResolutionResult> Function(List<ConflictItem> conflicts);

/// Modo de resolução de conflitos
enum ConflictResolutionMode {
  /// Servidor sempre vence (comportamento padrão)
  serverWins,

  /// Local sempre vence
  localWins,

  /// Perguntar ao usuário
  askUser,
}

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

  /// Modo de resolução de conflitos (padrão: servidor vence)
  ConflictResolutionMode conflictMode = ConflictResolutionMode.serverWins;

  /// Callback para resolver conflitos quando modo é askUser
  ConflictResolver? onConflictsDetected;

  /// Conflitos coletados durante a última sincronização
  final List<ConflictItem> _pendingConflicts = [];

  /// Inicializa o serviço de sincronização
  Future<void> initialize() async {
    _httpClient = http.Client();

    // Carregar URL da API das configurações
    final config = await PrefsService.loadDatabaseConfig();
    
    // Priorizar apiUrl se estiver configurada
    if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
      _apiBaseUrl = config.apiUrl;
    } else if (config.enabled && config.host.isNotEmpty) {
      _apiBaseUrl = 'http://${config.host}:3000';
    } else {
      // URL padrão se nada estiver configurado
      _apiBaseUrl = 'http://192.227.184.162:3000';
    }

    debugPrint('🔧 SyncService inicializado com URL: $_apiBaseUrl');

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

  /// Força reavaliação de conectividade e tenta voltar ao estado online
  Future<bool> forceConnectivityCheck({bool triggerSync = true}) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      syncStateNotifier.value = SyncState.offline;
      debugPrint('📴 Force check: ainda offline');
      return false;
    }

    // Temos conexão: voltar para idle e, opcionalmente, sincronizar
    syncStateNotifier.value = SyncState.idle;
    debugPrint('📶 Force check: conexão detectada, estado idle');

    if (triggerSync && AuthService.instance.isAuthenticated) {
      // Não bloquear caller; best-effort
      unawaited(incrementalSync());
    }

    return true;
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
  /// IMPORTANTE: Em instalações novas (sem dados sincronizados), faz PULL primeiro
  /// para evitar sobrescrever dados do servidor com dados locais padrão.
  Future<SyncResult> fullSync() async {
    // Recarregar URL da API se não estiver configurada
    if (_apiBaseUrl == null) {
      final config = await PrefsService.loadDatabaseConfig();
      if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
        _apiBaseUrl = config.apiUrl;
        debugPrint('🔧 SyncService: URL recarregada: $_apiBaseUrl');
      }
    }

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
      // Verificar se é uma instalação nova (nunca sincronizou antes)
      final isFirstSync = await _isFirstSync();
      debugPrint('🔄 É primeira sincronização: $isFirstSync');

      if (isFirstSync) {
        // INSTALAÇÃO NOVA: Pull primeiro, depois push
        // Isso evita que dados padrão locais sobrescrevam dados do servidor

        // 1. Pull server changes FIRST
        debugPrint('🔄 [NOVA INSTALAÇÃO] Iniciando pull de dados do servidor...');
        syncProgressNotifier.value = 0.1;
        final pullResult = await _pullChanges();
        totalPulled = pullResult.recordsPulled;

        // 2. Limpar registros locais que são apenas "padrão" e já existem no servidor
        debugPrint('🔄 [NOVA INSTALAÇÃO] Limpando duplicatas locais...');
        syncProgressNotifier.value = 0.5;
        await _cleanupLocalDefaultsAfterPull();

        // 3. Push apenas registros realmente novos (não os padrões)
        debugPrint('🔄 [NOVA INSTALAÇÃO] Enviando apenas dados novos...');
        syncProgressNotifier.value = 0.7;
        final pushResult = await _pushChanges();
        totalPushed = pushResult.recordsPushed;
        totalConflicts = pushResult.conflictsResolved;
      } else {
        // INSTALAÇÃO EXISTENTE: Push primeiro, depois pull (comportamento normal)

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
      }

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

  /// Verifica se é a primeira sincronização (nenhum registro tem server_id)
  Future<bool> _isFirstSync() async {
    try {
      // Verificar se existe algum registro com server_id em qualquer tabela
      for (final table in SyncTables.all) {
        final count = await _db.countSyncedRecords(table);
        if (count > 0) {
          return false; // Já sincronizou antes
        }
      }
      return true; // Nenhum registro sincronizado = primeira vez
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar primeira sync: $e');
      return false; // Em caso de erro, assume que não é primeira vez (mais seguro)
    }
  }

  /// Limpa registros locais "padrão" que são duplicatas após o primeiro pull
  /// Isso evita enviar dados duplicados ao servidor
  Future<void> _cleanupLocalDefaultsAfterPull() async {
    try {
      // Marcar registros locais sem server_id como "synced" se já existe
      // um registro equivalente vindo do servidor
      await _db.markLocalDefaultsAsSyncedIfDuplicate();
    } catch (e) {
      debugPrint('⚠️ Erro ao limpar duplicatas locais: $e');
    }
  }

  /// Executa sincronização incremental (apenas mudanças desde último sync)
  Future<SyncResult> incrementalSync() async {
    // Recarregar URL da API se não estiver configurada
    if (_apiBaseUrl == null) {
      final config = await PrefsService.loadDatabaseConfig();
      if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
        _apiBaseUrl = config.apiUrl;
        debugPrint('🔧 SyncService: URL recarregada: $_apiBaseUrl');
      }
    }
    
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

  /// Push de accounts em duas fases para garantir que cartões sejam sincronizados antes das despesas
  Future<SyncResult> _pushAccountsInTwoPhases() async {
    int totalPushed = 0;
    int totalConflicts = 0;
    const table = 'accounts';

    // Buscar todos os registros pendentes
    final rawCreates = await _db.getPendingCreates(table);
    final rawUpdates = await _db.getPendingUpdates(table);
    final deletes = await _db.getPendingDeletes(table);

    if (rawCreates.isEmpty && rawUpdates.isEmpty && deletes.isEmpty) {
      return SyncResult.successful();
    }

    // Separar cartões (cardBrand != null, cardId == null) das despesas de cartão (cardId != null)
    final cardCreates = rawCreates.where((r) => r['cardBrand'] != null && r['cardId'] == null).toList();
    final cardUpdates = rawUpdates.where((r) => r['cardBrand'] != null && r['cardId'] == null).toList();

    final cardExpenseCreates = rawCreates.where((r) => r['cardId'] != null).toList();
    final cardExpenseUpdates = rawUpdates.where((r) => r['cardId'] != null).toList();

    // Contas normais (sem cardBrand e sem cardId)
    final normalCreates = rawCreates.where((r) => r['cardBrand'] == null && r['cardId'] == null).toList();
    final normalUpdates = rawUpdates.where((r) => r['cardBrand'] == null && r['cardId'] == null).toList();

    // FASE 1: Sincronizar cartões e contas normais (não dependem de cardId)
    final phase1Creates = [...cardCreates, ...normalCreates];
    final phase1Updates = [...cardUpdates, ...normalUpdates];

    if (phase1Creates.isNotEmpty || phase1Updates.isNotEmpty || deletes.isNotEmpty) {
      // Resolver referências FK (typeId, categoryId)
      final resolvedCreates = await Future.wait(
        phase1Creates.map((r) => _db.resolveAccountReferences(r)),
      );
      final resolvedUpdates = await Future.wait(
        phase1Updates.map((r) => _db.resolveAccountReferences(r)),
      );

      debugPrint('📤 Push accounts (Fase 1 - cartões e normais): ${resolvedCreates.length} creates, ${resolvedUpdates.length} updates, ${deletes.length} deletes');

      final result1 = await _pushTableData(
        table: table,
        creates: resolvedCreates,
        updates: resolvedUpdates,
        deletes: deletes,
      );
      totalPushed += result1.recordsPushed;
      totalConflicts += result1.conflictsResolved;
    }

    // FASE 2: Sincronizar despesas de cartão (agora os cartões já têm server_id)
    if (cardExpenseCreates.isNotEmpty || cardExpenseUpdates.isNotEmpty) {
      // Resolver referências FK incluindo cardId agora que cartões foram sincronizados
      final resolvedCreates = await Future.wait(
        cardExpenseCreates.map((r) => _db.resolveAccountReferences(r)),
      );
      final resolvedUpdates = await Future.wait(
        cardExpenseUpdates.map((r) => _db.resolveAccountReferences(r)),
      );

      debugPrint('📤 Push accounts (Fase 2 - despesas cartão): ${resolvedCreates.length} creates, ${resolvedUpdates.length} updates');

      final result2 = await _pushTableData(
        table: table,
        creates: resolvedCreates,
        updates: resolvedUpdates,
        deletes: [], // Deletes já foram enviados na fase 1
      );
      totalPushed += result2.recordsPushed;
      totalConflicts += result2.conflictsResolved;
    }

    return SyncResult.successful(pushed: totalPushed, conflicts: totalConflicts);
  }

  /// Helper para enviar dados de uma tabela ao servidor
  Future<SyncResult> _pushTableData({
    required String table,
    required List<Map<String, dynamic>> creates,
    required List<Map<String, dynamic>> updates,
    required List<Map<String, dynamic>> deletes,
  }) async {
    int totalPushed = 0;
    int totalConflicts = 0;

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

      // Processar conflitos
      final conflicts = data['conflicts'] as List<dynamic>? ?? [];
      for (final conflict in conflicts) {
        final serverData = conflict['server_data'] as Map<String, dynamic>?;
        final localId = conflict['local_id'] as int?;
        final serverId = conflict['server_id'] as String?;

        if (serverData != null && localId != null) {
          // Buscar dados locais para comparação
          final localData = await _db.getRecordById(table, localId);

          if (conflictMode == ConflictResolutionMode.askUser) {
            // Coletar conflito para perguntar ao usuário
            _pendingConflicts.add(ConflictItem(
              tableName: table,
              localId: localId,
              serverId: serverId,
              localData: localData ?? {},
              serverData: serverData,
              localUpdatedAt: localData?['updated_at'] != null
                  ? DateTime.tryParse(localData!['updated_at'].toString())
                  : null,
              serverUpdatedAt: serverData['updated_at'] != null
                  ? DateTime.tryParse(serverData['updated_at'].toString())
                  : null,
            ));
          } else if (conflictMode == ConflictResolutionMode.localWins) {
            // Local vence - forçar push do local (será tratado na próxima sync)
            debugPrint('⚡ Conflito em $table: local vence (local_id=$localId)');
          } else {
            // Server wins (padrão)
            await _db.applyServerData(table, serverData);
          }
          totalConflicts++;
        }
      }

      // Remover registros deletados localmente após confirmação
      if (deletes.isNotEmpty) {
        await _db.purgePendingDeletes(table);
      }
    } else if (response.statusCode == 401) {
      // Token expirado - não fazer retry aqui, deixar para _pushChanges principal
      throw Exception('Token expirado');
    } else {
      debugPrint('❌ Erro no push de $table: ${response.statusCode}');
    }

    return SyncResult.successful(pushed: totalPushed, conflicts: totalConflicts);
  }

  /// Push de mudanças locais para o servidor
  Future<SyncResult> _pushChanges() async {
    int totalPushed = 0;
    int totalConflicts = 0;

    for (final table in SyncTables.orderedForPush) {
      try {
        // Para accounts, sincronizar em duas fases:
        // Fase 1: Cartões de crédito (cardBrand != null) - não têm cardId
        // Fase 2: Despesas de cartão (cardId != null) - dependem dos cartões
        if (table == 'accounts') {
          final result = await _pushAccountsInTwoPhases();
          totalPushed += result.recordsPushed;
          totalConflicts += result.conflictsResolved;
          continue;
        }

        // Buscar registros pendentes
        final rawCreates = await _db.getPendingCreates(table);
        final rawUpdates = await _db.getPendingUpdates(table);
        final deletes = await _db.getPendingDeletes(table);

        if (rawCreates.isEmpty && rawUpdates.isEmpty && deletes.isEmpty) {
          continue;
        }

        // Resolver referências FK para server_id antes de enviar
        List<Map<String, dynamic>> creates;
        List<Map<String, dynamic>> updates;

        if (table == 'account_descriptions') {
          // Resolver accountId para server_id do account_type
          creates = await Future.wait(
            rawCreates.map((r) => _db.resolveAccountDescriptionReferences(r)),
          );
          updates = await Future.wait(
            rawUpdates.map((r) => _db.resolveAccountDescriptionReferences(r)),
          );
        } else if (table == 'payments') {
          // Resolver accountId para server_id da conta
          creates = await Future.wait(
            rawCreates.map((r) => _db.resolvePaymentReferences(r)),
          );
          updates = await Future.wait(
            rawUpdates.map((r) => _db.resolvePaymentReferences(r)),
          );
        } else {
          creates = rawCreates;
          updates = rawUpdates;
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

          // Processar conflitos
          final conflicts = data['conflicts'] as List<dynamic>? ?? [];
          for (final conflict in conflicts) {
            final serverData = conflict['server_data'] as Map<String, dynamic>?;
            final localId = conflict['local_id'] as int?;
            final serverId = conflict['server_id'] as String?;

            if (serverData != null && localId != null) {
              final localData = await _db.getRecordById(table, localId);

              if (conflictMode == ConflictResolutionMode.askUser) {
                _pendingConflicts.add(ConflictItem(
                  tableName: table,
                  localId: localId,
                  serverId: serverId,
                  localData: localData ?? {},
                  serverData: serverData,
                  localUpdatedAt: localData?['updated_at'] != null
                      ? DateTime.tryParse(localData!['updated_at'].toString())
                      : null,
                  serverUpdatedAt: serverData['updated_at'] != null
                      ? DateTime.tryParse(serverData['updated_at'].toString())
                      : null,
                ));
              } else if (conflictMode == ConflictResolutionMode.localWins) {
                debugPrint('⚡ Conflito em $table: local vence (local_id=$localId)');
              } else {
                await _db.applyServerData(table, serverData);
              }
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

  /// Retorna o status da sincronização
  Future<Map<String, dynamic>> getSyncStatus() async {
    final pendingCount = await getPendingCount();
    final lastSync = lastSyncNotifier.value;
    final isEnabled = _apiBaseUrl != null && _apiBaseUrl!.isNotEmpty;
    
    // Estatísticas fictícias por enquanto (pode ser implementado com contadores reais)
    return {
      'lastSync': lastSync != null 
          ? '${lastSync.day}/${lastSync.month}/${lastSync.year} às ${lastSync.hour}:${lastSync.minute.toString().padLeft(2, '0')}'
          : 'Nunca',
      'pendingCount': pendingCount,
      'pushedCount': 0, // Contador será implementado na próxima versão
      'pulledCount': 0, // Contador será implementado na próxima versão
      'syncEnabled': isEnabled,
      'syncState': syncStateNotifier.value.toString(),
    };
  }

  /// Reseta todos os dados de sync (usado no logout)
  Future<void> resetSync() async {
    stopBackgroundSync();
    await _db.resetAllSyncStatus();
    syncStateNotifier.value = SyncState.offline;
    syncProgressNotifier.value = 0.0;
    lastErrorNotifier.value = null;
    lastSyncNotifier.value = null;
    _pendingConflicts.clear();
    debugPrint('🔄 Sync resetado');
  }

  // ============================================================
  // Métodos para resolução de conflitos pelo usuário
  // ============================================================

  /// Retorna se existem conflitos pendentes para resolver
  bool get hasConflicts => _pendingConflicts.isNotEmpty;

  /// Retorna lista de conflitos pendentes (cópia)
  List<ConflictItem> get pendingConflicts => List.from(_pendingConflicts);

  /// Limpa a lista de conflitos pendentes
  void clearConflicts() {
    _pendingConflicts.clear();
  }

  /// Aplica as escolhas do usuário para os conflitos
  Future<void> applyConflictResolutions(ConflictResolutionResult result) async {
    if (result.cancelled) {
      debugPrint('⚠️ Resolução de conflitos cancelada pelo usuário');
      _pendingConflicts.clear();
      return;
    }

    // Aplicar escolhas do servidor (sobrescrever local com dados do servidor)
    for (final conflict in result.useServer) {
      try {
        await _db.applyServerData(conflict.tableName, conflict.serverData);
        debugPrint('✅ Aplicado servidor para ${conflict.tableName} (id: ${conflict.localId})');
      } catch (e) {
        debugPrint('❌ Erro ao aplicar dados do servidor: $e');
      }
    }

    // Aplicar escolhas locais (marcar para re-push na próxima sync)
    for (final conflict in result.useLocal) {
      try {
        // Forçar re-push marcando como pendingUpdate
        await _db.markForResync(conflict.tableName, conflict.localId);
        debugPrint('✅ Marcado para reenvio: ${conflict.tableName} (id: ${conflict.localId})');
      } catch (e) {
        debugPrint('❌ Erro ao marcar para reenvio: $e');
      }
    }

    _pendingConflicts.clear();
    debugPrint('✅ Resolução de conflitos aplicada: ${result.useLocal.length} local, ${result.useServer.length} servidor');
  }

  /// Sincronização completa com resolução de conflitos pelo usuário
  /// Esta versão permite que um callback seja chamado quando conflitos são detectados
  Future<SyncResult> fullSyncWithUserResolution({
    required ConflictResolver conflictResolver,
  }) async {
    // Temporariamente mudar para modo askUser
    final previousMode = conflictMode;
    conflictMode = ConflictResolutionMode.askUser;
    _pendingConflicts.clear();

    try {
      // Executar sincronização normal
      final result = await fullSync();

      // Se houver conflitos, perguntar ao usuário
      if (_pendingConflicts.isNotEmpty) {
        debugPrint('🔄 ${_pendingConflicts.length} conflitos detectados, aguardando resolução...');

        final resolution = await conflictResolver(_pendingConflicts);
        await applyConflictResolutions(resolution);

        // Se não cancelou, fazer sync incremental para garantir que tudo está atualizado
        if (!resolution.cancelled) {
          await incrementalSync();
        }
      }

      return result;
    } finally {
      conflictMode = previousMode;
    }
  }

  /// Libera recursos
  void dispose() {
    stopBackgroundSync();
    _httpClient?.close();
  }
}
