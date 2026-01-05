import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import 'credit_card_screen.dart';
import 'dashboard_screen.dart';
import 'recebimentos_screen.dart';
import 'settings_screen.dart';
import 'database_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final VoidCallback _tabRequestListener;

  // Lazy-load screens to avoid initializing all screens on startup
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // Primeira aba: Contas a Pagar (exclui Recebimentos)
      const DashboardScreen(excludeTypeNameFilter: 'Recebimentos'),
      // Segunda aba: Contas a Receber
      const RecebimentosScreen(),
      // Terceira aba: Cartões
      const CreditCardScreen(),
      // Quarta aba: Preferências
      const SettingsScreen(),
      // Quinta aba: Calendário (placeholder)
      const SizedBox.shrink(),
      // Sexta aba: Feriados (placeholder)
      const SizedBox.shrink(),
      // Sétima aba: Tabelas (Database)
      const DatabaseScreen(),
    ];
    _tabRequestListener = () {
      final requested = PrefsService.tabRequestNotifier.value;
      if (requested == null || requested == _selectedIndex) return;
      setState(() => _selectedIndex = requested);
      PrefsService.tabRequestNotifier.value = null;
    };
    PrefsService.tabRequestNotifier.addListener(_tabRequestListener);
  }

  @override
  void dispose() {
    PrefsService.tabRequestNotifier.removeListener(_tabRequestListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}

