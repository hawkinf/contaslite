import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_interface.dart';

/// Implementação SQLite para operações offline
class SQLiteImpl implements DatabaseInterface {
  static final SQLiteImpl _instance = SQLiteImpl._internal();

  Database? _database;
  final ValueNotifier<bool> _connectionNotifier = ValueNotifier(true);

  SQLiteImpl._internal();

  factory SQLiteImpl() {
    return _instance;
  }

  @override
  ValueNotifier<bool> get connectionNotifier => _connectionNotifier;

  @override
  String get databaseType => 'sqlite';

  @override
  Future<void> initialize() async {
    try {
      final dbPath = await getDatabasesPath();
      final filePath = join(dbPath, 'finance_v62.db');

      debugPrint('📱 Inicializando SQLite em: $filePath');

      _database = await openDatabase(
        filePath,
        version: 11,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      _connectionNotifier.value = true;
      debugPrint('✅ SQLite inicializado com sucesso');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar SQLite: $e');
      _connectionNotifier.value = false;
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    try {
      await _database?.close();
      _database = null;
      _connectionNotifier.value = false;
      debugPrint('✅ SQLite fechado');
    } catch (e) {
      debugPrint('❌ Erro ao fechar SQLite: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      final results = await _database!.rawQuery(sql, args);
      return results;
    } catch (e) {
      debugPrint('❌ Erro ao fazer query em SQLite: $e');
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
      debugPrint('❌ Erro ao fazer querySingle em SQLite: $e');
      rethrow;
    }
  }

  @override
  Future<int> execute(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      await _database!.execute(sql, args);
      return 1;
    } catch (e) {
      debugPrint('❌ Erro ao executar em SQLite: $e');
      rethrow;
    }
  }

  @override
  Future<int> insert(
    String table, {
    required Map<String, dynamic> values,
  }) async {
    try {
      final id = await _database!.insert(table, values);
      return id;
    } catch (e) {
      debugPrint('❌ Erro ao inserir em SQLite: $e');
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
      final count = await _database!.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
      );
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao atualizar em SQLite: $e');
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
      final count = await _database!.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );
      return count;
    } catch (e) {
      debugPrint('❌ Erro ao deletar em SQLite: $e');
      rethrow;
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    try {
      return await _database!.transaction((_) => action());
    } catch (e) {
      debugPrint('❌ Erro ao executar transação em SQLite: $e');
      rethrow;
    }
  }

  @override
  Future<dynamic> rawQuery(
    String sql, {
    List<dynamic>? args,
  }) async {
    try {
      return await _database!.rawQuery(sql, args);
    } catch (e) {
      debugPrint('❌ Erro ao fazer rawQuery em SQLite: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isConnected() async {
    return true; // SQLite local sempre está disponível
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Schema será criado por DatabaseHelper
    debugPrint('🏗️ Criando banco SQLite (versão $version)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Upgrade será feito por DatabaseHelper
    debugPrint('⬆️ Atualizando SQLite de v$oldVersion para v$newVersion');
  }
}
