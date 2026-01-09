import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/account_type.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/bank_account.dart';
import '../models/payment_method.dart';
import '../models/payment.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _opening;
  static const String _dbName = 'finance_v62.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;

    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    final opening = _initDB(_dbName);
    _opening = opening;
    try {
      final db = await opening;
      _database = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  Future<void> closeDatabase() async {
    final inFlight = _opening;
    if (inFlight != null) {
      try {
        await inFlight;
      } catch (_) {
        // ignore - close below will handle if opened
      }
    }
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> reopenDatabase() async {
    await closeDatabase();
    _database = await database;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Garantir que o diretório existe
    final directory = Directory(dbPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 11,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('🔄 Iniciando migração de banco de dados v$oldVersion→v$newVersion...');

        // Executar migração com tratamento de erro robusto
        try {
          await _upgradeDB(db, oldVersion, newVersion);
          debugPrint('✓ Migração v$oldVersion→v$newVersion executada com sucesso');
        } catch (e) {
          debugPrint('❌ Erro durante migração v$oldVersion→v$newVersion: $e');
          debugPrintStack(stackTrace: StackTrace.current);
          // Continua mesmo com erro - tenta recuperar na próxima inicialização
        }

        debugPrint('📦 Migração v$oldVersion→v$newVersion concluída');
      },
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    // Otimizações de performance
    await db.execute('PRAGMA journal_mode = WAL');
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA temp_store = MEMORY');
    await db.execute('PRAGMA cache_size = -10000');
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de tipos de conta (será populada pelo DatabaseInitializationService)
    await db.execute('''
      CREATE TABLE account_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Tabela de descrições de contas (subcategorias)
    await db.execute('''
      CREATE TABLE account_descriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accountId INTEGER NOT NULL,
        description TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES account_types (id) ON DELETE CASCADE
      )
    ''');

    // Tabela principal de contas
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        typeId INTEGER NOT NULL,
        description TEXT NOT NULL,
        value REAL NOT NULL,
        estimatedValue REAL,
        dueDay INTEGER NOT NULL,
        isRecurrent INTEGER NOT NULL DEFAULT 0,
        payInAdvance INTEGER NOT NULL DEFAULT 0,
        month INTEGER,
        year INTEGER,
        recurrenceId INTEGER,
        installmentIndex INTEGER,
        installmentTotal INTEGER,
        bestBuyDay INTEGER,
        cardBrand TEXT,
        cardBank TEXT,
        cardLimit REAL,
        cardColor INTEGER,
        cardId INTEGER,
        observation TEXT,
        establishment TEXT,
        purchaseUuid TEXT,
        purchaseDate TEXT,
        creationDate TEXT,
        FOREIGN KEY (typeId) REFERENCES account_types (id) ON DELETE CASCADE,
        FOREIGN KEY (cardId) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Índices para melhor performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_typeId ON accounts(typeId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_month_year ON accounts(month, year)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_cardId ON accounts(cardId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_purchaseUuid ON accounts(purchaseUuid)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_recurrent ON accounts(isRecurrent)');
    // Índices compostos para queries frequentes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_cardId_recurrent ON accounts(cardId, isRecurrent)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_recurrenceId_date ON accounts(recurrenceId, year, month)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_account_descriptions_accountId ON account_descriptions(accountId)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS banks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        agency TEXT NOT NULL,
        account TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_banks_code ON banks(code)');

    // Tabela de formas de pagamento
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
	        type TEXT NOT NULL,
	        icon_code INTEGER NOT NULL,
	        requires_bank INTEGER NOT NULL DEFAULT 0,
	        usage INTEGER NOT NULL DEFAULT 2,
	        is_active INTEGER NOT NULL DEFAULT 1
	      )
	    ''');

    // Tabela de pagamentos
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        payment_method_id INTEGER NOT NULL,
        bank_account_id INTEGER,
        credit_card_id INTEGER,
        value REAL NOT NULL,
        payment_date TEXT NOT NULL,
        observation TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE RESTRICT,
        FOREIGN KEY (bank_account_id) REFERENCES banks (id) ON DELETE SET NULL,
        FOREIGN KEY (credit_card_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_account_id ON payments(account_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)');
  }

  // ========== MIGRAÇÃO DE BANCO (v1 → v2) ==========

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Criar tabela account_descriptions
      await db.execute('''
        CREATE TABLE account_descriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          accountId INTEGER NOT NULL,
          description TEXT NOT NULL,
        FOREIGN KEY (accountId) REFERENCES account_types (id) ON DELETE CASCADE
        )
      ''');

      // Criar índice
      await db.execute('CREATE INDEX IF NOT EXISTS idx_account_descriptions_accountId ON account_descriptions(accountId)');

      // 2. Desabilitar foreign keys temporariamente para operações DDL
      await db.execute('PRAGMA foreign_keys=OFF');

      try {
        // 3. Recreate strategy: SQLite não suporta DROP COLUMN
        // Criar nova tabela sem o campo expenseCategoryId
        await db.execute('''
          CREATE TABLE accounts_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            typeId INTEGER NOT NULL,
            description TEXT NOT NULL,
            value REAL NOT NULL,
            dueDay INTEGER NOT NULL,
            isRecurrent INTEGER NOT NULL DEFAULT 0,
            payInAdvance INTEGER NOT NULL DEFAULT 0,
            month INTEGER,
            year INTEGER,
            recurrenceId INTEGER,
            bestBuyDay INTEGER,
            cardBrand TEXT,
            cardBank TEXT,
            cardLimit REAL,
            cardColor INTEGER,
            cardId INTEGER,
            observation TEXT,
            establishment TEXT,
            purchaseUuid TEXT,
            purchaseDate TEXT,
            creationDate TEXT,
            FOREIGN KEY (typeId) REFERENCES account_types (id) ON DELETE CASCADE,
            FOREIGN KEY (cardId) REFERENCES accounts (id) ON DELETE CASCADE
          )
        ''');

        // Copiar dados da tabela antiga para a nova (sem expenseCategoryId)
        await db.execute('''
          INSERT INTO accounts_new
          SELECT id, typeId, description, value, dueDay, isRecurrent, payInAdvance,
                 month, year, recurrenceId, bestBuyDay, cardBrand, cardBank, cardLimit,
                 cardColor, cardId, observation, establishment, purchaseUuid,
                 purchaseDate, creationDate
          FROM accounts
        ''');

        // Deletar tabela antiga
        await db.execute('DROP TABLE accounts');

        // Renomear tabela nova
        await db.execute('ALTER TABLE accounts_new RENAME TO accounts');

        // Recriar índices
        await db.execute('CREATE INDEX idx_accounts_typeId ON accounts(typeId)');
        await db.execute('CREATE INDEX idx_accounts_month_year ON accounts(month, year)');
        await db.execute('CREATE INDEX idx_accounts_cardId ON accounts(cardId)');
        await db.execute('CREATE INDEX idx_accounts_purchaseUuid ON accounts(purchaseUuid)');
        await db.execute('CREATE INDEX idx_accounts_recurrent ON accounts(isRecurrent)');
      } finally {
        // Reabilitar foreign keys
        await db.execute('PRAGMA foreign_keys=ON');
      }
    }

    if (oldVersion < 3) {
      // Ajustar FK de account_descriptions para apontar para account_types (não accounts)
      await db.execute('PRAGMA foreign_keys=OFF');
      await db.execute('DROP INDEX IF EXISTS idx_account_descriptions_accountId');
      try {
        await db.execute('ALTER TABLE account_descriptions RENAME TO account_descriptions_old');
      } catch (_) {
        await db.execute('DROP TABLE IF EXISTS account_descriptions_old');
      }

      await db.execute('''
        CREATE TABLE account_descriptions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          accountId INTEGER NOT NULL,
          description TEXT NOT NULL,
          FOREIGN KEY (accountId) REFERENCES account_types (id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_account_descriptions_accountId ON account_descriptions(accountId)');

      try {
        await db.execute('''
          INSERT INTO account_descriptions (id, accountId, description)
          SELECT id, accountId, description FROM account_descriptions_old
        ''');
      } catch (_) {
        // Se a tabela antiga não existir ou falhar, prosseguir com tabela limpa
      }

      await db.execute('DROP TABLE IF EXISTS account_descriptions_old');
      await db.execute('PRAGMA foreign_keys=ON');
    }

    if (oldVersion < 4) {
      // Remover FK/coluna obsoleta expenseCategoryId se ainda existir
      await db.execute('PRAGMA foreign_keys=OFF');
      await db.execute('DROP INDEX IF EXISTS idx_accounts_expenseCategoryId');
      // Cria tabela placeholder para satisfazer FK antiga durante o drop
      await db.execute('CREATE TABLE IF NOT EXISTS expense_categories (id INTEGER PRIMARY KEY)');

      await db.execute('''
        CREATE TABLE accounts_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          typeId INTEGER NOT NULL,
          description TEXT NOT NULL,
          value REAL NOT NULL,
          dueDay INTEGER NOT NULL,
          isRecurrent INTEGER NOT NULL DEFAULT 0,
          payInAdvance INTEGER NOT NULL DEFAULT 0,
          month INTEGER,
          year INTEGER,
          recurrenceId INTEGER,
          bestBuyDay INTEGER,
          cardBrand TEXT,
          cardBank TEXT,
          cardLimit REAL,
          cardColor INTEGER,
          cardId INTEGER,
          observation TEXT,
          establishment TEXT,
          purchaseUuid TEXT,
          purchaseDate TEXT,
          creationDate TEXT,
          FOREIGN KEY (typeId) REFERENCES account_types (id) ON DELETE CASCADE,
          FOREIGN KEY (cardId) REFERENCES accounts (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute('''
          INSERT INTO accounts_new
          (id, typeId, description, value, dueDay, isRecurrent, payInAdvance, month, year, recurrenceId,
           bestBuyDay, cardBrand, cardBank, cardLimit, cardColor, cardId, observation, establishment,
           purchaseUuid, purchaseDate, creationDate)
          SELECT id, typeId, description, value, dueDay, isRecurrent, payInAdvance, month, year, recurrenceId,
                 bestBuyDay, cardBrand, cardBank, cardLimit, cardColor, cardId, observation, establishment,
                 purchaseUuid, purchaseDate, creationDate
          FROM accounts
        ''');
      } catch (_) {
        // Se não conseguir copiar, prossegue com tabela nova
      }

      await db.execute('DROP TABLE IF EXISTS accounts');
      await db.execute('ALTER TABLE accounts_new RENAME TO accounts');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_typeId ON accounts(typeId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_month_year ON accounts(month, year)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_cardId ON accounts(cardId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_purchaseUuid ON accounts(purchaseUuid)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_recurrent ON accounts(isRecurrent)');

      await db.execute('DROP TABLE IF EXISTS expense_categories');
      await db.execute('PRAGMA foreign_keys=ON');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS banks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          code INTEGER NOT NULL,
          name TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          agency TEXT NOT NULL,
          account TEXT NOT NULL,
          color INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_banks_code ON banks(code)');
    }

    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE banks ADD COLUMN description TEXT');
      } catch (_) {
        // coluna já existe
      }
      await db.execute("UPDATE banks SET description = '' WHERE description IS NULL");
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE banks ADD COLUMN color INTEGER');
      } catch (_) {
        // coluna já existe
      }
      await db.execute('UPDATE banks SET color = 0 WHERE color IS NULL');
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN installmentIndex INTEGER');
      } catch (_) {
        // coluna ja existe
      }
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN installmentTotal INTEGER');
      } catch (_) {
        // coluna ja existe
      }
    }

    if (oldVersion < 9) {
      // Criar tabela de formas de pagamento
      try {
        await db.execute('''
          CREATE TABLE payment_methods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            type TEXT NOT NULL,
            icon_code INTEGER NOT NULL,
	            requires_bank INTEGER NOT NULL DEFAULT 0,
	            usage INTEGER NOT NULL DEFAULT 2,
	            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');

        // Inserir dados iniciais de formas de pagamento/recebimento
        await db.insert('payment_methods', {
          'name': 'Cartão de Credito',
          'type': 'CREDIT_CARD',
          'icon_code': 0xe25e,
          'requires_bank': 0,
          'usage': 0,
          'is_active': 1,
        });
        await db.insert('payment_methods', {
          'name': 'Crédito em conta',
          'type': 'PIX',
          'icon_code': 0xe8d0,
          'requires_bank': 1,
          'usage': 1,
          'is_active': 1,
        });
        await db.insert('payment_methods', {
          'name': 'Dinheiro',
          'type': 'CASH',
          'icon_code': 0xe25a,
          'requires_bank': 0,
          'usage': 2,
          'is_active': 1,
        });
        await db.insert('payment_methods', {
          'name': 'Débito C/C',
          'type': 'BANK_DEBIT',
          'icon_code': 0xe25c,
          'requires_bank': 1,
          'usage': 0,
          'is_active': 1,
        });
        await db.insert('payment_methods', {
          'name': 'Internet Banking',
          'type': 'BANK_DEBIT',
          'icon_code': 0xe25c,
          'requires_bank': 1,
          'usage': 0,
          'is_active': 1,
        });
        await db.insert('payment_methods', {
          'name': 'PIX',
          'type': 'PIX',
          'icon_code': 0xe8d0,
          'requires_bank': 1,
          'usage': 2,
          'is_active': 1,
        });
      } catch (_) {
        // Tabela já existe
      }

      // Criar tabela de pagamentos
      try {
        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            payment_method_id INTEGER NOT NULL,
            bank_account_id INTEGER,
            credit_card_id INTEGER,
            value REAL NOT NULL,
            payment_date TEXT NOT NULL,
            observation TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
            FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE RESTRICT,
            FOREIGN KEY (bank_account_id) REFERENCES banks (id) ON DELETE SET NULL,
            FOREIGN KEY (credit_card_id) REFERENCES accounts (id) ON DELETE SET NULL
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_account_id ON payments(account_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)');
      } catch (_) {
        // Tabela já existe
      }
    }

    if (oldVersion < 11) {
      debugPrint('?? Executando migra‡Æo v11: Adicionando coluna usage em payment_methods...');
      try {
        try {
          await db.execute(
              'ALTER TABLE payment_methods ADD COLUMN usage INTEGER NOT NULL DEFAULT 2');
        } catch (_) {
          // coluna j  existe
        }
        await db.execute('UPDATE payment_methods SET usage = 2 WHERE usage IS NULL');
      } catch (e) {
        debugPrint('?? Erro na migra‡Æo v11: $e');
      }
    }

    if (oldVersion < 10) {
      // Adicionar coluna estimatedValue para suportar dois campos em contas recorrentes:
      // - estimatedValue: valor médio/previsto (Valor Previsto/Médio)
      // - value: valor lançado (Valor Lançado)
      debugPrint('🔄 Executando migração v10: Adicionando coluna estimatedValue...');
      try {
        // Simplesmente tentar adicionar a coluna - se já existe, o erro é ignorado
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN estimatedValue REAL');
          debugPrint('✓ Coluna estimatedValue adicionada com sucesso à tabela accounts');
        } catch (e) {
          // Coluna já existe ou outro erro - continua mesmo assim
          if (e.toString().contains('duplicate') || e.toString().contains('already exists')) {
            debugPrint('ℹ️ Coluna estimatedValue já existe na tabela accounts');
          } else {
            debugPrint('⚠️ Aviso ao adicionar coluna: $e');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Erro geral na migração v10: $e');
      }
    }
  }

  // ========== CRUD TIPOS DE CONTA ==========
  
  Future<int> createType(AccountType type) async {
    final db = await database;
    return await db.insert('account_types', type.toMap());
  }

  Future<int> updateType(AccountType type) async {
    final db = await database;
    return await db.update(
      'account_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<List<AccountType>> readAllTypes() async {
    final db = await database;
    final maps = await db.query('account_types', orderBy: 'name ASC');
    return maps.map((json) => AccountType.fromMap(json)).toList();
  }

  Future<int> countAccountTypes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM account_types');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> deleteType(int id) async {
    final db = await database;
    return await db.delete('account_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> checkAccountTypeExists(String name) async {
    final db = await database;
    final result = await db.query(
      'account_types',
      where: 'UPPER(name) = ?',
      whereArgs: [name.toUpperCase()],
    );
    return result.isNotEmpty;
  }

  // ========== CRUD CATEGORIAS DE CONTAS ==========

  Future<int> createAccountCategory(AccountCategory categoria) async {
    final db = await database;
    return await db.insert('account_descriptions', categoria.toMap());
  }

  Future<int> updateAccountCategory(AccountCategory categoria) async {
    final db = await database;
    return await db.update(
      'account_descriptions',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  Future<List<AccountCategory>> readAccountCategories(int accountId) async {
    final db = await database;
    final maps = await db.query(
      'account_descriptions',
      where: 'accountId = ?',
      whereArgs: [accountId],
      orderBy: 'description ASC',
    );
    return maps.map((json) => AccountCategory.fromMap(json)).toList();
  }

  Future<List<AccountCategory>> readAllAccountCategories() async {
    final db = await database;
    final maps = await db.query(
      'account_descriptions',
      orderBy: 'description ASC',
    );
    return maps.map((json) => AccountCategory.fromMap(json)).toList();
  }

  Future<int> deleteAccountCategory(int id) async {
    final db = await database;
    return await db.delete('account_descriptions', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> checkAccountCategoryExists(int accountId, String categoria) async {
    final db = await database;
    final result = await db.query(
      'account_descriptions',
      where: 'accountId = ? AND UPPER(description) = ?',
      whereArgs: [accountId, categoria.toUpperCase()],
    );
    return result.isNotEmpty;
  }

  // ========== CRUD CONTAS ==========
  
  Future<int> createAccount(Account account) async {
    final db = await database;
    return await db.insert('accounts', account.toMap());
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;

    // Se for uma recorrência PAI (isRecurrent = 1), deleta também as instâncias filhas
    final account = await getAccountById(id);
    if (account != null && account.isRecurrent) {
      debugPrint('🗑️  Deletando recorrência PAI (ID: $id) e todas as suas instâncias...');
      // Deletar todas as contas filhas que têm recurrenceId = id
      await db.delete('accounts', where: 'recurrenceId = ?', whereArgs: [id]);
      debugPrint('✓ Instâncias filhas deletadas');
    }

    // Deletar a conta principal
    int result = await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    debugPrint('✓ Conta deletada (ID: $id)');
    return result;
  }

  /// Deleta apenas a conta específica, SEM cascata (não deleta filhas automaticamente)
  Future<int> deleteAccountOnly(int id) async {
    final db = await database;
    debugPrint('🗑️ Deletando SOMENTE conta ID: $id (sem cascata)');
    int result = await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    if (result == 0) {
      debugPrint('⚠️ Nenhuma conta deletada (ID $id não encontrado no banco)');
    } else {
      debugPrint('✅ Conta deletada com sucesso (ID: $id, linhas afetadas: $result)');
    }
    return result;
  }

  Future<List<Account>> readAllAccountsRaw() async {
    final db = await database;
    final maps = await db.query('accounts');
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  /// Busca uma conta específica por ID
  Future<Account?> getAccountById(int? id) async {
    if (id == null) return null;
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  /// Busca apenas as contas filhas de uma recorrência pai
  Future<List<Account>> getAccountsByRecurrenceId(int recurrenceId) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'recurrenceId = ? AND month IS NOT NULL AND year IS NOT NULL',
      whereArgs: [recurrenceId],
      orderBy: 'year ASC, month ASC, dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  /// Busca todas as contas parceladas com o mesmo installmentTotal (todas as parcelas de uma série)
  Future<List<Account>> getAccountsByInstallmentTotal(int installmentTotal, String description) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'installmentTotal = ? AND description = ?',
      whereArgs: [installmentTotal, description],
      orderBy: 'month ASC, year ASC, installmentIndex ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> readAllCards() async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'cardBrand IS NOT NULL',
      orderBy: 'cardBank ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> getCardExpensesForMonth(
    int cardId,
    int month,
    int year,
  ) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'cardId = ? AND month = ? AND year = ? AND isRecurrent = 0',
      whereArgs: [cardId, month, year],
      orderBy: 'dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> readAccountsByDate(int month, int year) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> getAccountsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT * FROM accounts
      WHERE (year > ? OR (year = ? AND month >= ?))
        AND (year < ? OR (year = ? AND month <= ?))
      ORDER BY year ASC, month ASC, dueDay ASC
    ''', [
      startDate.year,
      startDate.year,
      startDate.month,
      endDate.year,
      endDate.year,
      endDate.month,
    ]);
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  // ========== MÉTODOS DE MOVIMENTAÇÃO ==========
  
  Future<void> moveAccount(int id, int newMonth, int newYear) async {
    final db = await database;
    await db.update(
      'accounts',
      {'month': newMonth, 'year': newYear},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> moveInstallmentSeries(
    int cardId,
    String baseDescriptionLike,
    int monthOffset,
  ) async {
    final db = await database;
    final list = await db.query(
      'accounts',
      where: 'cardId = ? AND description LIKE ?',
      whereArgs: [cardId, '$baseDescriptionLike%'],
    );

    final batch = db.batch();
    for (var item in list) {
      int id = item['id'] as int;
      int currentMonth = item['month'] as int;
      int currentYear = item['year'] as int;
      DateTime currentDt = DateTime(currentYear, currentMonth, 1);
      DateTime newDt = DateTime(
        currentDt.year,
        currentDt.month + monthOffset,
        1,
      );
      batch.update(
        'accounts',
        {'month': newDt.month, 'year': newDt.year},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> moveInstallmentSeriesByUuid(
    String purchaseUuid,
    int monthOffset,
  ) async {
    final db = await database;
    final list = await db.query(
      'accounts',
      where: 'purchaseUuid = ?',
      whereArgs: [purchaseUuid],
    );

    final batch = db.batch();
    for (var item in list) {
      int id = item['id'] as int;
      int currentMonth = item['month'] as int;
      int currentYear = item['year'] as int;
      DateTime currentDt = DateTime(currentYear, currentMonth, 1);
      DateTime newDt = DateTime(
        currentDt.year,
        currentDt.month + monthOffset,
        1,
      );
      batch.update(
        'accounts',
        {'month': newDt.month, 'year': newDt.year},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ========== SÉRIES E RECORRÊNCIAS ==========
  
  Future<void> deleteSubscriptionSeries(int recurrenceId) async {
    final db = await database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [recurrenceId]);
    await db.delete('accounts', where: 'recurrenceId = ?', whereArgs: [recurrenceId]);
  }

  Future<List<Account>> readInstallmentSeriesByUuid(String purchaseUuid) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'purchaseUuid = ?',
      whereArgs: [purchaseUuid],
      orderBy: 'year ASC, month ASC, dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> readInstallmentSeries(
    int cardId,
    String baseDescriptionLike, {
    int? installmentTotal,
  }) async {
    final db = await database;
    final whereClauses = ['cardId = ?', 'description LIKE ?'];
    final whereArgs = [cardId, '$baseDescriptionLike%'];
    if (installmentTotal != null && installmentTotal > 0) {
      whereClauses.add('installmentTotal = ?');
      whereArgs.add(installmentTotal);
    }
    final maps = await db.query(
      'accounts',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'year ASC, month ASC, dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<List<Account>> readInstallmentSeriesByDescription(
    int typeId,
    String baseDescription, {
    int? installmentTotal,
  }) async {
    final db = await database;
    final whereClauses = ['typeId = ?', 'description LIKE ?'];
    final whereArgs = [typeId, '$baseDescription (%'];
    if (installmentTotal != null && installmentTotal > 0) {
      whereClauses.add('installmentTotal = ?');
      whereArgs.add(installmentTotal);
    }
    final maps = await db.query(
      'accounts',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'year ASC, month ASC, dueDay ASC',
    );
    return maps.map((json) => Account.fromMap(json)).toList();
  }

  Future<void> deleteInstallmentSeriesByUuid(String purchaseUuid) async {
    final db = await database;
    await db.delete('accounts', where: 'purchaseUuid = ?', whereArgs: [purchaseUuid]);
  }

  Future<void> deleteInstallmentSeries(
    int cardId,
    String baseDescriptionLike, {
    int? installmentTotal,
  }) async {
    final db = await database;
    final whereClauses = ['cardId = ?'];
    final whereArgs = <Object?>[cardId];
    if (installmentTotal != null && installmentTotal > 0) {
      whereClauses.add('installmentTotal = ?');
      whereArgs.add(installmentTotal);
    }
    whereClauses.add('(description = ? OR description LIKE ?)');
    whereArgs.addAll([baseDescriptionLike, '$baseDescriptionLike (%']);
    await db.delete(
      'accounts',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
    );
  }

  Future<void> deleteInstallmentSeriesByDescription(
    int typeId,
    String baseDescription, {
    int? installmentTotal,
  }) async {
    final db = await database;
    final whereClauses = ['typeId = ?'];
    final whereArgs = <Object?>[typeId];
    if (installmentTotal != null && installmentTotal > 0) {
      whereClauses.add('installmentTotal = ?');
      whereArgs.add(installmentTotal);
    }
    whereClauses.add('(description = ? OR description LIKE ?)');
    whereArgs.addAll([baseDescription, '$baseDescription (%']);
    await db.delete(
      'accounts',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
    );
  }

  // ========== ESTATÍSTICAS E ANÁLISE ==========
  
  Future<DateTime?> getLastAccountDate() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT year, month, dueDay 
      FROM accounts 
      WHERE isRecurrent = 0 
      ORDER BY year DESC, month DESC, dueDay DESC 
      LIMIT 1
    ''');
    
    if (result.isNotEmpty) {
      final row = result.first;
      if (row['year'] != null && row['month'] != null && row['dueDay'] != null) {
        return DateTime(
          row['year'] as int,
          row['month'] as int,
          row['dueDay'] as int,
        );
      }
    }
    return null;
  }

  Future<double> getTotalByMonth(int month, int year) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT SUM(value) as total 
      FROM accounts 
      WHERE month = ? AND year = ? AND isRecurrent = 0
    ''', [month, year]);
    
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }


  // ========== LIMPEZA ==========
  
  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('payments');
    await db.delete('accounts');
    await db.delete('account_descriptions');
    await db.delete('account_types');
    await db.delete('payment_methods');
    await db.delete('banks');

    try {
      await db.delete('sqlite_sequence');
    } catch (e) {
      // Ignore se não existir
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  Future<void> exportDatabase(String destinationPath) async {
    final sourcePath = await getDatabaseFilePath();
    await close();
    final dbFile = File(sourcePath);
    if (!await dbFile.exists()) {
      throw Exception('Arquivo do banco não encontrado.');
    }
    await dbFile.copy(destinationPath);
    await database;
  }

  Future<void> importDatabase(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Arquivo selecionado não existe.');
    }
    final targetPath = await getDatabaseFilePath();
    await close();
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await sourceFile.copy(targetPath);
    await database;
  }

  Future<void> repairDatabase() async {
    final db = await database;
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    final result = integrity.isNotEmpty ? integrity.first.values.first : 'ok';
    if (result != 'ok') {
      throw Exception('PRAGMA integrity_check retornou: $result');
    }
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    await db.execute('VACUUM');
  }

  // ==== BANCOS ====
  Future<int> createBankAccount(BankAccount bank) async {
    final db = await database;
    return await db.insert('banks', bank.toMap());
  }

  Future<List<BankAccount>> readBankAccounts() async {
    final db = await database;
    final maps = await db.query('banks', orderBy: 'name');
    return maps.map((m) => BankAccount.fromMap(m)).toList();
  }

  Future<int> updateBankAccount(BankAccount bank) async {
    final db = await database;
    return await db.update('banks', bank.toMap(), where: 'id = ?', whereArgs: [bank.id]);
  }

  Future<int> deleteBankAccount(int id) async {
    final db = await database;
    return await db.delete('banks', where: 'id = ?', whereArgs: [id]);
  }

  // ========== CRUD FORMAS DE PAGAMENTO ==========

  Future<int> createPaymentMethod(PaymentMethod method) async {
    final db = await database;
    return await db.insert('payment_methods', method.toMap());
  }

  Future<List<PaymentMethod>> readPaymentMethods({bool onlyActive = true}) async {
    final db = await database;
    if (onlyActive) {
      final maps = await db.query(
        'payment_methods',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
      return maps.map((m) => PaymentMethod.fromMap(m)).toList();
    } else {
      final maps = await db.query('payment_methods', orderBy: 'name ASC');
      return maps.map((m) => PaymentMethod.fromMap(m)).toList();
    }
  }

  Future<int> countPaymentMethods({bool onlyActive = false}) async {
    final db = await database;
    if (onlyActive) {
      final result =
          await db.rawQuery('SELECT COUNT(*) FROM payment_methods WHERE is_active = 1');
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery('SELECT COUNT(*) FROM payment_methods');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> updatePaymentMethod(PaymentMethod method) async {
    final db = await database;
    return await db.update(
      'payment_methods',
      method.toMap(),
      where: 'id = ?',
      whereArgs: [method.id],
    );
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    return await db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> checkPaymentMethodExists(String name, {int? excludeId}) async {
    final db = await database;
    String where = 'UPPER(name) = ?';
    List<Object> whereArgs = [name.toUpperCase()];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final result = await db.query(
      'payment_methods',
      where: where,
      whereArgs: whereArgs,
    );
    return result.isNotEmpty;
  }

  // ========== CRUD PAGAMENTOS ==========

  Future<int> createPayment(Payment payment) async {
    final db = await database;
    return await db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> readPaymentsByAccountId(int accountId) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'payment_date DESC',
    );
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<List<Payment>> readPaymentsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT * FROM payments
      WHERE payment_date >= ? AND payment_date <= ?
      ORDER BY payment_date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<List<Payment>> readAllPayments() async {
    final db = await database;
    final maps = await db.query('payments', orderBy: 'payment_date DESC');
    return maps.map((m) => Payment.fromMap(m)).toList();
  }

  Future<int> deletePayment(int id) async {
    final db = await database;
    return await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }

  // ========== MÉTODOS AUXILIARES ==========

  Future<bool> isAccountPaid(int accountId) async {
    final db = await database;
    final result = await db.query(
      'payments',
      where: 'account_id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getAccountPaymentInfo(int accountId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT p.id, p.payment_date, pm.name as method_name
      FROM payments p
      INNER JOIN payment_methods pm ON p.payment_method_id = pm.id
      WHERE p.account_id = ?
      ORDER BY p.created_at DESC
      LIMIT 1
    ''', [accountId]);

    if (result.isNotEmpty) {
      return {
        'id': result.first['id'],
        'payment_date': result.first['payment_date'],
        'method_name': result.first['method_name'],
      };
    }
    return null;
  }

  Future<Map<int, Map<String, dynamic>>> getPaymentsForAccountsByMonth(
      List<int> accountIds, int month, int year) async {
    if (accountIds.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(accountIds.length, '?').join(',');
    final start = DateTime(year, month, 1);
    final endExclusive = DateTime(year, month + 1, 1);
    final startIso = start.toIso8601String();
    final endIso = endExclusive.toIso8601String();
    final result = await db.rawQuery('''
      SELECT p.account_id, p.id, p.payment_date, pm.name as method_name, p.created_at
      FROM payments p
      INNER JOIN payment_methods pm ON p.payment_method_id = pm.id
      WHERE p.account_id IN ($placeholders)
        AND p.payment_date >= ?
        AND p.payment_date < ?
      ORDER BY p.account_id, p.created_at DESC
    ''', [...accountIds, startIso, endIso]);

    final map = <int, Map<String, dynamic>>{};
    for (final row in result) {
      final accountId = row['account_id'] as int?;
      if (accountId == null) continue;
      if (map.containsKey(accountId)) continue;
      map[accountId] = {
        'id': row['id'],
        'payment_date': row['payment_date'],
        'method_name': row['method_name'],
      };
    }
    return map;
  }

  // ========== FUNÇÕES DE DEBUG ==========

  Future<double> getPaymentsSumForAccountsByMonth(
    List<int> accountIds,
    int month,
    int year,
  ) async {
    if (accountIds.isEmpty) return 0.0;
    final db = await database;
    final placeholders = List.filled(accountIds.length, '?').join(',');
    final start = DateTime(year, month, 1);
    final endExclusive = DateTime(year, month + 1, 1);
    final startIso = start.toIso8601String();
    final endIso = endExclusive.toIso8601String();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(p.value), 0) as total
      FROM payments p
      WHERE p.account_id IN ($placeholders)
        AND p.payment_date >= ?
        AND p.payment_date < ?
    ''', [...accountIds, startIso, endIso]);

    if (result.isEmpty) return 0.0;
    final total = result.first['total'];
    if (total is int) return total.toDouble();
    if (total is double) return total;
    return double.tryParse(total?.toString() ?? '') ?? 0.0;
  }

  /// Reset banco de dados (para testes/debug)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    
    // Fechar conexão atual
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // Deletar arquivo do banco
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      debugPrint('🗑️ Banco de dados deletado: $path');
    }
    
    // Reconectar (vai recriar com _createDB)
    _database = await _initDB(_dbName);
    debugPrint('✅ Banco de dados recriado');
  }

  /// Lê uma conta específica por ID
  Future<Account?> readAccountById(int id) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  /// Busca instância de recorrência por mês/ano
  Future<Account?> findInstanceByRecurrenceAndMonth(int recurrenceId, int month, int year) async {
    final db = await database;
    final maps = await db.query(
      'accounts',
      where: 'recurrenceId = ? AND month = ? AND year = ? AND isRecurrent = 0',
      whereArgs: [recurrenceId, month, year],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  /// Atualiza instâncias futuras de uma recorrência
  Future<void> updateRecurrenceInstances(
    int parentId,
    int fromMonth,
    int fromYear,
    Map<String, dynamic> updates,
  ) async {
    final db = await database;
    await db.update(
      'accounts',
      updates,
      where: 'recurrenceId = ? AND (year > ? OR (year = ? AND month >= ?))',
      whereArgs: [parentId, fromYear, fromYear, fromMonth],
    );
  }
}
