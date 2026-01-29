import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/default_account_categories_service.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_radius.dart';

/// Tela de categorias de Contas a Receber.
///
/// Exibe e gerencia categorias de receitas/recebimentos.
class ReceiveCategoriesScreen extends StatefulWidget {
  const ReceiveCategoriesScreen({super.key});

  @override
  State<ReceiveCategoriesScreen> createState() => _ReceiveCategoriesScreenState();
}

class _ReceiveCategoriesScreenState extends State<ReceiveCategoriesScreen> {
  List<AccountType> _types = [];
  bool _isLoading = false;
  bool _isPopulating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allTypes = await DatabaseHelper.instance.readAllTypes();
      // Filtra apenas tipos de recebimento
      _types = allTypes.where((t) {
        final name = t.name.toLowerCase();
        return name.contains('recebimento') ||
               name.contains('receita') ||
               name.contains('entrada') ||
               name.contains('vendas') ||
               name.contains('salário') ||
               name.contains('honorários');
      }).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FFEntityPageScaffold(
      title: 'Contas a Receber',
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
      isEmpty: _types.isEmpty,
      emptyState: FFEmptyState.categorias(
        description: 'Adicione categorias para organizar suas receitas.',
        onAction: () => _showTypeDialog(),
      ),
      columnHeaders: const ['Descrição', 'Ações'],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _types.length,
              itemBuilder: (context, index) {
                final type = _types[index];
                return FFEntityListItem.category(
                  emoji: type.logo,
                  name: type.name,
                  onEdit: () => _showTypeDialog(typeToEdit: type),
                  onTap: () => _showSubcategoriesDialog(type),
                  onDelete: () => _confirmDelete(type),
                  showDivider: index < _types.length - 1,
                );
              },
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
                isEditing ? 'Editar Categoria' : 'Nova Categoria de Recebimento',
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
                  hintText: 'Ex: Vendas, Salário',
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
                        hintText: 'Ex: 💰 ou 📈',
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
                      final name = controller.text.trim();
                      final logo = logoController.text.trim();
                      if (name.isEmpty) return;

                      if (!isEditing || name.toUpperCase() != typeToEdit.name.toUpperCase()) {
                        final exists = await DatabaseHelper.instance.checkAccountTypeExists(name);
                        if (exists && ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Este nome já existe!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                      }

                      if (isEditing) {
                        await DatabaseHelper.instance.updateType(
                          AccountType(id: typeToEdit.id, name: name, logo: logo.isEmpty ? null : logo),
                        );
                      } else {
                        await DatabaseHelper.instance.createType(
                          AccountType(name: name, logo: logo.isEmpty ? null : logo),
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
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

  Future<void> _showSubcategoriesDialog(AccountType type) async {
    final categorias = await DatabaseHelper.instance.readAccountCategories(type.id!);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _SubcategoriesDialog(
        typeId: type.id!,
        typeName: type.name,
        categorias: categorias,
        onUpdated: _loadData,
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
      _loadData();
    }
  }

  Future<void> _populateDefaults() async {
    if (_isPopulating) return;
    setState(() => _isPopulating = true);

    try {
      final defaultService = DefaultAccountCategoriesService.instance;
      final categoriesMap = defaultService.getCategoriesAsMap();

      int typesCreated = 0;
      int categoriesCreated = 0;

      // Nome padrão de recebimentos
      const receiveName = 'Recebimentos';

      if (categoriesMap.containsKey(receiveName)) {
        final exists = await DatabaseHelper.instance.checkAccountTypeExists(receiveName);
        int typeId;

        if (exists) {
          final allTypes = await DatabaseHelper.instance.readAllTypes();
          typeId = allTypes.firstWhere((t) => t.name.toUpperCase() == receiveName.toUpperCase()).id!;
        } else {
          final logo = DefaultAccountCategoriesService.getLogoForCategory(receiveName);
          typeId = await DatabaseHelper.instance.createType(
            AccountType(name: receiveName, logo: logo),
          );
          typesCreated++;
        }

        final subcategories = categoriesMap[receiveName]!;
        final existingCats = await DatabaseHelper.instance.readAccountCategories(typeId);
        final existingNames = existingCats.map((c) => c.categoria.toUpperCase()).toSet();

        for (final sub in subcategories) {
          if (existingNames.contains(sub.toUpperCase())) continue;

          final logo = DefaultAccountCategoriesService.getLogoForSubcategory(sub);
          await DatabaseHelper.instance.createAccountCategory(
            AccountCategory(accountId: typeId, categoria: sub, logo: logo),
          );
          categoriesCreated++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              typesCreated + categoriesCreated > 0
                  ? '$typesCreated tipos e $categoriesCreated categorias adicionados!'
                  : 'Todas as categorias já existem!',
            ),
            backgroundColor: typesCreated + categoriesCreated > 0 ? Colors.green : Colors.orange,
          ),
        );
      }

      _loadData();
    } finally {
      if (mounted) setState(() => _isPopulating = false);
    }
  }
}

/// Dialog para gerenciar subcategorias
class _SubcategoriesDialog extends StatefulWidget {
  final int typeId;
  final String typeName;
  final List<AccountCategory> categorias;
  final VoidCallback onUpdated;

  const _SubcategoriesDialog({
    required this.typeId,
    required this.typeName,
    required this.categorias,
    required this.onUpdated,
  });

  @override
  State<_SubcategoriesDialog> createState() => _SubcategoriesDialogState();
}

class _SubcategoriesDialogState extends State<_SubcategoriesDialog> {
  late List<AccountCategory> _categorias;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categorias = List.from(widget.categorias);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final cats = await DatabaseHelper.instance.readAccountCategories(widget.typeId);
    if (mounted) setState(() => _categorias = cats);
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final exists = await DatabaseHelper.instance.checkAccountCategoryExists(widget.typeId, text);
    if (exists && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta categoria já existe'), backgroundColor: Colors.red),
      );
      return;
    }

    await DatabaseHelper.instance.createAccountCategory(
      AccountCategory(accountId: widget.typeId, categoria: text),
    );
    _controller.clear();
    await _reload();
    widget.onUpdated();
  }

  Future<void> _delete(int id) async {
    final confirm = await FFConfirmDialog.showDelete(
      context: context,
      itemName: 'esta subcategoria',
    );
    if (confirm) {
      await DatabaseHelper.instance.deleteAccountCategory(id);
      await _reload();
      widget.onUpdated();
    }
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
        constraints: const BoxConstraints(maxHeight: 500),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Subcategorias: ${widget.typeName}',
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Nova Subcategoria',
                      icon: Icons.add_circle,
                      dense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FFPrimaryButton(
                  label: 'Adicionar',
                  icon: Icons.add,
                  expanded: false,
                  onPressed: _add,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: _categorias.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma subcategoria',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
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
                            onDelete: () => _delete(cat.id!),
                            showDivider: index < _categorias.length - 1,
                            density: FFEntityDensity.compact,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
