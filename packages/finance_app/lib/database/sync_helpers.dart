/// Status de sincronização para registros locais
enum SyncStatus {
  /// Registro sincronizado com servidor
  synced(0),

  /// Registro criado localmente, aguardando envio
  pendingCreate(1),

  /// Registro atualizado localmente, aguardando envio
  pendingUpdate(2),

  /// Registro marcado para exclusão, aguardando envio
  pendingDelete(3);

  final int value;

  const SyncStatus(this.value);

  /// Cria SyncStatus a partir do valor do banco
  static SyncStatus fromValue(int? value) {
    switch (value) {
      case 0:
        return SyncStatus.synced;
      case 1:
        return SyncStatus.pendingCreate;
      case 2:
        return SyncStatus.pendingUpdate;
      case 3:
        return SyncStatus.pendingDelete;
      default:
        return SyncStatus.synced;
    }
  }

  /// Verifica se precisa de sincronização
  bool get needsSync => this != SyncStatus.synced;

  /// Nome legível para exibição
  String get displayName {
    switch (this) {
      case SyncStatus.synced:
        return 'Sincronizado';
      case SyncStatus.pendingCreate:
        return 'Aguardando criação';
      case SyncStatus.pendingUpdate:
        return 'Aguardando atualização';
      case SyncStatus.pendingDelete:
        return 'Aguardando exclusão';
    }
  }
}

/// Estados de sincronização do serviço
enum SyncState {
  /// Sem atividade de sincronização
  idle,

  /// Sincronização em progresso
  syncing,

  /// Erro na última sincronização
  error,

  /// Sem conexão com internet
  offline,
}

/// Resultado de uma operação de sincronização
class SyncResult {
  final bool success;
  final int recordsPushed;
  final int recordsPulled;
  final int conflictsResolved;
  final String? error;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    this.recordsPushed = 0,
    this.recordsPulled = 0,
    this.conflictsResolved = 0,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncResult.successful({
    int pushed = 0,
    int pulled = 0,
    int conflicts = 0,
  }) =>
      SyncResult(
        success: true,
        recordsPushed: pushed,
        recordsPulled: pulled,
        conflictsResolved: conflicts,
      );

  factory SyncResult.failed(String error) => SyncResult(
        success: false,
        error: error,
      );

  @override
  String toString() {
    if (success) {
      return 'SyncResult(success: pushed=$recordsPushed, pulled=$recordsPulled, conflicts=$conflictsResolved)';
    }
    return 'SyncResult(failed: $error)';
  }
}

/// Metadados de sincronização para uma tabela
class SyncMetadata {
  final String tableName;
  final DateTime? lastSyncAt;
  final String? lastServerTimestamp;
  final String? userId;

  SyncMetadata({
    required this.tableName,
    this.lastSyncAt,
    this.lastServerTimestamp,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'table_name': tableName,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'last_server_timestamp': lastServerTimestamp,
      'user_id': userId,
    };
  }

  factory SyncMetadata.fromMap(Map<String, dynamic> map) {
    return SyncMetadata(
      tableName: map['table_name'] as String,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.parse(map['last_sync_at'] as String)
          : null,
      lastServerTimestamp: map['last_server_timestamp'] as String?,
      userId: map['user_id'] as String?,
    );
  }
}

/// Representa um conflito de sincronização
class SyncConflict {
  final String tableName;
  final int localId;
  final String? serverId;
  final Map<String, dynamic> localData;
  final Map<String, dynamic> serverData;
  final DateTime localUpdatedAt;
  final DateTime serverUpdatedAt;

  SyncConflict({
    required this.tableName,
    required this.localId,
    this.serverId,
    required this.localData,
    required this.serverData,
    required this.localUpdatedAt,
    required this.serverUpdatedAt,
  });

  /// Em caso de conflito, servidor vence
  Map<String, dynamic> get resolvedData => serverData;
}

/// Lista de tabelas que devem ser sincronizadas
class SyncTables {
  static const List<String> all = [
    'accounts',
    'account_types',
    'account_descriptions',
    'banks',
    'payment_methods',
    'payments',
  ];

  /// Tabelas em ordem de dependência (primeiro as que não têm FK)
  static const List<String> orderedForPush = [
    'account_types',
    'account_descriptions',
    'banks',
    'payment_methods',
    'accounts',
    'payments',
  ];

  /// Tabelas em ordem reversa para pull
  static const List<String> orderedForPull = [
    'payment_methods',
    'account_types',
    'account_descriptions',
    'banks',
    'accounts',
    'payments',
  ];
}
