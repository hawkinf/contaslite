import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import 'credit_card_screen.dart';
import 'dashboard_screen.dart';
import 'recebimentos_screen.dart';
import 'settings_screen.dart';

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
      body: Column(
        children: [
          // Fixed Navigation Bar
          Container(
            color: const Color(0xFF4A6FA5),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                _buildNavButton(0, 'Contas a Pagar', Icons.assignment),
                const SizedBox(width: 48),
                _buildNavButton(1, 'Contas a Receber', Icons.account_balance_wallet),
                const SizedBox(width: 48),
                _buildNavButton(2, 'Cartões', Icons.credit_card),
                const SizedBox(width: 48),
                _buildNavButton(3, 'Preferências', Icons.settings),
              ],
            ),
          ),
          // Content Area
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 2,
              width: 40,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}

