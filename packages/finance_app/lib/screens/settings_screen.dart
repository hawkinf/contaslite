import 'package:flutter/material.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import 'database_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _cities;
  late String _selectedCity;
  late bool _isDark;
  bool _citiesInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize from notifiers in initState to avoid blocking during widget construction
    _selectedCity = PrefsService.cityNotifier.value;
    _isDark = PrefsService.themeNotifier.value == ThemeMode.dark;
    // Initialize cities immediately to avoid late initialization errors
    _initializeCities();
  }

  void _initializeCities() {
    if (!_citiesInitialized) {
      _cities = HolidayService.regions.values.expand((items) => items).toSet().toList()
        ..sort();
      _citiesInitialized = true;

      if (!_cities.contains(_selectedCity) && _cities.isNotEmpty) {
        _selectedCity = _cities.first;
      }
    }
  }

  // Ensure cities are initialized before use
  void _ensureCitiesInitialized() {
    if (!_citiesInitialized) {
      _initializeCities();
    }
  }

  String _regionForCity(String city) {
    for (final entry in HolidayService.regions.entries) {
      if (entry.value.contains(city)) {
        return entry.key;
      }
    }
    return HolidayService.regions.keys.first;
  }


  void _showCitySelector() {
    _ensureCitiesInitialized();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCities = searchController.text.isEmpty
              ? _cities
              : _cities
                  .where((city) =>
                      city.toLowerCase().contains(searchController.text.toLowerCase()))
                  .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? 400 : 600,
                maxHeight: isMobile ? 600 : 500,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selecionar Cidade',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          searchController.dispose();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar cidade...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off,
                                    size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma cidade encontrada',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredCities.length,
                            itemBuilder: (context, index) {
                              final city = filteredCities[index];
                              final isSelected = city == _selectedCity;
                              return ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                ),
                                title: Text(city),
                                subtitle: Text(_regionForCity(city)),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: Theme.of(context).colorScheme.primary,
                                      )
                                    : null,
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedCity = city;
                                  });
                                  PrefsService.saveLocation(_regionForCity(city), city);
                                  searchController.dispose();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferências'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    size: 60,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contas a Pagar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'v1.00 (Build 20251208)',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Desenvolvido por\nAguinaldo Liesack Baptistini',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 40, thickness: 1),
          const Text(
            'Aparência',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          SwitchListTile(
            title: const Text('Modo Escuro'),
            value: _isDark,
            onChanged: (val) {
              setState(() => _isDark = val);
              PrefsService.saveTheme(val);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Localização (Feriados)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _showCitySelector,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cidade Selecionada',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedCity,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.location_on,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            tileColor: Colors.blueGrey.shade50,
            leading: const Icon(Icons.storage, color: Colors.blueGrey, size: 30),
            title: const Text('Banco de dados'),
            subtitle: const Text('Backup, restauração e manutenção', maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DatabaseScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
