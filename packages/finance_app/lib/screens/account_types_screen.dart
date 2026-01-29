import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/prefs_service.dart';
import '../services/credit_card_brand_service.dart';
import '../services/default_account_categories_service.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_radius.dart';

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
  bool _isPopulating = false;

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
  Future<void> _assignIntelligentLogos() async {
    try {
      int updatedTypes = 0;
      int updatedCategories = 0;

      for (final type in types) {
        final parentLogo = DefaultAccountCategoriesService.getLogoForCategory(type.name);
        if (parentLogo != null && (type.logo == null || type.logo!.isEmpty)) {
          final updatedType = AccountType(id: type.id, name: type.name, logo: parentLogo);
          await DatabaseHelper.instance.updateType(updatedType);
          updatedTypes++;
        }

        if (type.id != null) {
          final categories = await DatabaseHelper.instance.readAccountCategories(type.id!);
          final Set<String> usedLogos = {parentLogo ?? ''};

          for (final category in categories) {
            String? childLogo = DefaultAccountCategoriesService.getLogoForSubcategory(category.categoria);

            if (childLogo != null && usedLogos.contains(childLogo)) {
              childLogo = _findAlternativeLogo(category.categoria, usedLogos);
            }

            if (childLogo != null) {
              usedLogos.add(childLogo);
              final updatedCategory = category.copyWith(logo: childLogo);
              await DatabaseHelper.instance.updateAccountCategory(updatedCategory);
              updatedCategories++;
            }
          }
        }
      }

      final total = updatedTypes + updatedCategories;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              total > 0
                  ? '$updatedCategories categorias com ícones atribuídos!'
                  : 'Todas as categorias já têm ícones!',
            ),
            backgroundColor: total > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      await refreshData();
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return FFScreenScaffold(
      title: 'Categorias',
      useScrollView: false,
      verticalPadding: 0,
      child: ValueListenableBuilder<DateTimeRange>(
        valueListenable: PrefsService.dateRangeNotifier,
        builder: (context, range, _) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Actions bar
              Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, 0, AppSpacing.md),
                child: FFEntityActionsBar(
                  primaryAction: FFEntityAction(
                    label: 'Nova Categoria',
                    icon: Icons.add,
                    onPressed: () => _showTypeDialog(),
                  ),
                  secondaryAction: FFEntityAction(
                    label: 'Popular',
                    icon: Icons.auto_awesome,
                    onPressed: _isPopulating ? null : _populateDefaults,
                    isLoading: _isPopulating,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: types.isEmpty
                    ? FFEmptyState.categorias(
                        onAction: () => _showTypeDialog(),
                      )
                    : _buildList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FFCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Descrição',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  'Ações',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final type = types[index];
                return FFEntityListItem.category(
                  emoji: type.logo,
                  name: type.name,
                  onEdit: () => _showTypeDialog(typeToEdit: type),
                  onTap: () => _showCategoriesDialog(type),
                  onDelete: () => _confirmDelete(type),
                  showDivider: index < types.length - 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTypeDialog({AccountType? typeToEdit}) async {
    final isEditing = typeToEdit != null;
    final controller = TextEditingController(text: isEditing ? typeToEdit.name : '');
    final logoController = TextEditingController(text: isEditing ? (typeToEdit.logo ?? '') : '');

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Categoria' : 'Nova Categoria',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Nome da Categoria',
                  icon: Icons.label,
                  hintText: 'Ex: Energia, Internet',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logoController,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Logo (emoji)',
                        icon: Icons.image,
                        hintText: 'Ex: 🍔 ou 💳',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FFSecondaryButton(
                    label: 'Picker',
                    icon: Icons.palette,
                    expanded: false,
                    onPressed: () async {
                      final selectedIcon = await showIconPickerDialog(
                        ctx,
                        initialIcon: logoController.text.isNotEmpty ? logoController.text : null,
                      );
                      if (selectedIcon != null) {
                        logoController.text = selectedIcon;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FFSecondaryButton(
                    label: 'Cancelar',
                    expanded: false,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FFPrimaryButton(
                    label: 'Salvar',
                    expanded: false,
                    onPressed: () async {
                      String name = controller.text.trim();
                      String logo = logoController.text.trim();
                      if (name.isNotEmpty) {
                        if (!isEditing || (isEditing && name.toUpperCase() != typeToEdit.name.toUpperCase())) {
                          bool exists = await DatabaseHelper.instance.checkAccountTypeExists(name);
                          if (exists) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Erro: Este nome já existe!'), backgroundColor: Colors.red),
                              );
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

                        if (ctx.mounted) Navigator.pop(ctx);
                        refreshData();
                      }
                    },
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
    final confirm = await FFConfirmDialog.show(
      context: context,
      title: 'Excluir "${type.name}"?',
      message: 'Isso apagará todas as contas vinculadas a esta categoria.',
      confirmLabel: 'Excluir',
      isDanger: true,
      icon: Icons.delete_outline,
    );

    if (confirm) {
      await DatabaseHelper.instance.deleteType(type.id!);
      refreshData();
    }
  }

  Future<void> _populateDefaults() async {
    if (_isPopulating) return;
    setState(() => _isPopulating = true);

    final tipoPessoa = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = tipoPessoaOptions[2];
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

    if (tipoPessoa == null || !mounted) {
      setState(() => _isPopulating = false);
      return;
    }

    try {
      final defaultService = DefaultAccountCategoriesService.instance;
      final categoriesMap = defaultService.getCategoriesAsMap(tipoPessoa: tipoPessoa);

      int typesCreated = 0;
      int categoriesCreated = 0;

      final existingTypes = await DatabaseHelper.instance.readAllTypes();
      final typeIdByName = <String, int>{
        for (final type in existingTypes) type.name.trim().toUpperCase(): type.id!,
      };

      for (final typeName in categoriesMap.keys) {
        final normalizedName = typeName.trim().toUpperCase();
        int typeId;

        if (typeIdByName.containsKey(normalizedName)) {
          typeId = typeIdByName[normalizedName]!;
        } else {
          final logo = DefaultAccountCategoriesService.getLogoForCategory(typeName);
          typeId = await DatabaseHelper.instance.createType(
            AccountType(name: typeName, logo: logo),
          );
          typeIdByName[normalizedName] = typeId;
          typesCreated++;
        }

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

      await _assignIntelligentLogos();
      refreshData();
    } finally {
      if (mounted) setState(() => _isPopulating = false);
    }
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
        final brands = await CreditCardBrandService.instance.fetchBrands();
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
    final Set<String> usedLogos = {parentLogo ?? ''};

    int addedCount = 0;
    int updatedCount = 0;

    for (final subcategory in subcategories) {
      String? childLogo = DefaultAccountCategoriesService.getLogoForSubcategory(subcategory);

      if (childLogo != null && usedLogos.contains(childLogo)) {
        childLogo = _findAlternativeLogo(subcategory, usedLogos);
      }

      if (childLogo != null) {
        usedLogos.add(childLogo);
      }

      final categoriesFromDb = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
      final existingCategory = categoriesFromDb.firstWhere(
        (cat) => cat.categoria.toLowerCase().trim() == subcategory.toLowerCase().trim(),
        orElse: () => AccountCategory(accountId: widget.typeId, categoria: ''),
      );

      if (existingCategory.id != null) {
        final updated = existingCategory.copyWith(logo: childLogo);
        await DatabaseHelper.instance.updateAccountCategory(updated);
        updatedCount++;
      } else {
        final categoria = AccountCategory(
          accountId: widget.typeId,
          categoria: subcategory,
          logo: childLogo,
        );
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

      final nameChanged = newName != category.categoria;
      final logoChanged = newLogo != category.logo;

      if (!nameChanged && !logoChanged) {
        controller.dispose();
        logoController.dispose();
        return;
      }

      if (nameChanged) {
        final exists = await DatabaseHelper.instance.checkAccountCategoryExists(widget.typeId, newName);
        if (exists) {
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
      await DatabaseHelper.instance.updateAccountCategory(updated);

      final refreshed = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
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
    final confirm = await FFConfirmDialog.showDelete(
      context: context,
      itemName: 'esta categoria',
    );

    if (confirm) {
      await DatabaseHelper.instance.deleteAccountCategory(id);
      await _reloadCategories();
      widget.onCategoriasUpdated();
    }
  }

  Future<void> _loadBrandsAsCategories() async {
    if (_creditCardBrands == null || _creditCardBrands!.isEmpty) return;

    int addedCount = 0;
    for (final brand in _creditCardBrands!) {
      final exists = await DatabaseHelper.instance.checkAccountCategoryExists(widget.typeId, brand.name);
      if (!exists) {
        final categoria = AccountCategory(
          accountId: widget.typeId,
          categoria: brand.name,
        );
        final id = await DatabaseHelper.instance.createAccountCategory(categoria);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.category_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Categorias: ${widget.typeName}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Add field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoriaController,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Nova Subcategoria',
                      icon: Icons.add_circle,
                      dense: true,
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Action buttons
            FFEntityActionsBar(
              primaryAction: FFEntityAction(
                label: 'Adicionar',
                icon: Icons.add,
                onPressed: _addCategory,
              ),
              secondaryAction: FFEntityAction(
                label: 'Popular',
                icon: Icons.auto_awesome,
                onPressed: _loadDefaultCategories,
              ),
            ),

            if (_creditCardBrands != null && _creditCardBrands!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              FFSecondaryButton(
                label: 'Carregar Bandeiras',
                icon: Icons.cloud_download,
                onPressed: _isLoadingBrands ? null : _loadBrandsAsCategories,
                tonal: true,
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // List
            Flexible(
              child: _categorias.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma subcategoria cadastrada',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : FFCard(
                      padding: EdgeInsets.zero,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _categorias.length,
                        itemBuilder: (context, index) {
                          final cat = _categorias[index];
                          return FFEntityListItem.category(
                            emoji: cat.logo,
                            name: cat.categoria,
                            onEdit: () => _editCategory(cat),
                            onDelete: () => _deleteCategory(cat.id!),
                            showDivider: index < _categorias.length - 1,
                            density: FFEntityDensity.compact,
                          );
                        },
                      ),
                    ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: FFSecondaryButton(
                label: 'Fechar',
                expanded: false,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
