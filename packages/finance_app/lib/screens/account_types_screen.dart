import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/prefs_service.dart';
import '../services/credit_card_brand_service.dart';
import '../services/default_account_categories_service.dart';
import 'recebimentos_table_screen.dart';

/// Opções de tipo de pessoa para seleção
const List<String> tipoPessoaOptions = [
  'Pessoa Física',
  'Pessoa Jurídica',
  'Ambos (PF e PJ)',
];

class AccountTypesScreen extends StatefulWidget {
  const AccountTypesScreen({super.key});

  @override
  State<AccountTypesScreen> createState() => _AccountTypesScreenState();
}

class _AccountTypesScreenState extends State<AccountTypesScreen> {
  List<AccountType> types = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future refreshData() async {
    setState(() => isLoading = true);
    types = await DatabaseHelper.instance.readAllTypes();
    setState(() => isLoading = false);
  }

  /// Atribui ícones inteligentes baseados na descrição de cada categoria
  /// Garantindo que não haja repetição dentro do mesmo tipo pai
  Future<void> _assignIntelligentLogos() async {
    try {
      int updatedTypes = 0;
      int updatedCategories = 0;
      
      debugPrint('🎨 [ATRIBUIR LOGOS INTELIGENTES] Iniciando...');
      
      // Para cada tipo de conta
      for (final type in types) {
        // 1. Atribuir logo ao tipo pai
        final parentLogo = DefaultAccountCategoriesService.getLogoForCategory(type.name);
        if (parentLogo != null && (type.logo == null || type.logo!.isEmpty)) {
          final updatedType = AccountType(id: type.id, name: type.name, logo: parentLogo);
          await DatabaseHelper.instance.updateType(updatedType);
          updatedTypes++;
          debugPrint('🎨 [TIPO] ${type.name} → logo=$parentLogo');
        }
        
        // 2. Buscar as categorias filhas deste tipo
        if (type.id != null) {
          final categories = await DatabaseHelper.instance.readAccountCategories(type.id!);
          final Set<String> usedLogos = {parentLogo ?? ''}; // Já usa o logo do pai
          
          debugPrint('  📋 ${categories.length} categorias para ${type.name}');
          
          // Para cada categoria filha
          for (final category in categories) {
            // Buscar um ícone baseado na descrição da categoria
            String? childLogo = DefaultAccountCategoriesService.getLogoForSubcategory(category.categoria);
            
            // Se o ícone já foi usado, tentar outro
            if (childLogo != null && usedLogos.contains(childLogo)) {
              debugPrint('    ⚠️  Logo $childLogo já usado, procurando alternativa...');
              // Tentar usar um logo genérico diferente
              childLogo = _findAlternativeLogo(category.categoria, usedLogos);
            }
            
            // SEMPRE atualizar o logo da categoria filha (mesmo que já tenha um)
            if (childLogo != null) {
              usedLogos.add(childLogo);
              final updatedCategory = category.copyWith(logo: childLogo);
              await DatabaseHelper.instance.updateAccountCategory(updatedCategory);
              updatedCategories++;
              debugPrint('    ✅ ${category.categoria} → logo=$childLogo');
            }
          }
        }
      }
      
      final total = updatedTypes + updatedCategories;
      debugPrint('🎨 [RESULTADO] $updatedTypes tipos, $updatedCategories categorias = $total total');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              total > 0 
                ? '$updatedCategories categorias com ícones atribuídos!'
                : 'Todas as categorias já têm ícones!'
            ),
            backgroundColor: total > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      await refreshData();
    } catch (e) {
      debugPrint('❌ [ERRO] Erro ao atribuir logos inteligentes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atribuir ícones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Encontra um ícone alternativo para uma categoria, garantindo que não se repita
  String? _findAlternativeLogo(String categoryName, Set<String> usedLogos) {
    // Lista de ícones alternativos em ordem de preferência
    final alternativeLogos = [
      '🏷️', '📌', '🎯', '✨', '💫', '🌟', '⭐', '✅', '📍', '🔖',
      '📊', '📈', '📉', '💹', '📐', '📏', '⏱️', '⏰', '🕐', '🕑',
      '🎪', '🎨', '🎭', '🎬', '🎤', '🎧', '🎵', '🎶', '🎸', '🎹',
    ];
    
    for (final logo in alternativeLogos) {
      if (!usedLogos.contains(logo)) {
        return logo;
      }
    }
    
    return null; // Se todos os ícones foram usados
  }
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contas a Pagar'),
          ),
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : types.isEmpty
                    ? _buildEmptyState()
                    : _buildTable(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Nenhuma tabela/categoria cadastrada.', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: () => _showTypeDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Nova Categoria'),
            ),
            FilledButton.icon(
              onPressed: _populateDefaults,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Popular'),
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Descrição', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
            ],
            rows: types.map((type) {
              return DataRow(cells: [
              DataCell(
                Row(
                  children: [
                    if (type.logo != null && type.logo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(type.logo!, style: const TextStyle(fontSize: 18)),
                      ),
                    Expanded(
                      child: Text(type.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                onTap: () => _showTypeDialog(typeToEdit: type),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Editar', onPressed: () => _showTypeDialog(typeToEdit: type)),
                    IconButton(
                      icon: const Icon(Icons.category, color: Colors.purple),
                      tooltip: 'Categorias',
                      onPressed: () {
                        if (type.name.toUpperCase() == 'RECEBIMENTOS') {
                          showDialog(
                            context: context,
                            builder: (ctx) => const RecebimentosTableScreen(asDialog: true),
                          );
                          return;
                        }
                        _showCategoriesDialog(type);
                      },
                    ),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: 'Excluir', onPressed: () => _confirmDelete(type)),
                  ],
                ),
              ),
            ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _showTypeDialog({AccountType? typeToEdit}) async {
    final isEditing = typeToEdit != null;
    final controller = TextEditingController(text: isEditing ? typeToEdit.name : '');
    final logoController = TextEditingController(text: isEditing ? (typeToEdit.logo ?? '') : '');
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Item' : 'Adicionar na Tabela',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Nome do Tipo',
                  icon: Icons.label,
                  hintText: 'Ex: Energia, Internet',
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Campo de Logo com botão para abrir picker
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logoController,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Logo (emoji ou texto)',
                        icon: Icons.image,
                        hintText: 'Ex: 🍔 ou 💳',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () async {
                      final selectedIcon = await showIconPickerDialog(
                        context,
                        initialIcon: logoController.text.isNotEmpty ? logoController.text : null,
                      );
                      if (selectedIcon != null) {
                        logoController.text = selectedIcon;
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.palette),
                    label: const Text('Picker'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      String name = controller.text.trim();
                      String logo = logoController.text.trim();
                      if (name.isNotEmpty) {
                        if (!isEditing || (isEditing && name.toUpperCase() != typeToEdit.name.toUpperCase())) {
                           bool exists = await DatabaseHelper.instance.checkAccountTypeExists(name);
                           if (exists) {
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Este nome já existe!'), backgroundColor: Colors.red));
                             }
                             return;
                           }
                        }

                        if (isEditing) {
                          final updatedType = AccountType(id: typeToEdit.id, name: name, logo: logo.isEmpty ? null : logo);
                          await DatabaseHelper.instance.updateType(updatedType);
                        } else {
                          await DatabaseHelper.instance.createType(AccountType(name: name, logo: logo.isEmpty ? null : logo));
                        }
                        
                        if (context.mounted) Navigator.pop(context);
                        refreshData();
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoriesDialog(AccountType type) async {
    final categorias = await DatabaseHelper.instance.readAccountCategories(type.id!);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _CategoriasManagementDialog(
        typeId: type.id!,
        typeName: type.name,
        categorias: categorias,
        onCategoriasUpdated: () {
          refreshData();
        },
      ),
    );
  }

  Future<void> _confirmDelete(AccountType type) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirma exclusão?'),
        content: Text('Isso apagará todas as contas vinculadas a "${type.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim, Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteType(type.id!);
      refreshData();
    }
  }

  Future<void> _populateDefaults() async {
    // Mostrar diálogo de seleção de tipo de pessoa
    final tipoPessoa = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = tipoPessoaOptions[2]; // Ambos (PF e PJ) como padrão
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Popular Categorias'),
            content: RadioGroup<String>(
              groupValue: selected,
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => selected = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selecione o tipo de pessoa:'),
                  const SizedBox(height: 16),
                  ...tipoPessoaOptions.map((option) => ListTile(
                        title: Text(option),
                        leading: Radio<String>(value: option),
                        onTap: () => setDialogState(() => selected = option),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Popular'),
              ),
            ],
          ),
        );
      },
    );

    if (tipoPessoa == null || !mounted) return;

    // Obter categorias do serviço com base no tipo selecionado
    final defaultService = DefaultAccountCategoriesService.instance;
    final categoriesMap = defaultService.getCategoriesAsMap(tipoPessoa: tipoPessoa);

    int typesCreated = 0;
    int categoriesCreated = 0;

    // Carregar todos os tipos existentes
    final existingTypes = await DatabaseHelper.instance.readAllTypes();
    final typeIdByName = <String, int>{
      for (final type in existingTypes) type.name.trim().toUpperCase(): type.id!,
    };

    // Criar tipos e subcategorias
    for (final typeName in categoriesMap.keys) {
      final normalizedName = typeName.trim().toUpperCase();
      int typeId;

      if (typeIdByName.containsKey(normalizedName)) {
        typeId = typeIdByName[normalizedName]!;
      } else {
        // Obter o ícone apropriado para esta categoria
        final logo = DefaultAccountCategoriesService.getLogoForCategory(typeName);
        typeId = await DatabaseHelper.instance.createType(
          AccountType(name: typeName, logo: logo),
        );
        typeIdByName[normalizedName] = typeId;
        typesCreated++;
      }

      // Criar subcategorias
      final subcategories = categoriesMap[typeName]!;
      final existingCategories = await DatabaseHelper.instance.readAccountCategories(typeId);
      final existingNames = existingCategories.map((c) => c.categoria.trim().toUpperCase()).toSet();

      for (final subcategory in subcategories) {
        final normalizedSub = subcategory.trim().toUpperCase();
        if (existingNames.contains(normalizedSub)) continue;

        await DatabaseHelper.instance.createAccountCategory(
          AccountCategory(accountId: typeId, categoria: subcategory),
        );
        existingNames.add(normalizedSub);
        categoriesCreated++;
      }

      // Se for Recebimentos, adicionar subcategorias filhas
      if (normalizedName == DefaultAccountCategoriesService.recebimentosName.toUpperCase()) {
        final recebimentosChildren = defaultService.getRecebimentosChildDefaults(tipoPessoa: tipoPessoa);
        for (final entry in recebimentosChildren.entries) {
          final parentName = entry.key;
          final parentNormalized = parentName.trim().toUpperCase();

          if (!existingNames.contains(parentNormalized)) {
            await DatabaseHelper.instance.createAccountCategory(
              AccountCategory(accountId: typeId, categoria: parentName),
            );
            existingNames.add(parentNormalized);
            categoriesCreated++;
          }

          for (final child in entry.value) {
            final fullName = defaultService.buildRecebimentosChildName(parentName, child);
            final fullNormalized = fullName.trim().toUpperCase();
            if (existingNames.contains(fullNormalized)) continue;

            await DatabaseHelper.instance.createAccountCategory(
              AccountCategory(accountId: typeId, categoria: fullName),
            );
            existingNames.add(fullNormalized);
            categoriesCreated++;
          }
        }
      }
    }

    if (mounted) {
      final total = typesCreated + categoriesCreated;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            total > 0
                ? '$typesCreated tipos e $categoriesCreated categorias adicionados!'
                : 'Todas as categorias padrão já existem!',
          ),
          backgroundColor: total > 0 ? Colors.green : Colors.orange,
        ),
      );
    }

    // SEMPRE atualizar ícones de TODOS os tipos e categorias (novos E existentes)
    await _assignIntelligentLogos();
    
    refreshData();
  }
}

