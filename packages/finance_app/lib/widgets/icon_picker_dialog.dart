import 'package:flutter/material.dart';
import '../services/icon_library_service.dart';

/// Widget para seleção visual de ícones em um grid
class IconPickerDialog extends StatefulWidget {
  final String? initialIcon;
  final VoidCallback? onIconSelected;

  const IconPickerDialog({
    super.key,
    this.initialIcon,
    this.onIconSelected,
  });

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late TextEditingController _searchController;
  String _selectedCategory = '';
  List<String> _displayedIcons = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategory = IconLibraryService.getCategories().first;
    _updateDisplayedIcons();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateDisplayedIcons() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _displayedIcons = IconLibraryService.searchIcons(query);
    } else if (_selectedCategory.isNotEmpty) {
      _displayedIcons = IconLibraryService.getIconsByCategory(_selectedCategory);
    } else {
      _displayedIcons = IconLibraryService.getAllIcons();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Escolha um ícone',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campo de busca
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar ícones...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _updateDisplayedIcons();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                _updateDisplayedIcons();
              },
            ),
            const SizedBox(height: 16),

            // Seletor de categoria
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: const Text('Todos'),
                      selected: _selectedCategory.isEmpty,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = '';
                          _updateDisplayedIcons();
                        });
                      },
                    ),
                  ),
                  ...IconLibraryService.getCategories().map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? category : '';
                            _searchController.clear();
                            _updateDisplayedIcons();
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Grid de ícones
            Expanded(
              child: _displayedIcons.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text('Nenhum ícone encontrado'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _selectedCategory = IconLibraryService.getCategories().first;
                              _updateDisplayedIcons();
                            },
                            child: const Text('Limpar filtros'),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _displayedIcons.length,
                      itemBuilder: (context, index) {
                        final icon = _displayedIcons[index];
                        final isSelected = icon == widget.initialIcon;
                        return Material(
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(icon),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isSelected
                                    ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Informação
            const SizedBox(height: 16),
            Text(
              'Total: ${_displayedIcons.length} ícones disponíveis',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Função auxiliar para abrir o diálogo de seleção de ícones
Future<String?> showIconPickerDialog(
  BuildContext context, {
  String? initialIcon,
}) async {
  return showDialog<String>(
    context: context,
    builder: (context) => IconPickerDialog(initialIcon: initialIcon),
  );
}
