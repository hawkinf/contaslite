import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../services/default_account_categories_service.dart';
import '../widgets/app_input_decoration.dart';

class RecebimentosTableScreen extends StatefulWidget {
  final bool asDialog;

  const RecebimentosTableScreen({super.key, this.asDialog = false});

  @override
  State<RecebimentosTableScreen> createState() => _RecebimentosTableScreenState();
}

class _RecebimentosTableScreenState extends State<RecebimentosTableScreen> {
  static const String _recebimentosName =
      DefaultAccountCategoriesService.recebimentosName;
  static const String _childSeparator =
      DefaultAccountCategoriesService.recebimentosChildSeparator;
  static const Map<String, List<String>> _recebimentosDefaults =
      DefaultAccountCategoriesService.recebimentosChildDefaults;

  AccountType? _type;
  List<AccountCategory> _parentCategories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<int> _ensureTypeId() async {
    final types = await DatabaseHelper.instance.readAllTypes();
    final match = types.firstWhere(
      (t) => t.name.toUpperCase() == _recebimentosName.toUpperCase(),
      orElse: () => AccountType(name: _recebimentosName),
    );
    if (match.id != null) {
      _type = match;
      return match.id!;
    }
    final typeId = await DatabaseHelper.instance.createType(match);
    _type = AccountType(id: typeId, name: match.name);
    return typeId;
  }

  String _childDisplayName(String raw) {
    if (!raw.contains(_childSeparator)) return raw;
    return raw.split(_childSeparator).last.trim();
  }

  String _fullChildName(String parent, String child) {
    return '$parent$_childSeparator$child';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final typeId = await _ensureTypeId();
    final categories = await DatabaseHelper.instance.readAccountCategories(typeId);

    final parents = <AccountCategory>[];

    for (final cat in categories) {
      if (!cat.categoria.contains(_childSeparator)) {
        parents.add(cat);
      }
    }

    parents.sort((a, b) => a.categoria.compareTo(b.categoria));

    if (!mounted) return;
    setState(() {
      _parentCategories = parents;
      _isLoading = false;
    });
  }

