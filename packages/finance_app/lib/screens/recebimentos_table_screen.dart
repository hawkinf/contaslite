import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/prefs_service.dart';
import '../services/default_account_categories_service.dart';

/// Opções de tipo de pessoa para seleção
const List<String> tipoPessoaOptions = [
  'Pessoa Física',
  'Pessoa Jurídica',
  'Ambos (PF e PJ)',
];

class RecebimentosTableScreen extends StatefulWidget {
  final bool asDialog;

  const RecebimentosTableScreen({super.key, this.asDialog = false});

  @override
  State<RecebimentosTableScreen> createState() => _RecebimentosTableScreenState();
}

class _RecebimentosTableScreenState extends State<RecebimentosTableScreen> {
  AccountType? _recebimentosType;
  List<AccountCategory> _categories = [];
  final Map<String, List<AccountCategory>> _groupedByParent = {};
  bool isLoading = false;

  // Nome específico para recebimentos
  static const String _recebimentosName = DefaultAccountCategoriesService.recebimentosName;
  static const String _childSeparator = DefaultAccountCategoriesService.recebimentosChildSeparator;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future refreshData() async {
    setState(() => isLoading = true);
    final allTypes = await DatabaseHelper.instance.readAllTypes();
    // Filtrar apenas o tipo "Recebimentos"
    final recebimentosTypes = allTypes.where((t) => t.name.toUpperCase() == _recebimentosName.toUpperCase()).toList();
    
    // Se não existir, criar
    if (recebimentosTypes.isEmpty) {
      final logo = DefaultAccountCategoriesService.getLogoForCategory(_recebimentosName);
      final id = await DatabaseHelper.instance.createType(
        AccountType(name: _recebimentosName, logo: logo),
      );
      _recebimentosType = AccountType(id: id, name: _recebimentosName, logo: logo);
    } else {
      _recebimentosType = recebimentosTypes.first;
    }
    
    // Carregar categorias
    if (_recebimentosType != null && _recebimentosType!.id != null) {
      final allCategories = await DatabaseHelper.instance.readAccountCategories(_recebimentosType!.id!);
      
      // Agrupar por categoria pai
      _groupedByParent.clear();
      for (final cat in allCategories) {
        if (cat.categoria.contains(_childSeparator)) {
          // É uma categoria filha
          final parentName = cat.categoria.split(_childSeparator)[0].trim();
          _groupedByParent.putIfAbsent(parentName, () => []).add(cat);
        } else {
          // É uma categoria pai
          _groupedByParent.putIfAbsent(cat.categoria, () => [cat]);
        }
      }
      
      // Ordenar pais e filhos
      _categories = allCategories.where((cat) => !cat.categoria.contains(_childSeparator)).toList();
      _categories.sort((a, b) => a.categoria.compareTo(b.categoria));
      
      // Ordenar os filhos dentro de cada pai
      for (final parentCategories in _groupedByParent.values) {
        parentCategories.sort((a, b) => a.categoria.compareTo(b.categoria));
      }
    }
    
    setState(() => isLoading = false);
  }

