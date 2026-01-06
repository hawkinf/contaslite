import 'package:flutter/foundation.dart';

/// Interface abstrata para operações de banco de dados
/// Permite usar SQLite (offline) ou PostgreSQL (online)
abstract class DatabaseInterface {
  /// Inicializa a conexão com o banco de dados
  Future<void> initialize();

  /// Fecha a conexão com o banco de dados
  Future<void> close();

  /// Executa um SELECT e retorna lista de mapas
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? args,
  });

  /// Executa um SELECT e retorna um único resultado
  Future<Map<String, dynamic>?> querySingle(
    String sql, {
    List<dynamic>? args,
  });

  /// Executa INSERT, UPDATE ou DELETE
  Future<int> execute(
    String sql, {
    List<dynamic>? args,
  });

  /// Executa INSERT e retorna o ID inserido
  Future<int> insert(
    String table, {
    required Map<String, dynamic> values,
  });

  /// Executa UPDATE
  Future<int> update(
    String table, {
    required Map<String, dynamic> values,
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Executa DELETE
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  });

  /// Executa múltiplas operações em uma transação
  Future<T> transaction<T>(Future<T> Function() action);

  /// Executa uma função raw SQL
  Future<dynamic> rawQuery(
    String sql, {
    List<dynamic>? args,
  });

  /// Verifica se está conectado ao servidor
  Future<bool> isConnected();

  /// Obtém tipo do banco atualmente em uso
  String get databaseType; // 'sqlite' ou 'postgresql'

  /// Listener para mudanças de conexão
  ValueNotifier<bool> get connectionNotifier;
}