  Future<void> _populateDefaults() async {
    final typeId = _type?.id ?? await _ensureTypeId();
    final defaults = DefaultAccountCategoriesService.instance.getCategoriesAsMap();
    if (!defaults.containsKey(_recebimentosName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma categoria padrao para recebimentos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int addedCount = 0;

    // Carregar todas as categorias existentes uma única vez
    final existingCategories = await DatabaseHelper.instance.readAccountCategories(typeId);
    final existingCategoryNames = {for (final cat in existingCategories) cat.categoria.toUpperCase()};

    // Construir lista de categorias a criar
    final categoriesToCreate = <AccountCategory>[];

    for (final parent in _recebimentosDefaults.keys) {
      if (!existingCategoryNames.contains(parent.toUpperCase())) {
        categoriesToCreate.add(AccountCategory(accountId: typeId, categoria: parent));
        addedCount++;
      }

      for (final child in _recebimentosDefaults[parent]!) {
        final fullName = _fullChildName(parent, child);
        if (!existingCategoryNames.contains(fullName.toUpperCase())) {
          categoriesToCreate.add(AccountCategory(accountId: typeId, categoria: fullName));
          addedCount++;
        }
      }
    }

    // Criar todas as categorias
    for (final categoria in categoriesToCreate) {
      await DatabaseHelper.instance.createAccountCategory(categoria);
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _loadData();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          addedCount > 0
              ? '$addedCount categorias adicionadas!'
              : 'Todas as categorias ja existem!',
        ),
        backgroundColor: addedCount > 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _addParentCategory() async {
    final name = await _promptCategory(
      title: 'Adicionar categoria pai',
      label: 'Categoria',
      icon: Icons.category,
    );
    if (name == null || name.isEmpty) return;

    final typeId = _type?.id ?? await _ensureTypeId();
    final exists =
        await DatabaseHelper.instance.checkAccountCategoryExists(typeId, name);
    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta categoria ja existe'), backgroundColor: Colors.red),
      );
      return;
    }

    final categoria = AccountCategory(accountId: typeId, categoria: name);
    await DatabaseHelper.instance.createAccountCategory(categoria);
    if (!mounted) return;
    await _loadData();
  }


  Future<void> _editParentCategory(AccountCategory category) async {
    final name = await _promptCategory(
      title: 'Editar categoria pai',
      label: 'Categoria',
      icon: Icons.edit,
      initialValue: category.categoria,
    );
    if (name == null || name.isEmpty || name == category.categoria) return;

    final updated = category.copyWith(categoria: name);
    await DatabaseHelper.instance.updateAccountCategory(updated);

    final all = await DatabaseHelper.instance.readAccountCategories(_type!.id!);
    for (final child in all) {
      if (!child.categoria.startsWith('${category.categoria}$_childSeparator')) {
        continue;
      }
      final childName = _childDisplayName(child.categoria);
      final updatedChild =
          child.copyWith(categoria: _fullChildName(name, childName));
      await DatabaseHelper.instance.updateAccountCategory(updatedChild);
    }

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _deleteParentCategory(AccountCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar categoria?'),
        content: Text('Remover "${category.categoria}" e suas categorias filhas?'),
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
    if (confirm != true) return;

    final all = await DatabaseHelper.instance.readAccountCategories(_type!.id!);
    for (final child in all) {
      if (!child.categoria.startsWith('${category.categoria}$_childSeparator')) {
        continue;
      }
      await DatabaseHelper.instance.deleteAccountCategory(child.id!);
    }
    await DatabaseHelper.instance.deleteAccountCategory(category.id!);

    if (!mounted) return;
    await _loadData();
  }


  void _showChildrenDialog(String parentName) {
    final typeId = _type?.id;
    if (typeId == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _RecebimentosChildrenDialog(
        typeId: typeId,
        parentName: parentName,
        defaults: _recebimentosDefaults[parentName] ?? const [],
        childSeparator: _childSeparator,
      ),
    );
  }


  Future<String?> _promptCategory({
    required String title,
    required String label,
    required IconData icon,
    String? initialValue,
  }) async {
    if (!mounted) return null;
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: buildOutlinedInputDecoration(
            label: label,
            icon: icon,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }


  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _populateDefaults,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Popular'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(
                      label: Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: Text('Acoes', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                    ),
                  ],
                      rows: _parentCategories.map((parent) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                parent.categoria,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Editar',
                                    onPressed: () => _editParentCategory(parent),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.category, color: Colors.purple),
                                    tooltip: 'Categorias',
                                    onPressed: () => _showChildrenDialog(parent.categoria),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Excluir',
                                    onPressed: () => _deleteParentCategory(parent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
            ],
          );

    if (widget.asDialog) {
      final screenSize = MediaQuery.of(context).size;
      final viewInsets = MediaQuery.of(context).viewInsets;
      final maxWidth = (screenSize.width * 0.9).clamp(280.0, 520.0);
      final availableHeight = screenSize.height - viewInsets.bottom;
      final maxHeight = (availableHeight * 0.8).clamp(300.0, 900.0);

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFFF5F5F5),
        child: Container(
          width: maxWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Categorias: Contas a Receber',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addParentCategory,
                      icon: const Icon(Icons.add),
                      label: const Text('Nova Categoria'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade600),
                      onPressed: _populateDefaults,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Popular com Padrões'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(child: content),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas a Receber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Popular com padroes',
            onPressed: _populateDefaults,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addParentCategory,
        label: const Text('Nova categoria'),
        icon: const Icon(Icons.add),
      ),
      body: SafeArea(child: content),
    );
  }
}

class _RecebimentosChildrenDialog extends StatefulWidget {
  final int typeId;
  final String parentName;
  final List<String> defaults;
  final String childSeparator;

