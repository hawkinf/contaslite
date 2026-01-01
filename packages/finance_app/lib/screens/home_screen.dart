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

  final List<Widget> _screens = [
    const DashboardScreen(),
    const RecebimentosScreen(),
    const CreditCardScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
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