class _CategoriasManagementDialog extends StatefulWidget {
  final int typeId;
  final String typeName;
  final List<AccountCategory> categorias;
  final VoidCallback onCategoriasUpdated;

  const _CategoriasManagementDialog({
    required this.typeId,
    required this.typeName,
    required this.categorias,
    required this.onCategoriasUpdated,
  });

  @override
  State<_CategoriasManagementDialog> createState() => _CategoriasManagementDialogState();
}

class _CategoriasManagementDialogState extends State<_CategoriasManagementDialog> {
  late List<AccountCategory> _categorias;
  final _newCategoriaController = TextEditingController();
  List<CreditCardBrand>? _creditCardBrands;
  bool _isLoadingBrands = false;

  @override
  void initState() {
    super.initState();
    _categorias = List.from(widget.categorias);
    // Carregar bandeiras se for cartão
    _loadCreditCardBrandsIfNeeded();
  }

  Future<void> _reloadCategories() async {
    final categorias = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
    if (mounted) {
      setState(() {
        _categorias = categorias;
      });
    }
  }

  Future<void> _loadCreditCardBrandsIfNeeded() async {
    final isCardType = widget.typeName.toLowerCase().contains('cartão');
    if (isCardType) {
      setState(() => _isLoadingBrands = true);
      try {
        final brands =
            await CreditCardBrandService.instance.fetchBrands();
        if (mounted) {
          setState(() {
            _creditCardBrands = brands;
            _isLoadingBrands = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingBrands = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _newCategoriaController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultCategories() async {
    final defaultService = DefaultAccountCategoriesService.instance;
    final defaultCategories = defaultService.getCategoriesAsMap();

    if (!defaultCategories.containsKey(widget.typeName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma categoria padrão para este tipo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final subcategories = defaultCategories[widget.typeName]!;
    final parentLogo = DefaultAccountCategoriesService.getLogoForCategory(widget.typeName);
    final Set<String> usedLogos = {parentLogo ?? ''}; // Evitar repetir o logo do pai
    
    debugPrint('🎨 _loadDefaultCategories: tipo=${widget.typeName}, parentLogo=$parentLogo');
    int addedCount = 0;
    int updatedCount = 0;

    for (final subcategory in subcategories) {
      // Buscar logo inteligente baseado na descrição da subcategoria
      String? childLogo = DefaultAccountCategoriesService.getLogoForSubcategory(subcategory);
      
      // Se o logo já foi usado, procurar alternativa
      if (childLogo != null && usedLogos.contains(childLogo)) {
        childLogo = _findAlternativeLogo(subcategory, usedLogos);
      }
      
      // Adicionar à lista de logos usados
      if (childLogo != null) {
        usedLogos.add(childLogo);
      }
      
      // Buscar categoria no BANCO (não apenas na lista em memória)
      final categoriesFromDb = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
      final existingCategory = categoriesFromDb.firstWhere(
        (cat) => cat.categoria.toLowerCase().trim() == subcategory.toLowerCase().trim(),
        orElse: () => AccountCategory(accountId: widget.typeId, categoria: ''),
      );
      
      if (existingCategory.id != null) {
        // Categoria existe - ATUALIZAR o logo
        final updated = existingCategory.copyWith(logo: childLogo);
        await DatabaseHelper.instance.updateAccountCategory(updated);
        debugPrint('🎨 Atualizando categoria: $subcategory com logo=$childLogo');
        updatedCount++;
      } else {
        // Categoria NÃO existe - CRIAR
        final categoria = AccountCategory(
          accountId: widget.typeId,
          categoria: subcategory,
          logo: childLogo,
        );
        debugPrint('🎨 Criando categoria: $subcategory com logo=$childLogo');
        await DatabaseHelper.instance.createAccountCategory(categoria);
        addedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0 || updatedCount > 0
                ? '$addedCount criadas, $updatedCount atualizadas!'
                : 'Todas as subcategorias já estão configuradas!',
          ),
          backgroundColor: (addedCount > 0 || updatedCount > 0) ? Colors.green : Colors.orange,
        ),
      );
    }

    await _reloadCategories();
    widget.onCategoriasUpdated();
  }

  /// Encontra um ícone alternativo garantindo que não se repita
  String? _findAlternativeLogo(String categoryName, Set<String> usedLogos) {
    final alternativeLogos = [
      '🏷️', '📌', '🎯', '✨', '💫', '🌟', '⭐', '✅', '📍', '🔖',
      '📊', '📈', '📉', '💹', '📐', '📏', '⏱️', '⏰', '🕐', '🕑',
      '🎪', '🎨', '🎭', '🎬', '🎤', '🎧', '🎵', '🎶', '🎸', '🎹',
    ];
    
    for (final logo in alternativeLogos) {
      if (!usedLogos.contains(logo)) {
        return logo;
      }
    }
    
    return null;
  }

  Future<void> _addCategory() async {
    final text = _newCategoriaController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma categoria'), backgroundColor: Colors.orange),
      );
      return;
    }

    final exists = await DatabaseHelper.instance.checkAccountCategoryExists(widget.typeId, text);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esta categoria já existe'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Obter logo do tipo/categoria pai
    final logo = DefaultAccountCategoriesService.getLogoForCategory(widget.typeName);
    
    final categoria = AccountCategory(
      accountId: widget.typeId,
      categoria: text,
      logo: logo,
    );
    await DatabaseHelper.instance.createAccountCategory(categoria);

    _newCategoriaController.clear();
    await _reloadCategories();
    widget.onCategoriasUpdated();
  }

  Future<void> _editCategory(AccountCategory category) async {
    final controller = TextEditingController(text: category.categoria);
    final logoController = TextEditingController(text: category.logo ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: logoController,
                    decoration: const InputDecoration(
                      labelText: 'Logo (emoji ou texto)',
                      hintText: 'Ex: 🍔 ou 💳',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final selectedIcon = await showIconPickerDialog(
                      context,
                      initialIcon: logoController.text.isNotEmpty ? logoController.text : null,
                    );
                    if (selectedIcon != null) {
                      logoController.text = selectedIcon;
                    }
                  },
                  icon: const Icon(Icons.palette),
                  label: const Text('Picker'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              final logo = logoController.text.trim();
              Navigator.pop(ctx, {'name': name, 'logo': logo});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      final newName = result['name']!;
      final newLogo = result['logo']!.isEmpty ? null : result['logo'];
      
      // Só atualizar se houve mudança no nome OU no logo
      final nameChanged = newName != category.categoria;
      final logoChanged = newLogo != category.logo;
      
      if (!nameChanged && !logoChanged) {
        debugPrint('[EDIT] Nenhuma mudança detectada, pulando update');
        controller.dispose();
        logoController.dispose();
        return;
      }
      
      debugPrint('[EDIT] Editando categoria: ID=${category.id}, de "${category.categoria}" para "$newName", logo: $newLogo');

      // Verificar se o novo nome já existe (excluindo o registro atual)
      if (nameChanged) {
        final exists = await DatabaseHelper.instance.checkAccountCategoryExists(widget.typeId, newName);
        if (exists) {
          debugPrint('[EDIT] Nome "$newName" já existe!');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Uma categoria com este nome já existe'), backgroundColor: Colors.red),
            );
          }
          controller.dispose();
          logoController.dispose();
          return;
        }
      }

      final updated = category.copyWith(categoria: newName, logo: newLogo);
      debugPrint('[EDIT] Chamando updateAccountCategory com ID=${updated.id}');
      final rowsAffected = await DatabaseHelper.instance.updateAccountCategory(updated);
      debugPrint('[EDIT] Resultado do update: $rowsAffected linhas');

      // Recarregar dados do banco para garantir sincronização
      final refreshed = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
      debugPrint('[EDIT] Recarregado ${refreshed.length} categorias do banco');
      setState(() {
        _categorias.clear();
        _categorias.addAll(refreshed);
      });
      widget.onCategoriasUpdated();
    }
    controller.dispose();
    logoController.dispose();
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Categoria?'),
        content: const Text('Deseja remover esta categoria?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAccountCategory(id);
      await _reloadCategories();
      widget.onCategoriasUpdated();
    }
  }

  Future<void> _loadBrandsAsCategories() async {
    if (_creditCardBrands == null || _creditCardBrands!.isEmpty) return;

    int addedCount = 0;
    for (final brand in _creditCardBrands!) {
      final exists = await DatabaseHelper.instance
          .checkAccountCategoryExists(widget.typeId, brand.name);
      if (!exists) {
        final categoria = AccountCategory(
          accountId: widget.typeId,
          categoria: brand.name,
        );
        final id =
            await DatabaseHelper.instance.createAccountCategory(categoria);
        setState(() {
          _categorias.add(
            AccountCategory(
              id: id,
              accountId: widget.typeId,
              categoria: brand.name,
            ),
          );
        });
        addedCount++;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addedCount > 0
                ? '$addedCount bandeiras adicionadas!'
                : 'Todas as bandeiras já existem!',
          ),
          backgroundColor: addedCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    }

    widget.onCategoriasUpdated();
  }

  // ignore: unused_element
  Future<void> _removeDuplicates() async {
    final Map<String, List<AccountCategory>> grouped = {};
    
    // Agrupar por nome
    for (final cat in _categorias) {
      final key = cat.categoria.toLowerCase().trim();
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(cat);
    }
    
    int deletedCount = 0;
    
    // Para cada grupo, manter apenas o primeiro e deletar os demais
    for (final entry in grouped.entries) {
      if (entry.value.length > 1) {
        // Ordenar por ID (manter o mais antigo)
        entry.value.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
        
        // Deletar duplicatas (todos exceto o primeiro)
        for (int i = 1; i < entry.value.length; i++) {
          if (entry.value[i].id != null) {
            await DatabaseHelper.instance.deleteAccountCategory(entry.value[i].id!);
            deletedCount++;
            debugPrint('🗑️ Deletada duplicata: ${entry.value[i].categoria} (id=${entry.value[i].id})');
          }
        }
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount > 0
                ? '$deletedCount duplicatas removidas!'
                : 'Nenhuma duplicata encontrada!',
          ),
          backgroundColor: deletedCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
    
    await _reloadCategories();
    widget.onCategoriasUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF5F5F5),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Categorias: ${widget.typeName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Campo de entrada
            TextField(
              controller: _newCategoriaController,
            decoration: buildOutlinedInputDecoration(
              label: 'Nova Categoria',
              icon: Icons.add_circle,
              suffixIcon: _newCategoriaController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() => _newCategoriaController.clear()),
                    ),
              dense: true,
            ),
            onChanged: (val) => setState(() {}),
            onSubmitted: (val) => _addCategory(),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Popular'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _loadDefaultCategories,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            
            // Botão para popular com bandeiras (se for cartão)
            if (_creditCardBrands != null && _creditCardBrands!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('Carregar Bandeiras'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoadingBrands ? null : _loadBrandsAsCategories,
                ),
              ),
                        // Lista de categorias
            Flexible(
              child: _categorias.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma categoria cadastrada',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categorias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final cat = _categorias[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (cat.logo != null && cat.logo!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Text(cat.logo!, style: const TextStyle(fontSize: 16)),
                                      ),
                                    Expanded(
                                      child: Text(
                                        cat.categoria,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                onPressed: () => _editCategory(cat),
                                tooltip: 'Editar',
                                splashRadius: 20,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () => _deleteCategory(cat.id!),
                                tooltip: 'Deletar',
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Botão de fechar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
