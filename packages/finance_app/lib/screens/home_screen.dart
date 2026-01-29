import 'package:flutter/material.dart';
import '../services/app_startup_controller.dart';
import '../services/export_controller.dart';
import '../services/prefs_service.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'tables_home_screen.dart';
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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late final VoidCallback _tabRequestListener;
  final ExportController _exportController = ExportController();

  // Screens for each tab
  late final List<Widget> _screens;

  // Tab definitions
  static const _tabs = [
    _TabInfo(icon: Icons.receipt_long, label: 'Contas'),
    _TabInfo(icon: Icons.calendar_month, label: 'Calendário'),
    _TabInfo(icon: Icons.celebration, label: 'Feriados'),
    _TabInfo(icon: Icons.table_chart, label: 'Tabelas'),
    _TabInfo(icon: Icons.settings, label: 'Config'),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      // Contas (Dashboard)
      const DashboardScreen(),
      // Calendário
      const CalendarScreen(),
      // Feriados
      const HolidaysScreen(),
      // Tabelas (Menu)
      const TablesHomeScreen(),
      // Configurações
      const SettingsScreen(),
    ];

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Usar AppStartupController para determinar a aba inicial
    // Prioriza: 1) widget.initialTabIndex se especificado, 2) AppStartupController
    final requestedIndex = widget.initialTabIndex != 0
        ? widget.initialTabIndex
        : AppStartupController.initialTabIndex;
    if (requestedIndex >= 0 && requestedIndex < _screens.length) {
      _tabController.index = requestedIndex;
    }

    _tabController.addListener(_onTabChanged);

    _tabRequestListener = () {
      final requested = PrefsService.tabRequestNotifier.value;
      if (requested == null || requested == _tabController.index) return;
      if (requested >= 0 && requested < _tabs.length) {
        _tabController.animateTo(requested);
      }
      PrefsService.tabRequestNotifier.value = null;
    };
    PrefsService.tabRequestNotifier.addListener(_tabRequestListener);

    // Disparar jumpToToday no primeiro frame se estiver na aba Contas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabController.index == 0) {
        AppStartupController.triggerJumpToToday();
      }
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Persistir aba atual para restauração futura
    AppStartupController.saveCurrentTab(_tabController.index);
    setState(() {});
  }

  /// Retorna o nome da aba atual para exibição
  String _getCurrentTabName() {
    switch (_tabController.index) {
      case 0:
        return 'Contas';
      case 1:
        return 'Calendário';
      case 2:
        return 'Feriados';
      case 3:
        return 'Tabelas';
      case 4:
        return 'Configurações';
      default:
        return 'Relatório';
    }
  }

  /// Verifica se a aba atual suporta exportação PDF
  bool _canExportCurrentTab() {
    // Abas que suportam exportação: Contas (0) e Calendário (1)
    return _tabController.index == 0 || _tabController.index == 1;
  }

  Future<void> exportCurrentViewToPdf() async {
    await _exportController.exportCurrentViewToPdf(
      context: context,
      selectedIndex: _tabController.index,
      currentTabName: _getCurrentTabName(),
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    PrefsService.tabRequestNotifier.removeListener(_tabRequestListener);
    super.dispose();
  }

  /// Find the next upcoming holiday
  Map<String, dynamic>? _findNextHoliday(String city) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // National holidays with names (fixed dates)
    final nationalHolidays = [
      {'month': 1, 'day': 1, 'name': 'Ano Novo'},
      {'month': 4, 'day': 21, 'name': 'Tiradentes'},
      {'month': 5, 'day': 1, 'name': 'Dia do Trabalho'},
      {'month': 9, 'day': 7, 'name': 'Independência'},
      {'month': 10, 'day': 12, 'name': 'N. Sra. Aparecida'},
      {'month': 11, 'day': 2, 'name': 'Finados'},
      {'month': 11, 'day': 15, 'name': 'Proclamação da República'},
      {'month': 12, 'day': 25, 'name': 'Natal'},
    ];

    // Calculate Easter-based holidays for this year and next
    DateTime easterDate(int year) {
      final a = year % 19;
      final b = year ~/ 100;
      final c = year % 100;
      final d = b ~/ 4;
      final e = b % 4;
      final f = (b + 8) ~/ 25;
      final g = (b - f + 1) ~/ 3;
      final h = (19 * a + b - d - g + 15) % 30;
      final i = c ~/ 4;
      final k = c % 4;
      final l = (32 + 2 * e + 2 * i - h - k) % 7;
      final m = (a + 11 * h + 22 * l) ~/ 451;
      final month = (h + l - 7 * m + 114) ~/ 31;
      final day = ((h + l - 7 * m + 114) % 31) + 1;
      return DateTime(year, month, day);
    }

    List<Map<String, dynamic>> allHolidays = [];

    // Add fixed holidays for current and next year
    for (final year in [now.year, now.year + 1]) {
      for (final h in nationalHolidays) {
        allHolidays.add({
          'date': DateTime(year, h['month'] as int, h['day'] as int),
          'name': h['name'],
        });
      }

      // Easter-based holidays
      final easter = easterDate(year);
      allHolidays.addAll([
        {'date': easter.subtract(const Duration(days: 47)), 'name': 'Carnaval'},
        {'date': easter.subtract(const Duration(days: 2)), 'name': 'Sexta-feira Santa'},
        {'date': easter, 'name': 'Páscoa'},
        {'date': easter.add(const Duration(days: 60)), 'name': 'Corpus Christi'},
      ]);
    }

    // Sort by date and find the next one
    allHolidays.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    for (final holiday in allHolidays) {
      final holidayDate = holiday['date'] as DateTime;
      if (!holidayDate.isBefore(today)) {
        return holiday;
      }
    }

    return null;
  }

  /// Build the next holiday badge widget
  Widget? _buildHolidayBadge(BuildContext context) {
    final city = PrefsService.cityNotifier.value;
    final nextHoliday = _findNextHoliday(city);

    if (nextHoliday == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final holidayDate = nextHoliday['date'] as DateTime;
    final daysUntil = holidayDate.difference(today).inDays;

    if (daysUntil > 60) return null; // Only show if within 60 days

    final holidayName = nextHoliday['name'] as String;
    final daysText = daysUntil == 0
        ? 'Hoje!'
        : daysUntil == 1
            ? 'Amanhã'
            : 'Faltam $daysUntil dias';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.amber.shade600,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.celebration,
            size: 14,
            color: Colors.brown.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            '$holidayName • $daysText',
            style: TextStyle(
              color: Colors.brown.shade900,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.blue.shade900 : Colors.blue.shade700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'FácilFin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Holiday badge
          if (_buildHolidayBadge(context) != null)
            _buildHolidayBadge(context)!,
          // Export PDF button (visible on all tabs, but only Contas exports for now)
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: _canExportCurrentTab()
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
            tooltip: 'Exportar PDF',
            onPressed: exportCurrentViewToPdf,
          ),
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            onPressed: () {
              PrefsService.saveTheme(!isDark);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 12,
          ),
          tabs: _tabs.map((tab) => Tab(
            icon: Icon(tab.icon, size: 20),
            text: tab.label,
          )).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe to prevent accidental navigation
        children: _screens,
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String label;

  const _TabInfo({required this.icon, required this.label});
}