  const _RecebimentosChildrenDialog({
    required this.typeId,
    required this.parentName,
    required this.defaults,
    required this.childSeparator,
  });

  @override
  State<_RecebimentosChildrenDialog> createState() =>
      _RecebimentosChildrenDialogState();
}

class _RecebimentosChildrenDialogState
    extends State<_RecebimentosChildrenDialog> {
  final _newController = TextEditingController();
  List<AccountCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  String _childDisplayName(String raw) {
    if (!raw.contains(widget.childSeparator)) return raw;
    return raw.split(widget.childSeparator).last.trim();
  }

  String _fullName(String child) {
    return '${widget.parentName}${widget.childSeparator}$child';
  }

  Future<void> _loadChildren() async {
    final categories =
        await DatabaseHelper.instance.readAccountCategories(widget.typeId);
    final children = categories
        .where((c) => c.categoria
            .startsWith('${widget.parentName}${widget.childSeparator}'))
        .toList()
      ..sort((a, b) => a.categoria.compareTo(b.categoria));
    if (!mounted) return;
    setState(() {
      _categories = children;
      _loading = false;
    });
  }

  Future<void> _addChild() async {
    final name = _newController.text.trim();
    if (name.isEmpty) return;
    final fullName = _fullName(name);
    final exists = await DatabaseHelper.instance
        .checkAccountCategoryExists(widget.typeId, fullName);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta categoria ja existe'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final categoria = AccountCategory(accountId: widget.typeId, categoria: fullName);
    final id = await DatabaseHelper.instance.createAccountCategory(categoria);
    if (!mounted) return;
    setState(() {
      _categories.add(AccountCategory(id: id, accountId: widget.typeId, categoria: fullName));
      _newController.clear();
    });
  }

  Future<void> _populateDefaults() async {
    int added = 0;
    for (final child in widget.defaults) {
      final fullName = _fullName(child);
      final exists = await DatabaseHelper.instance
          .checkAccountCategoryExists(widget.typeId, fullName);
      if (!exists) {
        final categoria =
            AccountCategory(accountId: widget.typeId, categoria: fullName);
        await DatabaseHelper.instance.createAccountCategory(categoria);
        added++;
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _loadChildren();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added > 0 ? '$added categorias adicionadas!' : 'Todas ja existem!',
        ),
        backgroundColor: added > 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _editChild(AccountCategory category) async {
    final controller =
        TextEditingController(text: _childDisplayName(category.categoria));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: buildOutlinedInputDecoration(
            label: 'Categoria',
            icon: Icons.edit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty) return;
    final fullName = _fullName(newName);
    final updated = category.copyWith(categoria: fullName);
    await DatabaseHelper.instance.updateAccountCategory(updated);
    if (!mounted) return;
    await _loadChildren();
  }

  Future<void> _deleteChild(AccountCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar categoria?'),
        content: Text('Remover "${_childDisplayName(category.categoria)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteAccountCategory(category.id!);
    if (!mounted) return;
    await _loadChildren();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final maxWidth = (screenSize.width * 0.9).clamp(280.0, 420.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.75).clamp(250.0, 800.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF5F5F5),
      child: Container(
        width: maxWidth,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Categorias: ${widget.parentName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              decoration: buildOutlinedInputDecoration(
                label: 'Nova Categoria',
                icon: Icons.add_circle,
              ),
              onSubmitted: (_) => _addChild(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
              onPressed: _addChild,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade600),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Popular com Padrões'),
              onPressed: _populateDefaults,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _categories.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma categoria cadastrada',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final cat = _categories[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _childDisplayName(cat.categoria),
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    onPressed: () => _editChild(cat),
                                    tooltip: 'Editar',
                                    splashRadius: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                    onPressed: () => _deleteChild(cat),
                                    tooltip: 'Deletar',
                                    splashRadius: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
