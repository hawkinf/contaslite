import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../models/payment_method.dart';
import 'default_account_categories_service.dart';
import 'database_protection_service.dart';

class DatabaseInitializationService {
  static final DatabaseInitializationService instance =
      DatabaseInitializationService._();
  DatabaseInitializationService._();

  Future<void> initializeDatabase() async {
    try {
      debugPrint('[DB INIT] Iniciando verificacao do banco de dados...');
      final stopwatch = Stopwatch()..start();
      final db = DatabaseHelper.instance;

      // Consultas rapidas sequenciais para evitar disputa na abertura do banco
      int typeCount = await db.countAccountTypes();
      int methodCount = await db.countPaymentMethods(onlyActive: false);

      debugPrint('[DB INIT] Tipos de conta encontrados: $typeCount');
      debugPrint('[DB INIT] Formas de pagamento encontradas: $methodCount');

      if (typeCount == 0) {
        debugPrint('[DB INIT] Banco vazio detectado. Inicializando com categorias padrao...');
      }

      await populateDefaultData();

      typeCount = await db.countAccountTypes();
      methodCount = await db.countPaymentMethods(onlyActive: false);
      if (typeCount > 0 && methodCount > 0) {
        debugPrint('[DB INIT] Banco de dados inicializado com sucesso!');
      }

      // Validar integridade do banco
      debugPrint('[DB INIT] Validando integridade do banco de dados...');
      try {
        final integrityResult =
            await DatabaseProtectionService.instance.validateIntegrity();
        if (integrityResult.isValid) {
          debugPrint('✓ [DB INIT] Integridade do banco: OK');
        } else {
          debugPrint('⚠️ [DB INIT] AVISO: Banco com problemas detectados');
          for (final error in integrityResult.errors) {
            debugPrint('  ❌ $error');
          }
          for (final warning in integrityResult.warnings) {
            debugPrint('  ⚠️ $warning');
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DB INIT] Erro ao validar integridade: $e');
      }

      final elapsedMs = stopwatch.elapsedMilliseconds;
      debugPrint('[DB INIT] Banco pronto com $typeCount tipo(s) e $methodCount forma(s) (${elapsedMs}ms).');
    } catch (e, st) {
      debugPrint('[DB INIT] ERRO ao inicializar banco de dados: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> populateDefaultData() async {
    try {
      debugPrint('[DB INIT] Populando dados padrao...');
      final db = DatabaseHelper.instance;
      final defaultService = DefaultAccountCategoriesService.instance;
      final categoriesMap = defaultService.getCategoriesAsMap();
      final existingTypes = await db.readAllTypes();
      final typeIdByName = <String, int>{
        for (final type in existingTypes)
          type.name.trim().toUpperCase(): type.id!,
      };

      debugPrint('[DB INIT] Criando ${categoriesMap.length} tipos de conta com subcategorias...');
      int typesCreated = 0;
      int categoriesCreated = 0;

      // Criar tipos padrao com suas categorias
      for (final typeName in categoriesMap.keys) {
        final normalizedName = typeName.trim().toUpperCase();
        final typeId = typeIdByName[normalizedName] ??
            await db.createType(AccountType(name: typeName));
        if (!typeIdByName.containsKey(normalizedName)) {
          typeIdByName[normalizedName] = typeId;
          typesCreated++;
          debugPrint('  -> Tipo "$typeName" criado (ID: $typeId)');
        } else {
          debugPrint('  -> Tipo "$typeName" ja existe (ID: $typeId)');
        }

        final subcategories = categoriesMap[typeName]!;
        final existingCategories = await db.readAccountCategories(typeId);
        final existingNames = existingCategories
            .map((c) => c.categoria.trim().toUpperCase())
            .toSet();

        int addedForType = 0;
        for (final subcategory in subcategories) {
          final normalizedSub = subcategory.trim().toUpperCase();
          if (existingNames.contains(normalizedSub)) continue;
          final category = AccountCategory(
            accountId: typeId,
            categoria: subcategory,
          );
          await db.createAccountCategory(category);
          existingNames.add(normalizedSub);
          categoriesCreated++;
          addedForType++;
          debugPrint('    -> Subcategoria: "$subcategory"');
        }

        if (normalizedName ==
            DefaultAccountCategoriesService.recebimentosName.toUpperCase()) {
          for (final entry
              in DefaultAccountCategoriesService.recebimentosChildDefaults.entries) {
            final parentName = entry.key;
            final parentNormalized = parentName.trim().toUpperCase();
            if (!existingNames.contains(parentNormalized)) {
              await db.createAccountCategory(
                AccountCategory(accountId: typeId, categoria: parentName),
              );
              existingNames.add(parentNormalized);
              categoriesCreated++;
              addedForType++;
              debugPrint('    -> Subcategoria: "$parentName"');
            }

            for (final child in entry.value) {
              final fullName =
                  defaultService.buildRecebimentosChildName(parentName, child);
              final fullNormalized = fullName.trim().toUpperCase();
              if (existingNames.contains(fullNormalized)) continue;
              await db.createAccountCategory(
                AccountCategory(accountId: typeId, categoria: fullName),
              );
              existingNames.add(fullNormalized);
              categoriesCreated++;
              addedForType++;
              debugPrint('      -> Filho: "$child"');
            }
          }
        }

        if (addedForType == 0) {
          debugPrint('    - Nenhuma subcategoria nova para "$typeName"');
        } else {
          debugPrint('    - Total: $addedForType subcategorias adicionadas');
        }
      }

      debugPrint('[DB INIT] Tipos criados: $typesCreated | Subcategorias criadas: $categoriesCreated');

      // Criar formas de pagamento padrao
      debugPrint('[DB INIT] Populando formas de pagamento...');
      await populatePaymentMethods(db);

      debugPrint('[DB INIT] Dados padrao populados com sucesso!');
    } catch (e, st) {
      debugPrint('[DB INIT] ERRO ao popular dados padrao: $e');
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