  /// Atribui ícones inteligentes baseados na descrição de cada categoria
  /// Garantindo que não haja repetição dentro do mesmo tipo pai
  Future<void> _assignIntelligentLogos() async {
    try {
      int updatedType = 0;
      int updatedCategories = 0;

      debugPrint('🎨 [RECEBIMENTOS - ATRIBUIR LOGOS INTELIGENTES] Iniciando...');

      if (_recebimentosType == null || _recebimentosType!.id == null) return;

      // 1. Atribuir logo ao tipo pai (Recebimentos)
      final parentLogo = DefaultAccountCategoriesService.getLogoForCategory(_recebimentosType!.name);
      if (parentLogo != null && (_recebimentosType!.logo == null || _recebimentosType!.logo!.isEmpty)) {
        final updatedTypeObj = AccountType(id: _recebimentosType!.id, name: _recebimentosType!.name, logo: parentLogo);
        await DatabaseHelper.instance.updateType(updatedTypeObj);
        updatedType++;
        debugPrint('🎨 [TIPO] ${_recebimentosType!.name} → logo=$parentLogo');
      }

      // 2. Buscar as categorias filhas deste tipo
      final categories = await DatabaseHelper.instance.readAccountCategories(_recebimentosType!.id!);

      debugPrint('  📋 ${categories.length} categorias para ${_recebimentosType!.name}');

      // Para cada categoria (pode ser pai ou filho de Recebimentos)
      for (final category in categories) {
        String? childLogo;

        // Verificar se é uma categoria pai (sem ||) ou filho (com ||)
        final separator = DefaultAccountCategoriesService.recebimentosChildSeparator;
        if (category.categoria.contains(separator)) {
          // É um filho - extrair nome do pai e do filho
          final parts = category.categoria.split(separator);
          final recebimentoParentName = parts[0].trim();
          final recebimentoChildName = parts[1].trim();

          // Usar o método específico para filhos de Recebimentos
          childLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(
            recebimentoParentName,
            recebimentoChildName,
          );
          debugPrint('    📦 Filho: "$recebimentoChildName" (pai: $recebimentoParentName) → $childLogo');
        } else {
          // É uma categoria pai de Recebimentos (ex: Salário/Pró-Labore, Vendas, etc.)
          childLogo = DefaultAccountCategoriesService.getLogoForRecebimentosPai(category.categoria);
          debugPrint('    📁 Pai: "${category.categoria}" → $childLogo');
        }

        // SEMPRE atualizar o logo da categoria (mesmo que já tenha um)
        final updatedCategory = category.copyWith(logo: childLogo);
        await DatabaseHelper.instance.updateAccountCategory(updatedCategory);
        updatedCategories++;
        debugPrint('    ✅ ${category.categoria} → logo=$childLogo');
      }

      final total = updatedType + updatedCategories;
      debugPrint('🎨 [RESULTADO] $updatedType tipo, $updatedCategories categorias = $total total');

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

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) {
      return _buildDialogContent();
    }

    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contas a Receber'),
          ),
          body: SafeArea(
            child: _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildDialogContent() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contas a Receber',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : _categories.isEmpty
            ? _buildEmptyState()
            : _buildTable();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Nenhuma categoria de recebimento cadastrada.', style: TextStyle(color: Colors.grey.shade600)),
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
              onPressed: () => _showCategoryDialog(),
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
            rows: _categories.map((parentCategory) {
              return DataRow(cells: [
                DataCell(
                  Row(
                    children: [
                      if (parentCategory.logo != null && parentCategory.logo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(parentCategory.logo!, style: const TextStyle(fontSize: 18)),
                        ),
                      Expanded(
                        child: Text(parentCategory.categoria, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  onTap: () => _editCategory(parentCategory),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Editar',
                        onPressed: () => _editCategory(parentCategory),
                      ),
                      IconButton(
                        icon: const Icon(Icons.category, color: Colors.purple),
                        tooltip: 'Subcategorias',
                        onPressed: () => _showChildrenDialog(parentCategory),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Deletar',
                        onPressed: () => _deleteCategory(parentCategory),
                      ),
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

  /// Abre um diálogo mostrando as subcategorias de uma categoria pai
  Future<void> _showChildrenDialog(AccountCategory parentCategory) async {
    final children = _groupedByParent[parentCategory.categoria] ?? [];
    final onlyChildCategories = children.where((c) => c.categoria.contains(_childSeparator)).toList();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Categorias: ${parentCategory.categoria}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showChildCategoryDialog(parentCategory),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova Categoria'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _populateDefaultChildren(parentCategory),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Popular'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Lista de subcategorias
              Expanded(
                child: onlyChildCategories.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma subcategoria',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: onlyChildCategories.length,
                        itemBuilder: (ctx, idx) {
                          final child = onlyChildCategories[idx];
                          final childName = child.categoria.split(_childSeparator).last.trim();
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (child.logo != null && child.logo!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Text(child.logo!, style: const TextStyle(fontSize: 18)),
                                  ),
                                Expanded(
                                  child: Text(childName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  tooltip: 'Editar',
                                  onPressed: () => _editChildCategory(child, parentCategory),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Deletar',
                                  onPressed: () => _deleteCategory(child),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryDialog() async {
    final controller = TextEditingController();
    final logoController = TextEditingController();
    
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
              const Text(
                'Adicionar Categoria de Recebimento',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Nome da Categoria',
                  icon: Icons.label,
                  hintText: 'Ex: Salários, Investimentos',
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logoController,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Logo (emoji ou texto)',
                        icon: Icons.image,
                        hintText: 'Ex: 💰 ou 📈',
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
                        bool exists = await DatabaseHelper.instance.checkAccountCategoryExists(_recebimentosType!.id!, name);
                        if (exists) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro: Esta categoria já existe!'), backgroundColor: Colors.red));
                          }
                          return;
                        }

                        await DatabaseHelper.instance.createAccountCategory(
                          AccountCategory(
                            accountId: _recebimentosType!.id!,
                            categoria: name,
                            logo: logo.isEmpty ? null : logo,
                          ),
                        );
                        
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
                      hintText: 'Ex: 💰 ou 📈',
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
        final exists = await DatabaseHelper.instance.checkAccountCategoryExists(_recebimentosType!.id!, newName);
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

      final refreshed = await DatabaseHelper.instance.readAccountCategories(_recebimentosType!.id!);
      setState(() {
        _categories.clear();
        _categories.addAll(refreshed);
      });
    }
    controller.dispose();
    logoController.dispose();
  }

  Future<void> _deleteCategory(AccountCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Categoria?'),
        content: Text('Deseja remover "${category.categoria}"?'),
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
      if (category.id != null) {
        await DatabaseHelper.instance.deleteAccountCategory(category.id!);
        refreshData();
      }
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
            title: const Text('Popular Categorias de Recebimento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecione o tipo de pessoa:'),
                const SizedBox(height: 16),
                ...tipoPessoaOptions.map((option) => ListTile(
                      title: Text(option),
                      leading: Icon(selected == option ? Icons.radio_button_checked : Icons.radio_button_off),
                      onTap: () => setDialogState(() => selected = option),
                    )),
              ],
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

    // Garantir que o tipo Recebimentos existe
    if (_recebimentosType == null) {
      await refreshData();
    }
    
    final typeId = _recebimentosType!.id!;
    final defaultService = DefaultAccountCategoriesService.instance;
    
    // Obter categorias específicas de recebimentos
    final recebimentosDefaults = defaultService.getRecebimentosChildDefaults(tipoPessoa: tipoPessoa);

    int categoriesCreated = 0;

    // Carregar categorias existentes
    final existingCategories = await DatabaseHelper.instance.readAccountCategories(typeId);
    final existingNames = {for (final cat in existingCategories) cat.categoria.toUpperCase()};

    // Criar categorias pai e filhas com ícones
    for (final parent in recebimentosDefaults.keys) {
      if (!existingNames.contains(parent.toUpperCase())) {
        // Obter ícone para a categoria pai de Recebimentos
        final parentLogo = DefaultAccountCategoriesService.getLogoForRecebimentosPai(parent);
        await DatabaseHelper.instance.createAccountCategory(
          AccountCategory(accountId: typeId, categoria: parent, logo: parentLogo),
        );
        categoriesCreated++;
      }

      for (final child in recebimentosDefaults[parent]!) {
        final fullName = defaultService.buildRecebimentosChildName(parent, child);
        if (!existingNames.contains(fullName.toUpperCase())) {
          // Obter ícone para o filho de Recebimentos
          final childLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(parent, child);
          await DatabaseHelper.instance.createAccountCategory(
            AccountCategory(accountId: typeId, categoria: fullName, logo: childLogo),
          );
          categoriesCreated++;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            categoriesCreated > 0
                ? '$categoriesCreated categorias adicionadas!'
                : 'Todas as categorias padrão já existem!',
          ),
          backgroundColor: categoriesCreated > 0 ? Colors.green : Colors.orange,
        ),
      );
    }

    // SEMPRE atualizar ícones de TODAS as categorias (novas E existentes)
    await _assignIntelligentLogos();
    
    refreshData();
  }

  /// Diálogo para adicionar uma nova subcategoria filha
  Future<void> _showChildCategoryDialog(AccountCategory parentCategory) async {
    final controller = TextEditingController();
    final logoController = TextEditingController();
    
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
              const Text(
                'Adicionar Subcategoria',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Nome da Subcategoria',
                  icon: Icons.label,
                  hintText: 'Ex: INSS, Férias',
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logoController,
                      maxLength: 1,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Ícone',
                        icon: Icons.emoji_emotions,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.purple),
                    onPressed: () async {
                      final selectedLogo = await showDialog<String>(
                        context: context,
                        builder: (ctx) => const IconPickerDialog(),
                      );
                      if (selectedLogo != null) {
                        logoController.text = selectedLogo;
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        if (controller.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Nome da subcategoria é obrigatório')),
                          );
                          return;
                        }
                        
                        final fullName = '${parentCategory.categoria}$_childSeparator${controller.text.trim()}';
                        final logo = logoController.text.trim().isEmpty ? null : logoController.text.trim();
                        
                        final newCategory = AccountCategory(
                          accountId: _recebimentosType!.id!,
                          categoria: fullName,
                          logo: logo,
                        );
                        
                        await DatabaseHelper.instance.createAccountCategory(newCategory);
                        if (!mounted) return;
                        navigator.pop();
                        refreshData();
                      },
                      child: const Text('Adicionar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Editar uma subcategoria filha
  Future<void> _editChildCategory(AccountCategory childCategory, AccountCategory parentCategory) async {
    final childName = childCategory.categoria.split(_childSeparator).last.trim();
    final controller = TextEditingController(text: childName);
    final logoController = TextEditingController(text: childCategory.logo ?? '');
    
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
              const Text(
                'Editar Subcategoria',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: buildOutlinedInputDecoration(
                  label: 'Nome da Subcategoria',
                  icon: Icons.label,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: logoController,
                      maxLength: 1,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Ícone',
                        icon: Icons.emoji_emotions,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.purple),
                    onPressed: () async {
                      final selectedLogo = await showDialog<String>(
                        context: context,
                        builder: (ctx) => const IconPickerDialog(),
                      );
                      if (selectedLogo != null) {
                        logoController.text = selectedLogo;
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        if (controller.text.trim().isEmpty) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Nome da subcategoria é obrigatório')),
                          );
                          return;
                        }
                        
                        final fullName = '${parentCategory.categoria}$_childSeparator${controller.text.trim()}';
                        final logo = logoController.text.trim().isEmpty ? null : logoController.text.trim();
                        
                        final updatedCategory = childCategory.copyWith(
                          categoria: fullName,
                          logo: logo,
                        );
                        
                        await DatabaseHelper.instance.updateAccountCategory(updatedCategory);
                        if (!mounted) return;
                        navigator.pop();
                        refreshData();
                      },
                      child: const Text('Atualizar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Popular subcategorias padrão para uma categoria pai específica
  Future<void> _populateDefaultChildren(AccountCategory parentCategory) async {
    final defaultService = DefaultAccountCategoriesService.instance;
    
    // Mostrar diálogo de seleção de tipo de pessoa
    final tipoPessoa = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String selected = tipoPessoaOptions[2]; // Ambos (PF e PJ) como padrão
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Popular Subcategorias'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecione o tipo de pessoa:'),
                const SizedBox(height: 16),
                ...tipoPessoaOptions.map((option) => ListTile(
                      title: Text(option),
                      leading: Icon(selected == option ? Icons.radio_button_checked : Icons.radio_button_off),
                      onTap: () => setDialogState(() => selected = option),
                    )),
              ],
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

    final recebimentosDefaults = defaultService.getRecebimentosChildDefaults(tipoPessoa: tipoPessoa);
    final parentName = parentCategory.categoria;

    int categoriesCreated = 0;

    // Carregar categorias existentes
    final existingCategories = await DatabaseHelper.instance.readAccountCategories(_recebimentosType!.id!);
    final existingNames = {for (final cat in existingCategories) cat.categoria.toUpperCase()};

    // Se temos subcategorias padrão para este pai
    if (recebimentosDefaults.containsKey(parentName)) {
      for (final child in recebimentosDefaults[parentName]!) {
        final fullName = defaultService.buildRecebimentosChildName(parentName, child);
        if (!existingNames.contains(fullName.toUpperCase())) {
          // Obter ícone específico para este filho
          final childLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(parentName, child);
          await DatabaseHelper.instance.createAccountCategory(
            AccountCategory(
              accountId: _recebimentosType!.id!,
              categoria: fullName,
              logo: childLogo,
            ),
          );
          categoriesCreated++;
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            categoriesCreated > 0
                ? '$categoriesCreated subcategorias adicionadas!'
                : 'Todas as subcategorias padrão já existem!',
          ),
          backgroundColor: categoriesCreated > 0 ? Colors.green : Colors.orange,
        ),
      );
    }

    // SEMPRE atualizar ícones
    await _assignIntelligentLogos();
    
    refreshData();
  }
}