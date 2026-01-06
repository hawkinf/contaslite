import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_interface.dart';
import 'sqlite_impl.dart';
import 'postgresql_impl.dart';

/// Gerenciador de banco de dados que escolhe entre SQLite (offline) e PostgreSQL (online)
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();

  late DatabaseInterface _database;
  late SQLiteImpl _sqlite;
  late PostgreSQLImpl _postgresql;
  late Connectivity _connectivity;

  final ValueNotifier<String> _databaseTypeNotifier = ValueNotifier('sqlite');
  final ValueNotifier<bool> _isOnlineNotifier = ValueNotifier(false);

  DatabaseManager._internal();

  factory DatabaseManager() {
    return _instance;
  }

  /// Getters
  DatabaseInterface get database => _database;
  ValueNotifier<String> get databaseTypeNotifier => _databaseTypeNotifier;
  ValueNotifier<bool> get isOnlineNotifier => _isOnlineNotifier;

  String get currentDatabaseType => _databaseTypeNotifier.value;
  bool get isOnline => _isOnlineNotifier.value;

  /// Inicializa o gerenciador com ambas as implementações
  Future<void> initialize({
    required PostgreSQLConfig postgresConfig,
  }) async {
    try {
      debugPrint('🔄 Inicializando DatabaseManager...');

      // Criar instâncias
      _sqlite = SQLiteImpl();
      _postgresql = PostgreSQLImpl();
      _postgresql.configure(postgresConfig);

      // Inicializar SQLite sempre (offline)
      await _sqlite.initialize();

      // Inicializar PostgreSQL (online)
      await _postgresql.initialize();

      // Definir banco inicial baseado na conectividade
      _connectivity = Connectivity();
      await _checkConnectivity();

      // Monitorar mudanças de conectividade
      _connectivity.onConnectivityChanged.listen((result) {
        _handleConnectivityChange(result);
      });

      debugPrint('✅ DatabaseManager inicializado com sucesso');
      debugPrint('📊 Banco atual: ${_databaseTypeNotifier.value}');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar DatabaseManager: $e');
      // Fallback para SQLite em caso de erro
      _database = _sqlite;
      _databaseTypeNotifier.value = 'sqlite';
      _isOnlineNotifier.value = false;
    }
  }

  /// Verifica conectividade e muda de banco se necessário
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final hasInternet = connectivityResult != ConnectivityResult.none;

      if (hasInternet) {
        // Tentar conectar ao PostgreSQL
        final isPostgresOnline = await _postgresql.isConnected();
        if (isPostgresOnline) {
          _switchToPostgreSQL();
        } else {
          _switchToSQLite();
        }
      } else {
        _switchToSQLite();
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar conectividade: $e');
      _switchToSQLite();
    }
  }

  /// Gerencia mudanças de conectividade
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    debugPrint('🔌 Mudança de conectividade: $result');

    if (result == ConnectivityResult.none) {
      // Sem internet
      _switchToSQLite();
    } else {
      // Com internet, tentar PostgreSQL
      final isOnline = await _postgresql.isConnected();
      if (isOnline) {
        _switchToPostgreSQL();
      } else {
        _switchToSQLite();
      }
    }
  }

  /// Muda para SQLite
  void _switchToSQLite() {
    if (_databaseTypeNotifier.value == 'sqlite') return;

    debugPrint('📱 Alternando para SQLite (offline)');
    _database = _sqlite;
    _databaseTypeNotifier.value = 'sqlite';
    _isOnlineNotifier.value = false;
  }

  /// Muda para PostgreSQL
  void _switchToPostgreSQL() {
    if (_databaseTypeNotifier.value == 'postgresql') return;

    debugPrint('🌐 Alternando para PostgreSQL (online)');
    _database = _postgresql;
    _databaseTypeNotifier.value = 'postgresql';
    _isOnlineNotifier.value = true;
  }

  /// Sincroniza dados entre SQLite e PostgreSQL
  /// (Implementação futura baseada em sua lógica de negócio)
  Future<void> syncData() async {
    try {
      if (!isOnline) {
        debugPrint('⚠️ Sem conexão de internet - sincronização não é possível');
        return;
      }

      debugPrint('🔄 Iniciando sincronização de dados...');

      // TODO: Implementar lógica de sincronização
      // 1. Buscar dados modificados localmente no SQLite
      // 2. Enviar para PostgreSQL
      // 3. Buscar dados novos do PostgreSQL
      // 4. Atualizar SQLite localmente

      debugPrint('✅ Sincronização concluída');
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar dados: $e');
    }
  }

  /// Força reconexão ao PostgreSQL
  Future<void> reconnectPostgres() async {
    try {
      debugPrint('🔄 Reconectando ao PostgreSQL...');
      await _postgresql.close();
      await _postgresql.initialize();

      final isOnline = await _postgresql.isConnected();
      if (isOnline) {
        _switchToPostgreSQL();
        debugPrint('✅ Reconectado ao PostgreSQL');
      } else {
        _switchToSQLite();
        debugPrint('⚠️ PostgreSQL indisponível - usando SQLite');
      }
    } catch (e) {
      debugPrint('❌ Erro ao reconectar: $e');
      _switchToSQLite();
    }
  }

  /// Fecha ambas as conexões
  Future<void> close() async {
    try {
      await _sqlite.close();
      await _postgresql.close();
      debugPrint('✅ DatabaseManager fechado');
    } catch (e) {
      debugPrint('❌ Erro ao fechar DatabaseManager: $e');
    }
  }
}
