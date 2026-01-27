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
import '../services/database_protection_service.dart';
import 'sync_helpers.dart';

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
      version: 17,
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
        name TEXT NOT NULL UNIQUE,
        logo TEXT
      )
    ''');

    // Tabela de descrições de contas (subcategorias)
    await db.execute('''
      CREATE TABLE account_descriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accountId INTEGER NOT NULL,
        description TEXT NOT NULL,
        logo TEXT,
        FOREIGN KEY (accountId) REFERENCES account_types (id) ON DELETE CASCADE
      )
    ''');

    // Tabela principal de contas
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        typeId INTEGER NOT NULL,
        categoryId INTEGER,
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
        logo TEXT,
        observation TEXT,
        purchaseUuid TEXT,
        purchaseDate TEXT,
        creationDate TEXT,
        FOREIGN KEY (typeId) REFERENCES account_types (id) ON DELETE CASCADE,
        FOREIGN KEY (categoryId) REFERENCES account_descriptions (id) ON DELETE SET NULL,
        FOREIGN KEY (cardId) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // Índices para melhor performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_typeId ON accounts(typeId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_categoryId ON accounts(categoryId)');
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
        is_active INTEGER NOT NULL DEFAULT 1,
        logo TEXT
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

    // Tabela de metadados de sincronização
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL UNIQUE,
        last_sync_at TEXT,
        last_server_timestamp TEXT,
        user_id TEXT
      )
    ''');

    // Tabela de sessão do usuário
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_session (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        name TEXT,
        access_token TEXT,
        refresh_token TEXT,
        token_expires_at TEXT,
        logged_in_at TEXT
      )
    ''');
  }

  // ========== MIGRAÇÃO DE BANCO ==========

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Migração v16: Adicionar campo logo em payment_methods
    if (oldVersion < 16) {
      debugPrint('🔄 Executando migração v16: Adicionando campo logo em payment_methods...');
      try {
        await db.execute('ALTER TABLE payment_methods ADD COLUMN logo TEXT');
        debugPrint('✓ Migração v16 concluída');
      } catch (e) {
        debugPrint('⚠️ Coluna logo já existe ou erro: $e');
      }
    }

    // Migração v14: Adicionar campo logo nas contas
    if (oldVersion < 14) {
      debugPrint('🔄 Executando migração v14: Adicionando campo logo...');
      try {
        // Adicionar coluna logo em account_types
        try {
          await db.execute('ALTER TABLE account_types ADD COLUMN logo TEXT');
        } catch (_) {}
        
        // Adicionar coluna logo em accounts
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN logo TEXT');
        } catch (_) {}
        
        // Adicionar coluna logo em account_descriptions
        try {
          await db.execute('ALTER TABLE account_descriptions ADD COLUMN logo TEXT');
        } catch (_) {}
        
        debugPrint('✓ Migração v14 concluída');
      } catch (e) {
        debugPrint('❌ Erro na migração v14: $e');
      }
    }

    // Migração v13: Adicionar suporte a sincronização multi-usuário
    if (oldVersion < 13) {
      debugPrint('🔄 Executando migração v13: Adicionando suporte a sincronização...');
      try {
        // Adicionar colunas de sync em accounts
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN updated_at TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN last_synced_at TEXT');
        } catch (_) {}

        // Adicionar colunas de sync em account_types
        try {
          await db.execute('ALTER TABLE account_types ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE account_types ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE account_types ADD COLUMN updated_at TEXT');
        } catch (_) {}

        // Adicionar colunas de sync em account_descriptions
        try {
          await db.execute('ALTER TABLE account_descriptions ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE account_descriptions ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE account_descriptions ADD COLUMN updated_at TEXT');
        } catch (_) {}

        // Adicionar colunas de sync em banks
        try {
          await db.execute('ALTER TABLE banks ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE banks ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE banks ADD COLUMN updated_at TEXT');
        } catch (_) {}

        // Adicionar colunas de sync em payment_methods
        try {
          await db.execute('ALTER TABLE payment_methods ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE payment_methods ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE payment_methods ADD COLUMN updated_at TEXT');
        } catch (_) {}

        // Adicionar colunas de sync em payments
        try {
          await db.execute('ALTER TABLE payments ADD COLUMN server_id TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE payments ADD COLUMN sync_status INTEGER DEFAULT 0');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE payments ADD COLUMN updated_at TEXT');
        } catch (_) {}

        // Criar tabela de metadados de sync
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_metadata (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL UNIQUE,
            last_sync_at TEXT,
            last_server_timestamp TEXT,
            user_id TEXT
          )
        ''');

        // Criar tabela de sessão do usuário
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_session (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_id TEXT NOT NULL,
            email TEXT NOT NULL,
            name TEXT,
            access_token TEXT,
            refresh_token TEXT,
            token_expires_at TEXT,
            logged_in_at TEXT
          )
        ''');

        // Criar índices para sync
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_sync_status ON accounts(sync_status)');
        } catch (_) {}
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_server_id ON accounts(server_id)');
        } catch (_) {}

        // Marcar todos os registros existentes como pendentes de criação no servidor
        await db.execute('UPDATE accounts SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');
        await db.execute('UPDATE account_types SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');
        await db.execute('UPDATE account_descriptions SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');
        await db.execute('UPDATE banks SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');
        await db.execute('UPDATE payment_methods SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');
        await db.execute('UPDATE payments SET sync_status = 1 WHERE sync_status IS NULL OR sync_status = 0');

        debugPrint('✓ Migração v13 concluída com sucesso');
      } catch (e) {
        debugPrint('❌ Erro na migração v13: $e');
      }
    }

    // Migração v17: Limpeza de coluna antiga em accounts
    if (oldVersion < 17) {
      debugPrint('🔄 Executando migração v17: Limpando coluna antiga...');
      try {
        try {
          await DatabaseProtectionService.instance.createBackup(
            'pre_migration_v17_cleanup_accounts',
            databaseOverride: db,
          );
        } catch (e) {
          debugPrint('⚠️ Falha ao criar backup antes da migração v17: $e');
        }

        await db.execute('PRAGMA foreign_keys=OFF');
        await db.execute('''
          CREATE TABLE accounts_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            typeId INTEGER NOT NULL,
            categoryId INTEGER,
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
            logo TEXT,
            observation TEXT,
            purchaseUuid TEXT,
            purchaseDate TEXT,
            creationDate TEXT,
            server_id TEXT,
            sync_status INTEGER DEFAULT 0,
            updated_at TEXT,
            last_synced_at TEXT,
            FOREIGN KEY (typeId) REFERENCES account_types (id) ON DELETE CASCADE,
            FOREIGN KEY (categoryId) REFERENCES account_descriptions (id) ON DELETE SET NULL,
            FOREIGN KEY (cardId) REFERENCES accounts (id) ON DELETE CASCADE
          )
        ''');

        final existingColumns = await db.rawQuery("PRAGMA table_info('accounts')");
        final existingNames = existingColumns
            .map((row) => row['name'] as String)
            .toSet();
        final targetColumns = [
          'id',
          'typeId',
          'categoryId',
          'description',
          'value',
          'estimatedValue',
          'dueDay',
          'isRecurrent',
          'payInAdvance',
          'month',
          'year',
          'recurrenceId',
          'installmentIndex',
          'installmentTotal',
          'bestBuyDay',
          'cardBrand',
          'cardBank',
          'cardLimit',
          'cardColor',
          'cardId',
          'logo',
          'observation',
          'purchaseUuid',
          'purchaseDate',
          'creationDate',
          'server_id',
          'sync_status',
          'updated_at',
          'last_synced_at',
        ];
        final copyColumns =
            targetColumns.where(existingNames.contains).toList();
        final columnList = copyColumns.join(', ');
        await db.execute('''
          INSERT INTO accounts_new ($columnList)
          SELECT $columnList
          FROM accounts
        ''');

        await db.execute('DROP TABLE accounts');
        await db.execute('ALTER TABLE accounts_new RENAME TO accounts');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_typeId ON accounts(typeId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_categoryId ON accounts(categoryId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_month_year ON accounts(month, year)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_cardId ON accounts(cardId)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_purchaseUuid ON accounts(purchaseUuid)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_recurrent ON accounts(isRecurrent)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_cardId_recurrent ON accounts(cardId, isRecurrent)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_recurrenceId_date ON accounts(recurrenceId, year, month)');
      } catch (e) {
        debugPrint('❌ Erro na migração v17: $e');
      } finally {
        await db.execute('PRAGMA foreign_keys=ON');
      }
    }

    if (oldVersion < 12) {
      debugPrint('🔄 Executando migração v12: adicionando categoryId em accounts...');
      try {
        try {
          await db.execute('ALTER TABLE accounts ADD COLUMN categoryId INTEGER');
        } catch (_) {
          // coluna já existe
        }
        try {
          await db.execute('CREATE INDEX IF NOT EXISTS idx_accounts_categoryId ON accounts(categoryId)');
        } catch (_) {
          // índice já existe
        }
        // Melhor esforço: popular categoryId quando description == categoria
        try {
          await db.execute('''
            UPDATE accounts
               SET categoryId = (
                 SELECT ad.id
                   FROM account_descriptions ad
                  WHERE ad.accountId = accounts.typeId
                    AND ad.description = accounts.description
                  LIMIT 1
               )
             WHERE categoryId IS NULL
          ''');
        } catch (_) {
          // ignore
        }
      } catch (e) {
        debugPrint('❌ Erro na migração v12: $e');
      }
    }
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
               cardColor, cardId, observation, purchaseUuid,
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
              bestBuyDay, cardBrand, cardBank, cardLimit, cardColor, cardId, observation,
           purchaseUuid, purchaseDate, creationDate)
          SELECT id, typeId, description, value, dueDay, isRecurrent, payInAdvance, month, year, recurrenceId,
               bestBuyDay, cardBrand, cardBank, cardLimit, cardColor, cardId, observation,
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

    // Se não tiver ID, não pode fazer update
    if (categoria.id == null) {
      debugPrint('[DB] ERRO: Tentativa de UPDATE sem ID! Categoria: ${categoria.categoria}');
      return 0;
    }

    // Não incluir o ID nos dados de atualização, apenas usar no WHERE
    final dataToUpdate = {
      'accountId': categoria.accountId,
      'description': categoria.categoria,
      'logo': categoria.logo, // ✅ INCLUINDO O LOGO!
    };

    debugPrint('[DB] UPDATE categoria ID=${categoria.id}: "${categoria.categoria}", logo=${categoria.logo}');

    final rowsAffected = await db.update(
      'account_descriptions',
      dataToUpdate,
      where: 'id = ?',
      whereArgs: [categoria.id],
    );

    debugPrint('[DB] UPDATE resultado: $rowsAffected linhas afetadas');
    return rowsAffected;
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

  /// Retorna todas as contas EXCLUINDO despesas de cartão e cartões de crédito
  /// Usado pelo calendário para não duplicar lançamentos de cartão
  Future<List<Account>> readAllAccountsExcludingCardExpenses() async {
    final db = await database;
    // Excluir:
    // - Despesas de cartão (cardId preenchido)
    // - Cartões de crédito (cardBrand preenchido)
    final maps = await db.rawQuery('''
      SELECT * FROM accounts
      WHERE cardId IS NULL
        AND cardBrand IS NULL
    ''');
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
      where:
          'cardBrand IS NOT NULL AND recurrenceId IS NULL AND (month IS NULL OR month = 0) AND (year IS NULL OR year = 0)',
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
    // Buscar TODOS os pagamentos das contas, sem filtrar por data do pagamento
    // O que importa é se a conta (ID) tem um pagamento registrado
    final result = await db.rawQuery('''
      SELECT p.account_id, p.id, p.payment_date, pm.name as method_name, p.created_at
      FROM payments p
      INNER JOIN payment_methods pm ON p.payment_method_id = pm.id
      WHERE p.account_id IN ($placeholders)
      ORDER BY p.account_id, p.created_at DESC
    ''', [...accountIds]);

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
    // Somar TODOS os pagamentos das contas, sem filtrar por data
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(p.value), 0) as total
      FROM payments p
      WHERE p.account_id IN ($placeholders)
    ''', [...accountIds]);

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

  // ========== MÉTODOS COM SYNC TRACKING ==========

  /// Cria uma conta com tracking de sincronização
  Future<int> createAccountWithSync(Account account) async {
    final db = await database;
    final map = account.toMap();
    map['sync_status'] = SyncStatus.pendingCreate.value;
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.insert('accounts', map);
  }

  /// Atualiza uma conta com tracking de sincronização
  Future<int> updateAccountWithSync(Account account) async {
    final db = await database;
    final map = account.toMap();
    // Só marca como pendingUpdate se já estava synced
    final current = await getAccountById(account.id);
    if (current != null) {
      final currentStatus = await _getAccountSyncStatus(account.id!);
      if (currentStatus == SyncStatus.synced) {
        map['sync_status'] = SyncStatus.pendingUpdate.value;
      }
      // Se já está pending, mantém o status atual
    }
    map['updated_at'] = DateTime.now().toIso8601String();
    return await db.update(
      'accounts',
      map,
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  /// Deleta uma conta com soft delete para sincronização
  Future<int> deleteAccountWithSync(int id) async {
    final db = await database;
    final currentStatus = await _getAccountSyncStatus(id);

    // Se ainda não foi sincronizado (pendingCreate), pode deletar direto
    if (currentStatus == SyncStatus.pendingCreate) {
      return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    }

    // Se já está no servidor, marca para exclusão
    return await db.update(
      'accounts',
      {
        'sync_status': SyncStatus.pendingDelete.value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtém o status de sync de uma conta
  Future<SyncStatus> _getAccountSyncStatus(int id) async {
    final db = await database;
    final result = await db.query(
      'accounts',
      columns: ['sync_status'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return SyncStatus.synced;
    return SyncStatus.fromValue(result.first['sync_status'] as int?);
  }

  /// Busca registros pendentes de sincronização
  Future<List<Map<String, dynamic>>> getPendingRecords(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status != ?',
      whereArgs: [SyncStatus.synced.value],
    );
  }

  /// Busca registros pendentes de criação
  Future<List<Map<String, dynamic>>> getPendingCreates(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingCreate.value],
    );
  }

  /// Busca registros pendentes de atualização
  Future<List<Map<String, dynamic>>> getPendingUpdates(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingUpdate.value],
    );
  }

  /// Busca registros pendentes de exclusão
  Future<List<Map<String, dynamic>>> getPendingDeletes(String table) async {
    final db = await database;
    return await db.query(
      table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingDelete.value],
    );
  }

  /// Marca registro como sincronizado
  Future<void> markAsSynced(String table, int localId, String serverId) async {
    final db = await database;
    await db.update(
      table,
      {
        'sync_status': SyncStatus.synced.value,
        'server_id': serverId,
        'last_synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Obtém o ID local de um registro pelo server_id
  /// Usado para resolver referências FK no pull
  Future<int?> getLocalIdFromServerId(String table, String serverId) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: ['id'],
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['id'] as int?;
  }

  /// Converte valor para String para busca de server_id
  String? _toServerIdString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  /// Resolve referências FK do servidor para IDs locais (usado no pull)
  /// O servidor retorna IDs como integers, então precisamos converter para string
  /// para buscar o registro local pelo server_id
  Future<Map<String, dynamic>> resolveServerReferencesToLocal(
    String table,
    Map<String, dynamic> serverData,
  ) async {
    final resolved = Map<String, dynamic>.from(serverData);

    if (table == 'account_descriptions') {
      // Resolver accountId (FK para account_types)
      final accountIdStr = _toServerIdString(serverData['accountId']);
      if (accountIdStr != null) {
        final localAccountTypeId = await getLocalIdFromServerId('account_types', accountIdStr);
        if (localAccountTypeId != null) {
          resolved['accountId'] = localAccountTypeId;
        } else {
          debugPrint('⚠️ [PULL] accountId (account_type) $accountIdStr não encontrado localmente');
        }
      }
    } else if (table == 'accounts') {
      // Resolver typeId (server_id → local id)
      final typeIdStr = _toServerIdString(serverData['typeId']);
      if (typeIdStr != null) {
        final localTypeId = await getLocalIdFromServerId('account_types', typeIdStr);
        if (localTypeId != null) {
          resolved['typeId'] = localTypeId;
        } else {
          debugPrint('⚠️ [PULL] typeId $typeIdStr não encontrado localmente');
        }
      }

      // Resolver categoryId
      final categoryIdStr = _toServerIdString(serverData['categoryId']);
      if (categoryIdStr != null) {
        final localCategoryId = await getLocalIdFromServerId('account_descriptions', categoryIdStr);
        resolved['categoryId'] = localCategoryId; // pode ser null
      }

      // Resolver cardId (self-reference)
      final cardIdStr = _toServerIdString(serverData['cardId']);
      if (cardIdStr != null) {
        final localCardId = await getLocalIdFromServerId('accounts', cardIdStr);
        resolved['cardId'] = localCardId; // pode ser null se cartão ainda não sincronizado
      }
    } else if (table == 'payments') {
      // Resolver account_id
      final accountIdStr = _toServerIdString(serverData['account_id']);
      if (accountIdStr != null) {
        final localAccountId = await getLocalIdFromServerId('accounts', accountIdStr);
        if (localAccountId != null) {
          resolved['account_id'] = localAccountId;
        } else {
          debugPrint('⚠️ [PULL] account_id $accountIdStr não encontrado localmente');
        }
      }

      // Resolver payment_method_id
      final paymentMethodIdStr = _toServerIdString(serverData['payment_method_id']);
      if (paymentMethodIdStr != null) {
        final localMethodId = await getLocalIdFromServerId('payment_methods', paymentMethodIdStr);
        if (localMethodId != null) {
          resolved['payment_method_id'] = localMethodId;
        } else {
          debugPrint('⚠️ [PULL] payment_method_id $paymentMethodIdStr não encontrado localmente');
        }
      }

      // Resolver bank_account_id
      final bankAccountIdStr = _toServerIdString(serverData['bank_account_id']);
      if (bankAccountIdStr != null) {
        final localBankId = await getLocalIdFromServerId('banks', bankAccountIdStr);
        resolved['bank_account_id'] = localBankId; // pode ser null
      }

      // Resolver credit_card_id
      final creditCardIdStr = _toServerIdString(serverData['credit_card_id']);
      if (creditCardIdStr != null) {
        final localCardId = await getLocalIdFromServerId('accounts', creditCardIdStr);
        resolved['credit_card_id'] = localCardId; // pode ser null
      }
    }

    return resolved;
  }

  /// Aplica dados do servidor (server wins)
  Future<void> applyServerData(String table, Map<String, dynamic> serverData) async {
    final db = await database;
    // Converter id para String (servidor pode retornar int ou String)
    final rawId = serverData['id'];
    final serverId = rawId?.toString();
    if (serverId == null || serverId.isEmpty) return;

    // Resolver referências FK do servidor para IDs locais
    final resolvedData = await resolveServerReferencesToLocal(table, serverData);

    // Buscar registro local pelo server_id
    final local = await db.query(
      table,
      where: 'server_id = ?',
      whereArgs: [serverId],
      limit: 1,
    );

    resolvedData['sync_status'] = SyncStatus.synced.value;
    resolvedData['last_synced_at'] = DateTime.now().toIso8601String();
    resolvedData['server_id'] = serverId;
    resolvedData.remove('id'); // Remover ID do servidor

    if (local.isEmpty) {
      // Novo registro do servidor
      await db.insert(table, resolvedData);
    } else {
      // Atualizar registro existente (server wins)
      await db.update(
        table,
        resolvedData,
        where: 'server_id = ?',
        whereArgs: [serverId],
      );
    }
  }

  /// Deleta registro que foi deletado no servidor
  Future<void> deleteByServerId(String table, String serverId) async {
    final db = await database;
    await db.delete(table, where: 'server_id = ?', whereArgs: [serverId]);
  }

  /// Remove registros marcados para exclusão após sync
  Future<void> purgePendingDeletes(String table) async {
    final db = await database;
    await db.delete(
      table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pendingDelete.value],
    );
  }

  // ========== SYNC METADATA ==========

  /// Obtém metadados de sync para uma tabela
  Future<SyncMetadata?> getSyncMetadata(String tableName) async {
    final db = await database;
    final result = await db.query(
      'sync_metadata',
      where: 'table_name = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return SyncMetadata.fromMap(result.first);
  }

  /// Atualiza metadados de sync para uma tabela
  Future<void> updateSyncMetadata(
    String tableName,
    String serverTimestamp, {
    String? userId,
  }) async {
    final db = await database;
    final existing = await getSyncMetadata(tableName);

    final data = {
      'table_name': tableName,
      'last_sync_at': DateTime.now().toIso8601String(),
      'last_server_timestamp': serverTimestamp,
      if (userId != null) 'user_id': userId,
    };

    if (existing == null) {
      await db.insert('sync_metadata', data);
    } else {
      await db.update(
        'sync_metadata',
        data,
        where: 'table_name = ?',
        whereArgs: [tableName],
      );
    }
  }

  /// Limpa metadados de sync (usado no logout)
  Future<void> clearSyncMetadata() async {
    final db = await database;
    await db.delete('sync_metadata');
  }

  /// Conta registros pendentes de sync
  Future<int> countPendingSync() async {
    final db = await database;
    int total = 0;
    for (final table in SyncTables.all) {
      try {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE sync_status != ?',
          [SyncStatus.synced.value],
        );
        total += (result.first['count'] as int?) ?? 0;
      } catch (_) {
        // Tabela pode não existir ainda
      }
    }
    return total;
  }

  /// Reseta todos os status de sync para pendingCreate
  Future<void> resetAllSyncStatus() async {
    final db = await database;
    for (final table in SyncTables.all) {
      try {
        await db.update(
          table,
          {'sync_status': SyncStatus.pendingCreate.value, 'server_id': null},
        );
      } catch (_) {
        // Tabela pode não existir
      }
    }
    await clearSyncMetadata();
  }

  /// Obtém o server_id de um registro pelo ID local
  /// Usado para resolver referências FK antes do push
  Future<String?> getServerIdFromLocalId(String table, int localId) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: ['server_id'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return result.first['server_id'] as String?;
  }

  /// Resolve referências FK de account_descriptions para server_id
  /// Converte accountId local para server_id do account_type
  Future<Map<String, dynamic>> resolveAccountDescriptionReferences(
    Map<String, dynamic> descData,
  ) async {
    final resolved = Map<String, dynamic>.from(descData);

    // Resolver accountId (referência ao tipo de conta)
    final accountId = descData['accountId'];
    if (accountId != null && accountId is int) {
      final accountTypeServerId = await getServerIdFromLocalId('account_types', accountId);
      if (accountTypeServerId != null) {
        resolved['accountId'] = accountTypeServerId;
      } else {
        debugPrint('⚠️ accountId (account_type) $accountId não tem server_id ainda');
      }
    }

    return resolved;
  }

  /// Resolve referências FK de accounts para server_id
  /// Converte IDs locais para server_id das tabelas relacionadas
  Future<Map<String, dynamic>> resolveAccountReferences(
    Map<String, dynamic> accountData,
  ) async {
    final resolved = Map<String, dynamic>.from(accountData);

    // Resolver typeId (referência ao tipo de conta)
    final typeId = accountData['typeId'];
    if (typeId != null && typeId is int) {
      final typeServerId = await getServerIdFromLocalId('account_types', typeId);
      if (typeServerId != null) {
        resolved['typeId'] = typeServerId;
      } else {
        debugPrint('⚠️ typeId $typeId não tem server_id ainda');
      }
    }

    // Resolver categoryId (referência à descrição/categoria)
    final categoryId = accountData['categoryId'];
    if (categoryId != null && categoryId is int) {
      final categoryServerId = await getServerIdFromLocalId('account_descriptions', categoryId);
      if (categoryServerId != null) {
        resolved['categoryId'] = categoryServerId;
      } else {
        debugPrint('⚠️ categoryId $categoryId não tem server_id ainda, removendo referência');
        resolved.remove('categoryId');
      }
    }

    // Resolver cardId (referência ao cartão de crédito pai)
    final cardId = accountData['cardId'];
    if (cardId != null && cardId is int) {
      final cardServerId = await getServerIdFromLocalId('accounts', cardId);
      if (cardServerId != null) {
        resolved['cardId'] = cardServerId;
      } else {
        // Cartão pai ainda não foi sincronizado
        // Remover referência para evitar erro - será resolvido na próxima sync
        debugPrint('⚠️ cardId $cardId não tem server_id ainda, removendo referência');
        resolved.remove('cardId');
      }
    }

    return resolved;
  }

  /// Resolve referências FK de payments para server_id
  /// Converte IDs locais para server_id das tabelas relacionadas
  Future<Map<String, dynamic>> resolvePaymentReferences(
    Map<String, dynamic> paymentData,
  ) async {
    final resolved = Map<String, dynamic>.from(paymentData);

    // Resolver account_id (referência à conta)
    final accountId = paymentData['account_id'];
    if (accountId != null && accountId is int) {
      final accountServerId = await getServerIdFromLocalId('accounts', accountId);
      if (accountServerId != null) {
        resolved['account_id'] = accountServerId;
      } else {
        debugPrint('⚠️ account_id $accountId não tem server_id ainda');
      }
    }

    // Resolver payment_method_id (referência ao método de pagamento)
    final paymentMethodId = paymentData['payment_method_id'];
    if (paymentMethodId != null && paymentMethodId is int) {
      final methodServerId = await getServerIdFromLocalId('payment_methods', paymentMethodId);
      if (methodServerId != null) {
        resolved['payment_method_id'] = methodServerId;
      } else {
        debugPrint('⚠️ payment_method_id $paymentMethodId não tem server_id ainda');
      }
    }

    // Resolver bank_account_id (referência ao banco)
    final bankAccountId = paymentData['bank_account_id'];
    if (bankAccountId != null && bankAccountId is int) {
      final bankServerId = await getServerIdFromLocalId('banks', bankAccountId);
      if (bankServerId != null) {
        resolved['bank_account_id'] = bankServerId;
      } else {
        debugPrint('⚠️ bank_account_id $bankAccountId não tem server_id ainda, removendo referência');
        resolved.remove('bank_account_id');
      }
    }

    // Resolver credit_card_id (referência ao cartão de crédito)
    final creditCardId = paymentData['credit_card_id'];
    if (creditCardId != null && creditCardId is int) {
      final cardServerId = await getServerIdFromLocalId('accounts', creditCardId);
      if (cardServerId != null) {
        resolved['credit_card_id'] = cardServerId;
      } else {
        debugPrint('⚠️ credit_card_id $creditCardId não tem server_id ainda, removendo referência');
        resolved.remove('credit_card_id');
      }
    }

    return resolved;
  }
}
