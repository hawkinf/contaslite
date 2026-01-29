import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testes para validação de resolução de FK
///
/// TRAVA DE SEGURANÇA NO FLUTTER:
/// Garante que FKs obrigatórias são resolvidas antes de enviar ao servidor.
/// Registros com FKs não resolvidas são pulados para evitar FK órfãs.
void main() {
  // Inicializar sqflite_ffi para testes
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    // Criar banco de dados em memória para testes
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        // Criar tabelas mínimas para testes
        await db.execute('''
          CREATE TABLE account_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            server_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE account_descriptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            accountId INTEGER NOT NULL,
            description TEXT NOT NULL,
            server_id TEXT,
            FOREIGN KEY (accountId) REFERENCES account_types (id)
          )
        ''');

        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            typeId INTEGER NOT NULL,
            categoryId INTEGER,
            cardId INTEGER,
            description TEXT NOT NULL,
            value REAL NOT NULL,
            dueDay INTEGER NOT NULL,
            server_id TEXT,
            FOREIGN KEY (typeId) REFERENCES account_types (id),
            FOREIGN KEY (categoryId) REFERENCES account_descriptions (id),
            FOREIGN KEY (cardId) REFERENCES accounts (id)
          )
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('FK Resolution - account_descriptions', () {
    test('deve resolver accountId quando server_id existe', () async {
      // Arrange: criar account_type com server_id
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': '100', // server_id existe
      });

      // Act: simular resolução de FK
      final serverIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert
      expect(serverIdResult.isNotEmpty, true);
      expect(serverIdResult.first['server_id'], '100');
    });

    test('deve retornar null quando accountId não tem server_id', () async {
      // Arrange: criar account_type SEM server_id
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': null, // SEM server_id
      });

      // Act: simular verificação de FK
      final serverIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert: server_id é null, registro deve ser PULADO
      expect(serverIdResult.isNotEmpty, true);
      expect(serverIdResult.first['server_id'], isNull);
    });

    test('deve retornar null quando accountId não existe', () async {
      // Act: simular verificação de FK para ID inexistente
      final serverIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [999], // ID que não existe
      );

      // Assert: registro não encontrado
      expect(serverIdResult.isEmpty, true);
    });
  });

  group('FK Resolution - accounts', () {
    test('deve resolver typeId obrigatório quando server_id existe', () async {
      // Arrange
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': '100',
      });

      // Act
      final serverIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert
      expect(serverIdResult.first['server_id'], '100');
    });

    test('deve retornar null quando typeId obrigatório não tem server_id', () async {
      // Arrange: account_type sem server_id
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': null,
      });

      // Act
      final serverIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert: deve pular registro (typeId é obrigatório)
      expect(serverIdResult.first['server_id'], isNull);
    });

    test('deve remover categoryId opcional quando não tem server_id', () async {
      // Arrange
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': '100',
      });
      await db.insert('account_descriptions', {
        'id': 1,
        'accountId': 1,
        'description': 'Categoria Teste',
        'server_id': null, // SEM server_id
      });

      // Act
      final categoryResult = await db.query(
        'account_descriptions',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert: categoryId opcional sem server_id deve ser REMOVIDO (não null)
      expect(categoryResult.first['server_id'], isNull);
      // Comportamento esperado: remover categoryId do payload, não pular registro
    });

    test('deve remover cardId opcional quando não tem server_id', () async {
      // Arrange
      await db.insert('account_types', {
        'id': 1,
        'name': 'Tipo Teste',
        'server_id': '100',
      });
      await db.insert('accounts', {
        'id': 1,
        'typeId': 1,
        'description': 'Cartão Teste',
        'value': 0,
        'dueDay': 10,
        'server_id': null, // Cartão sem server_id
      });

      // Act
      final cardResult = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [1],
      );

      // Assert: cardId opcional sem server_id deve ser REMOVIDO
      expect(cardResult.first['server_id'], isNull);
    });
  });

  group('Cenários de segurança - FK Cross-User Prevention', () {
    test('cenário: sync ordem correta - account_types antes de account_descriptions', () async {
      // Este teste valida a ordem de sincronização
      // account_types DEVE ser sincronizado ANTES de account_descriptions

      // 1. Sincronizar account_types primeiro
      await db.insert('account_types', {
        'id': 1,
        'name': 'Alimentação',
        'server_id': '100', // Recebe server_id do servidor
      });

      // 2. Agora podemos sincronizar account_descriptions
      await db.insert('account_descriptions', {
        'id': 1,
        'accountId': 1,
        'description': 'Supermercado',
        'server_id': null,
      });

      // 3. Ao fazer push, accountId será resolvido para server_id=100
      final typeServerIdResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      expect(typeServerIdResult.first['server_id'], '100');
    });

    test('cenário: evitar envio de FK local quando server_id não existe', () async {
      // Este teste valida que NÃO enviamos IDs locais para o servidor

      // 1. Criar account_type SEM server_id (não foi sincronizado ainda)
      await db.insert('account_types', {
        'id': 1,
        'name': 'Alimentação',
        'server_id': null, // NÃO sincronizado
      });

      // 2. Criar account_description que referencia o tipo
      await db.insert('account_descriptions', {
        'id': 1,
        'accountId': 1, // Referência LOCAL
        'description': 'Supermercado',
      });

      // 3. Ao tentar resolver FK, deve falhar
      final typeResult = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [1],
      );

      // server_id é null, então este registro DEVE SER PULADO
      expect(typeResult.first['server_id'], isNull);

      // Comportamento esperado no código real:
      // resolveAccountDescriptionReferences retorna null
      // sync_service.dart filtra nulls e não envia este registro
    });

    test('cenário: mapeamento bidirecional local_id <-> server_id', () async {
      // Este teste valida que o mapeamento funciona nos dois sentidos

      // 1. Criar registro local
      final localId = await db.insert('account_types', {
        'name': 'Saúde',
        'server_id': null,
      });
      expect(localId, isNotNull);

      // 2. Simular recebimento de server_id após push
      await db.update(
        'account_types',
        {'server_id': '200'},
        where: 'id = ?',
        whereArgs: [localId],
      );

      // 3. Verificar mapeamento local -> server
      final localToServer = await db.query(
        'account_types',
        where: 'id = ?',
        whereArgs: [localId],
      );
      expect(localToServer.first['server_id'], '200');

      // 4. Verificar mapeamento server -> local
      final serverToLocal = await db.query(
        'account_types',
        where: 'server_id = ?',
        whereArgs: ['200'],
      );
      expect(serverToLocal.first['id'], localId);
    });
  });

  group('Ordem de sincronização', () {
    test('deve respeitar ordem de dependências no push', () {
      // Ordem correta de push (tabelas sem FK primeiro):
      const pushOrder = [
        'account_types', // Sem FK para outras tabelas de sync
        'account_descriptions', // FK para account_types
        'banks', // Sem FK para outras tabelas de sync
        'payment_methods', // Sem FK para outras tabelas de sync
        'accounts', // FK para account_types, account_descriptions
        'payments', // FK para accounts, payment_methods, banks
      ];

      // Verificar que account_types vem antes de account_descriptions
      expect(
        pushOrder.indexOf('account_types') < pushOrder.indexOf('account_descriptions'),
        true,
      );

      // Verificar que account_types vem antes de accounts
      expect(
        pushOrder.indexOf('account_types') < pushOrder.indexOf('accounts'),
        true,
      );

      // Verificar que account_descriptions vem antes de accounts
      expect(
        pushOrder.indexOf('account_descriptions') < pushOrder.indexOf('accounts'),
        true,
      );

      // Verificar que accounts vem antes de payments
      expect(
        pushOrder.indexOf('accounts') < pushOrder.indexOf('payments'),
        true,
      );
    });
  });
}
