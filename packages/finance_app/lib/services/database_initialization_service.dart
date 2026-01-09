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
      debugPrint('[DB INIT] Iniciando verificacao do banco de dados...');
      final stopwatch = Stopwatch()..start();
      final db = DatabaseHelper.instance;

      // Consultas rapidas sequenciais para evitar disputa na abertura do banco
      int typeCount = 0;
      int methodCount = 0;

      try {
        typeCount = await db.countAccountTypes();
      } catch (e) {
        debugPrint('[DB INIT] ?? Erro ao contar tipos de conta: $e');
        typeCount = 0;
      }

      try {
        methodCount = await db.countPaymentMethods(onlyActive: false);
      } catch (e) {
        debugPrint('[DB INIT] ?? Erro ao contar formas de pagamento: $e');
        methodCount = 0;
      }

      debugPrint('[DB INIT] Tipos de conta encontrados: $typeCount');
      debugPrint('[DB INIT] Formas de pagamento encontradas: $methodCount');

      // SOMENTE popular dados padrão se o banco estiver VAZIO (primeiro uso)
      // Não recriar categorias em todo startup - isso sobrescreve edições do usuário!
      if (typeCount == 0 && methodCount == 0) {
        debugPrint('[DB INIT] Banco vazio detectado. Inicializando com categorias padrao...');
        await populateDefaultData();

        typeCount = await db.countAccountTypes();
        methodCount = await db.countPaymentMethods(onlyActive: false);
        debugPrint('[DB INIT] Banco de dados inicializado com sucesso!');
      } else {
        debugPrint('[DB INIT] Banco ja possui dados. Pulando populacao automatica.');
      }

      // Validar integridade do banco (skip por agora - pode travar em algumas situa‡äes)
      debugPrint('[DB INIT] Valida‡Æo de integridade skipped durante inicializa‡Æo');

      final elapsedMs = stopwatch.elapsedMilliseconds;
      debugPrint(
          '[DB INIT] Banco pronto com $typeCount tipo(s) e $methodCount forma(s) (${elapsedMs}ms).');
    } catch (e, st) {
      debugPrint('[DB INIT] ERRO ao inicializar banco de dados: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<void> populateDefaultData({String tipoPessoa = 'Ambos (PF e PJ)'}) async {
    try {
      debugPrint('[DB INIT] Populando dados padrao (Tipo: $tipoPessoa)...');
      final db = DatabaseHelper.instance;
      final defaultService = DefaultAccountCategoriesService.instance;
      final categoriesMap = defaultService.getCategoriesAsMap(tipoPessoa: tipoPessoa);
      final existingTypes = await db.readAllTypes();
      final typeIdByName = <String, int>{
        for (final type in existingTypes) type.name.trim().toUpperCase(): type.id!,
      };

      debugPrint('[DB INIT] Criando ${categoriesMap.length} tipos de conta com subcategorias...');
      int typesCreated = 0;
      int categoriesCreated = 0;

      // Criar tipos padrao com suas categorias
      for (final typeName in categoriesMap.keys) {
        final normalizedName = typeName.trim().toUpperCase();
        final typeId =
            typeIdByName[normalizedName] ?? await db.createType(AccountType(name: typeName));
        if (!typeIdByName.containsKey(normalizedName)) {
          typeIdByName[normalizedName] = typeId;
          typesCreated++;
          debugPrint('  -> Tipo "$typeName" criado (ID: $typeId)');
        } else {
          debugPrint('  -> Tipo "$typeName" ja existe (ID: $typeId)');
        }

        final subcategories = categoriesMap[typeName]!;
        final existingCategories = await db.readAccountCategories(typeId);
        final existingNames =
            existingCategories.map((c) => c.categoria.trim().toUpperCase()).toSet();

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
          final recebimentosChildren = defaultService.getRecebimentosChildDefaults(tipoPessoa: tipoPessoa);
          for (final entry in recebimentosChildren.entries) {
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

      debugPrint(
          '[DB INIT] Tipos criados: $typesCreated | Subcategorias criadas: $categoriesCreated');

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
    final canonicalMethods = [
      PaymentMethod(
        name: 'Cartão de Credito',
        type: 'CREDIT_CARD',
        iconCode: 0xe25e,
        requiresBank: false,
        isActive: true,
        usage: PaymentMethodUsage.pagamentos,
      ),
      PaymentMethod(
        name: 'Crédito em conta',
        type: 'PIX',
        iconCode: 0xe8d0,
        requiresBank: true,
        isActive: true,
        usage: PaymentMethodUsage.recebimentos,
      ),
      PaymentMethod(
        name: 'Dinheiro',
        type: 'CASH',
        iconCode: 0xe25a,
        requiresBank: false,
        isActive: true,
        usage: PaymentMethodUsage.pagamentosRecebimentos,
      ),
      PaymentMethod(
        name: 'Débito C/C',
        type: 'BANK_DEBIT',
        iconCode: 0xe25c,
        requiresBank: true,
        isActive: true,
        usage: PaymentMethodUsage.pagamentos,
      ),
      PaymentMethod(
        name: 'Internet Banking',
        type: 'BANK_DEBIT',
        iconCode: 0xe25c,
        requiresBank: true,
        isActive: true,
        usage: PaymentMethodUsage.pagamentos,
      ),
      PaymentMethod(
        name: 'PIX',
        type: 'PIX',
        iconCode: 0xe8d0,
        requiresBank: true,
        isActive: true,
        usage: PaymentMethodUsage.pagamentosRecebimentos,
      ),
    ];

    final existingMethods = await db.readPaymentMethods(onlyActive: false);
    final existingByUpperName = <String, PaymentMethod>{};
    for (final method in existingMethods) {
      existingByUpperName[method.name.toUpperCase()] = method;
    }

    final methodByName = <String, PaymentMethod>{
      for (final method in canonicalMethods) method.name: method,
    };

    // Normaliza defaults antigos (nomes com encoding antigo/variações) sem sobrescrever métodos customizados.
    final legacyToCanonicalName = <String, String>{
      'CARTÃO DE CREDITO': 'Cartão de Credito',
      'CARTAO DE CREDITO': 'Cartão de Credito',
      'CARTÃO DE CRÉDITO': 'Cartão de Credito',
      'CARTAO DE CRÉDITO': 'Cartão de Credito',
      'CARTÃO CRÉDITO': 'Cartão de Credito',
      'CARTAO CREDITO': 'Cartão de Credito',
      'CARTÃO CREDITO': 'Cartão de Credito',
      'CARTÆO CR‚DITO': 'Cartão de Credito',
      'CRÉDITO EM CONTA': 'Crédito em conta',
      'CREDITO EM CONTA': 'Crédito em conta',
      'DÉBITO C/C': 'Débito C/C',
      'DEBITO C/C': 'Débito C/C',
      'D‚BITO C/C': 'Débito C/C',
    };

    for (final entry in legacyToCanonicalName.entries) {
      final legacyUpper = entry.key;
      final canonicalName = entry.value;
      final canonical = methodByName[canonicalName];
      final legacy = existingByUpperName[legacyUpper];
      if (canonical == null || legacy == null) continue;

      if (existingByUpperName.containsKey(canonicalName.toUpperCase())) continue;

      try {
        await db.updatePaymentMethod(
          legacy.copyWith(
            name: canonical.name,
            type: canonical.type,
            iconCode: canonical.iconCode,
            requiresBank: canonical.requiresBank,
            isActive: canonical.isActive,
            usage: canonical.usage,
          ),
        );
      } catch (e) {
        debugPrint('??  [DB INIT] Erro ao normalizar forma "${legacy.name}": $e');
      }
    }

    final existing =
        (await db.readPaymentMethods(onlyActive: false)).map((m) => m.name.toUpperCase()).toSet();

    int methodsCreated = 0;
    for (final method in canonicalMethods) {
      try {
        if (!existing.contains(method.name.toUpperCase())) {
          await db.createPaymentMethod(method);
          methodsCreated++;
          debugPrint('  ÃÄ Forma de pagamento/recebimento "${method.name}" criada');
        } else {
          debugPrint('  ÃÄ Forma de pagamento/recebimento "${method.name}" j  existe (pulada)');
        }
      } catch (e) {
        debugPrint(
            '??  [DB INIT] Erro ao criar forma de pagamento/recebimento "${method.name}": $e');
      }
    }
    debugPrint('V [DB INIT] Formas de pagamento/recebimento criadas: $methodsCreated');
  }
}
