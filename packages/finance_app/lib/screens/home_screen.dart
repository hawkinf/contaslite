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
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ContasPRO'),
            Text(
              'by Aguinaldo Liesack Baptistini',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4A6FA5),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Tabs Navigation Bar
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(0, 'Contas a Pagar', Icons.assignment),
                  _buildTab(1, 'Contas a Receber', Icons.account_balance_wallet),
                  _buildTab(2, 'Cartões', Icons.credit_card),
                  _buildTab(3, 'Calendário', Icons.calendar_today),
                  _buildTab(4, 'Feriados', Icons.event_note),
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens + [
                const SizedBox.shrink(), // Placeholder for Calendário
                const SizedBox.shrink(), // Placeholder for Feriados
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

