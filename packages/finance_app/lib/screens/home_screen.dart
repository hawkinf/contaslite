import 'package:flutter/material.dart';
import '../services/prefs_service.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'database_screen.dart';
import 'holidays_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
  });

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
      // Preferências
      const SettingsScreen(),
      // Calendário
      const CalendarScreen(),
      // Feriados
      const HolidaysScreen(),
      // Tabelas (Database)
      const DatabaseScreen(),
    ];
    final requestedIndex = widget.initialTabIndex;
    _selectedIndex = (requestedIndex >= 0 && requestedIndex < _screens.length) ? requestedIndex : 0;
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
