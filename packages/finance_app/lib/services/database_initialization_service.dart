import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../models/payment_method.dart';
import 'default_account_categories_service.dart';

class DatabaseInitializationService {
  static final DatabaseInitializationService instance =
      DatabaseInitializationService._();
  DatabaseInitializationService._();

  Future<void> initializeDatabase() async {
    try {
      debugPrint('🔍 [DB INIT] Iniciando verificação do banco de dados...');
      final stopwatch = Stopwatch()..start();
      final db = DatabaseHelper.instance;

      // Consultas rápidas sequenciais para evitar disputa na abertura do banco
      int typeCount = await db.countAccountTypes();
      int methodCount = await db.countPaymentMethods(onlyActive: false);

      debugPrint('📊 [DB INIT] Tipos de conta encontrados: $typeCount');
      debugPrint('💳 [DB INIT] Formas de pagamento encontradas: $methodCount');

      if (typeCount == 0) {
        debugPrint('📦 [DB INIT] Banco vazio detectado. Inicializando com categorias padrão...');
        await populateDefaultData();
        typeCount = await db.countAccountTypes();
        methodCount = await db.countPaymentMethods(onlyActive: false);
        debugPrint('✅ [DB INIT] Banco de dados inicializado com sucesso!');
      } else if (methodCount == 0) {
        debugPrint('📦 [DB INIT] Nenhuma forma de pagamento ativa encontrada. Recriando padrão...');
        await populatePaymentMethods(db);
        methodCount = await db.countPaymentMethods(onlyActive: false);
      }

      final elapsedMs = stopwatch.elapsedMilliseconds;
      debugPrint('✓ [DB INIT] Banco pronto com $typeCount tipo(s) e $methodCount forma(s) (⏱ ${elapsedMs}ms).');
    } catch (e, st) {
      debugPrint('❌ [DB INIT] ERRO ao inicializar banco de dados: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> populateDefaultData() async {
    try {
      debugPrint('📦 [DB INIT] Populando dados padrão...');
      final db = DatabaseHelper.instance;
      final defaultService = DefaultAccountCategoriesService.instance;
      final categoriesMap = defaultService.getCategoriesAsMap();

      debugPrint('📦 [DB INIT] Criando ${categoriesMap.length} tipos de conta com subcategorias...');
      int typesCreated = 0;
      int categoriesCreated = 0;

      // Criar tipos padrão com suas categorias
      for (final typeName in categoriesMap.keys) {
        final exists = await db.checkAccountTypeExists(typeName);
        if (!exists) {
          final newType = AccountType(name: typeName);
          final typeId = await db.createType(newType);
          typesCreated++;
          
          // Adicionar subcategorias para este tipo
          final subcategories = categoriesMap[typeName]!;
          debugPrint('  ├─ Tipo "$typeName" criado (ID: $typeId)');
          
          for (final subcategory in subcategories) {
            final category = AccountCategory(
              accountId: typeId,
              categoria: subcategory,
            );
            await db.createAccountCategory(category);
            categoriesCreated++;
            debugPrint('    ├─ Subcategoria: "$subcategory"');
          }
          debugPrint('    └─ Total: ${subcategories.length} subcategorias');
        } else {
          debugPrint('  ├─ Tipo "$typeName" já existe (pulado)');
        }
      }

      debugPrint('✓ [DB INIT] Tipos criados: $typesCreated | Subcategorias criadas: $categoriesCreated');

      // Criar formas de pagamento padrão
      debugPrint('💳 [DB INIT] Populando formas de pagamento...');
      await populatePaymentMethods(db);
      
      debugPrint('✅ [DB INIT] Dados padrão populados com sucesso!');
    } catch (e, st) {
      debugPrint('❌ [DB INIT] ERRO ao popular dados padrão: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> populatePaymentMethods(DatabaseHelper db) async {
    final methods = [
      PaymentMethod(
        name: 'Dinheiro',
        type: 'CASH',
        iconCode: 0xe25a,
        requiresBank: false,
        isActive: true,
      ),
      PaymentMethod(
        name: 'PIX',
        type: 'PIX',
        iconCode: 0xe8d0,
        requiresBank: true,
        isActive: true,
      ),
      PaymentMethod(
        name: 'Débito C/C',
        type: 'BANK_DEBIT',
        iconCode: 0xe25c,
        requiresBank: true,
        isActive: true,
      ),
      PaymentMethod(
        name: 'Cartão Crédito',
        type: 'CREDIT_CARD',
        iconCode: 0xe25e,
        requiresBank: false,
        isActive: true,
      ),
    ];

    final existing = (await db.readPaymentMethods(onlyActive: false))
        .map((m) => m.name.toUpperCase())
        .toSet();

    int methodsCreated = 0;
    for (final method in methods) {
      try {
        if (!existing.contains(method.name.toUpperCase())) {
          await db.createPaymentMethod(method);
          methodsCreated++;
          debugPrint('  ├─ Forma de pagamento "${method.name}" criada');
        } else {
          debugPrint('  ├─ Forma de pagamento "${method.name}" já existe (pulada)');
        }
      } catch (e) {
        debugPrint('⚠️  [DB INIT] Erro ao criar forma de pagamento "${method.name}": $e');
      }
    }
    debugPrint('✓ [DB INIT] Formas de pagamento criadas: $methodsCreated');
  }
}
