import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_interface.dart';

/// Configuração do PostgreSQL
class PostgreSQLConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  PostgreSQLConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  String get connectionString =>
      'postgresql://$username:$password@$host:$port/$database';

  String get apiUrl => 'http://$host:8080'; // Assumindo API REST na porta 8080
}

/// Implementação PostgreSQL para operações online
class PostgreSQLImpl implements DatabaseInterface {
  static final PostgreSQLImpl _instance = PostgreSQLImpl._internal();

  late PostgreSQLConfig _config;
  final ValueNotifier<bool> _connectionNotifier = ValueNotifier(false);
  late http.Client _httpClient;

  PostgreSQLImpl._internal();

  factory PostgreSQLImpl() {
    return _instance;
  }

  @override
  ValueNotifier<bool> get connectionNotifier => _connectionNotifier;

  @override
  String get databaseType => 'postgresql';

  /// Configura os dados de conexão
  void configure(PostgreSQLConfig config) {
    _config = config;
    debugPrint('⚙️ PostgreSQL configurado: ${_config.host}:${_config.port}');
  }

  @override
  Future<void> initialize() async {
    try {
      _httpClient = http.Client();
      debugPrint('🌐 Inicializando PostgreSQL em: ${_config.host}');

      // Testar conexão
      final connected = await isConnected();
      _connectionNotifier.value = connected;

      if (connected) {
        debugPrint('✅ PostgreSQL conectado com sucesso');
      } else {
        debugPrint('⚠️ PostgreSQL não está acessível');
      }
    } catch (e) {
      debugPrint('❌ Erro ao inicializar PostgreSQL: $e');
      _connectionNotifier.value = false;
    }
  }

  @override
  Future<void> close() async {
    try {
      _httpClient.close();
      _connectionNotifier.value = false;
      debugPrint('✅ PostgreSQL desconectado');
    } catch (e) {
      debugPrint('❌ Erro ao desconectar PostgreSQL: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      final response = await _makeRequest(
        'query',
        {'sql': sql, 'args': args ?? []},
      );

      final List<dynamic> data = response['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Erro ao fazer query em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> querySingle(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      final results = await query(sql, args: args);
      return results.isEmpty ? null : results.first;
    } catch (e) {
      debugPrint('❌ Erro ao fazer querySingle em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<int> execute(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      final response = await _makeRequest(
        'execute',
        {'sql': sql, 'args': args ?? []},
      );

      return response['rowsAffected'] ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao executar em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<int> insert(
    String table, {
    required Map<String, dynamic> values,
  }) async {
    try {
      final response = await _makeRequest(
        'insert',
        {'table': table, 'values': values},
      );

      return response['id'] ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao inserir em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<int> update(
    String table, {
    required Map<String, dynamic> values,
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final response = await _makeRequest(
        'update',
        {
          'table': table,
          'values': values,
          'where': where,
          'whereArgs': whereArgs ?? [],
        },
      );

      return response['rowsAffected'] ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao atualizar em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final response = await _makeRequest(
        'delete',
        {
          'table': table,
          'where': where,
          'whereArgs': whereArgs ?? [],
        },
      );

      return response['rowsAffected'] ?? 0;
    } catch (e) {
      debugPrint('❌ Erro ao deletar em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    try {
      await _makeRequest('beginTransaction', {});
      try {
        final result = await action();
        await _makeRequest('commit', {});
        return result;
      } catch (e) {
        await _makeRequest('rollback', {});
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Erro ao executar transação em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<dynamic> rawQuery(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      return await query(sql, args: args);
    } catch (e) {
      debugPrint('❌ Erro ao fazer rawQuery em PostgreSQL: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('${_config.apiUrl}/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Faz requisição HTTP para a API PostgreSQL
  Future<Map<String, dynamic>> _makeRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('${_config.apiUrl}/api/$endpoint');
      final response = await _httpClient
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_config.username}:${_config.password}',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Autenticação falhou no PostgreSQL');
      } else {
        throw Exception(
          'Erro na requisição PostgreSQL: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Erro ao fazer requisição PostgreSQL: $e');
      _connectionNotifier.value = false;
      rethrow;
    }
  }
}
