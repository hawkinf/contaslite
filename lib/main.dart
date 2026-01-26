import 'package:finance_app/screens/account_types_screen.dart';
import 'package:finance_app/screens/bank_accounts_screen.dart';
import 'package:finance_app/screens/dashboard_screen.dart' as contas_dash;
import 'package:finance_app/screens/payment_methods_screen.dart';
import 'package:finance_app/screens/recebimentos_table_screen.dart';
import 'package:finance_app/screens/settings_screen.dart';
import 'package:finance_app/database/db_helper.dart';
import 'package:finance_app/services/holiday_service.dart';
import 'package:finance_app/widgets/backup_dialog.dart';
import 'package:finance_app/models/account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:window_manager/window_manager.dart';
import 'widgets/date_calculator_dialog.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/app_spacing.dart';
import 'ui/widgets/app_scaffold.dart';
import 'ui/widgets/month_header.dart';
import 'ui/widgets/filter_bar.dart';
import 'ui/widgets/section_header.dart';
import 'ui/widgets/mini_chip.dart' as ui_chips;
import 'ui/widgets/empty_state.dart';
import 'ui/widgets/date_pill.dart' as ui_date;

import 'package:finance_app/main.dart' as contas_app;
import 'package:finance_app/services/database_initialization_service.dart' as contas_db;
import 'package:finance_app/services/prefs_service.dart' as contas_prefs;
import 'package:finance_app/services/auth_service.dart' as contas_auth;
import 'package:finance_app/services/sync_service.dart' as contas_sync;

import 'contas_bootstrap.dart';


// Versão do App
const String appVersion = '1.50.0';
const String appBuild = '22';
const String apiSource = 'BrasilAPI - https://brasilapi.com.br/api/feriados/v1/';

String get appDisplayVersion {
  final parts = appVersion.split('.');
  if (parts.length >= 2) {
    return '${parts[0]}.${parts[1]}';
  }
  return appVersion;
}

// === INICIALIZAÇÃO E LOCALE ===
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar sqflite_common_ffi antes de qualquer acesso ao banco (desktop)
  await configureContasDatabaseIfNeeded();

  // Inicializar window_manager para desktop
  if (GetPlatform.isDesktop) {
    try {
      await windowManager.ensureInitialized();

      // Usar timeout para evitar travamento
      await windowManager.waitUntilReadyToShow().timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          debugPrint('⚠️ waitUntilReadyToShow timeout, mostrando janela mesmo assim');
          return;
        },
      ).then((_) async {
        try {
          // Carregar tamanho salvo ou usar padrão
          final prefs = await SharedPreferences.getInstance();
          final savedWidth = prefs.getDouble('windowWidth') ?? 1200;
          final savedHeight = prefs.getDouble('windowHeight') ?? 800;

          await windowManager.setSize(Size(savedWidth, savedHeight));
          await windowManager.setResizable(true);
          await windowManager.setMaximizable(true);
          await windowManager.setMinimumSize(const Size(800, 600));
          await windowManager.show();
          debugPrint('✅ Janela inicializada e mostrada com sucesso');
        } catch (e) {
          debugPrint('❌ Erro ao configurar janela: $e');
          try {
            await windowManager.show();
          } catch (e2) {
            debugPrint('❌ Erro ao mostrar janela: $e2');
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Erro ao inicializar window_manager: $e');
    }
  }

  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';
  await contas_prefs.PrefsService.init();

  // Garantir que o módulo financeiro restaure sessão salva (tokens e usuário)
  await contas_auth.AuthService.instance.initialize();

  // Monitorar conectividade para exibir status online/offline
  await contas_sync.SyncService.instance.initialize();

  runApp(const MyApp());
}

// Detectar plataforma
class GetPlatform {
  static bool get isDesktop => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);
}

Color adaptiveSurface(BuildContext context) =>
    Theme.of(context).colorScheme.surface;
Color adaptiveSurfaceVariant(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;
Color adaptiveOutline(BuildContext context) =>
    Theme.of(context).colorScheme.outline;
Color adaptiveOnSurface(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;
Color adaptiveBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

class Holiday {
  final String date;
  final String name;
  final List<String> types;
  final String? specialNote;

  Holiday({required this.date, required this.name, required this.types, this.specialNote});

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: json['date'] as String,
      name: json['name'] as String,
      types: [(json['type'] as String).replaceAll('national', 'Nacional')],
    );
  }

  Holiday mergeWith(Holiday other) {
    final combinedTypes = {...types, ...other.types}.toList();
    return Holiday(
      date: date,
      name: name,
      types: combinedTypes,
      specialNote: specialNote ?? other.specialNote,
    );
  }
}

class CityData {
  final String name;
  final String state;
  final String region;
  final List<Map<String, String>> municipalHolidays;

  CityData({required this.name, required this.state, required this.region, required this.municipalHolidays});
}

class YearlyData {
  final int year;
  final int weekdayHolidays;
  YearlyData(this.year, this.weekdayHolidays);
}

class MonthStats {
  final String monthName;
  int totalDays = 0;
  int weekendDays = 0;

  MonthStats(this.monthName);
}

class HolidayStats {
  int bancarios = 0;
  int nacionais = 0;
  int estaduais = 0;
  int municipais = 0;
  int segundas = 0;
  int tercas = 0;
  int quartas = 0;
  int quintas = 0;
  int sextas = 0;
  int sabados = 0;
  int domingos = 0;
  int diasUteis = 0;
  int finaisSemana = 0;
  int totalFeriadosUnicos = 0;

  final Map<int, MonthStats> monthlyStats = {};

  void addMonthStat(int month, String monthName, bool isWeekend) {
    monthlyStats.putIfAbsent(month, () => MonthStats(monthName));
    monthlyStats[month]!.totalDays++;
    if (isWeekend) {
      monthlyStats[month]!.weekendDays++;
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: contas_prefs.PrefsService.themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'ContasPRO',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('pt', 'BR'),
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const HolidayScreen(),
        );
      },
    );
  }
}

// =======================================================
// === TELA PRINCIPAL ===
// =======================================================

class HolidayScreen extends StatefulWidget {
  final DateTime? initialDate;

  const HolidayScreen({super.key, this.initialDate});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> with TickerProviderStateMixin {
  late int _selectedYear;
  late int _calendarMonth;
  late DateTime _selectedWeek;
  String _calendarType = 'semanal'; // 'semanal', 'mensal', 'anual'
  late CityData _selectedCity;
  late Future<List<Holiday>> _holidaysFuture;
  late Future<void> _contasInitFuture;
  late Future<Map<int, ({double previsto, double lancado, int previstoCount, int lancadoCount, double recebimentos, int recebimentosCount, double avulsas, int avulsasCount, double recebimentosPrevisto, int recebimentosPrevistoCount, double recebimentosAvulsas, int recebimentosAvulsasCount})>>
      _monthlyTotalsFuture;
  Future<Map<int, ({double pagar, double receber})>> _annualTotalsFuture = Future.value({});
  late AnimationController _animationController;
  late TabController _tabController;
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _skipNextContasReset = false;
  final Map<int, Future<List<Holiday>>> _holidaysCache = {};
  double _horizontalDragDistance = 0;
  ({Holiday? holiday, int daysUntil})? _nextHolidayData;

  // GlobalKeys para capturar screenshots dos calendários
  final GlobalKey _calendarGridKey = GlobalKey();
  final GlobalKey _annualCalendarKey = GlobalKey();

  final List<int> availableYears = List.generate(11, (index) => DateTime.now().year - 5 + index);

  late final List<CityData> cities;

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? DateTime.now();
    _selectedWeek = date;
    _selectedYear = date.year;
    _calendarMonth = date.month;

    // Inicializar cidades ANTES de usar em outros métodos
    _initializeCities();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 0) {
        if (_skipNextContasReset) {
          _skipNextContasReset = false;
        } else {
          _resetContasDateRangeIfSingleDay();
        }
      }
      if (_tabController.index == 1 && mounted) {
        setState(() {
          _monthlyTotalsFuture = _loadMonthlyTotals(_calendarMonth, _selectedYear);
        });
      }
    });
    contas_prefs.PrefsService.tabRequestNotifier.addListener(_handleTabRequest);
    
    // Inicializar _holidaysFuture antes de qualquer coisa
    _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
    _contasInitFuture = configureContasDatabaseIfNeeded();
    _monthlyTotalsFuture = _loadMonthlyTotals(_calendarMonth, _selectedYear);
    _annualTotalsFuture = _loadAnnualTotals(_selectedYear);

    // Carregar próximo feriado
    _getNextHoliday().then((data) {
      if (mounted) {
        setState(() {
          _nextHolidayData = data;
        });
      }
    });
    
    contas_prefs.PrefsService.cityNotifier.addListener(_syncCityFromPrefs);
    _loadPreferences();
    
    // Setup para salvar tamanho da janela periodicamente em desktop
    if (GetPlatform.isDesktop) {
      Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) _saveWindowSize();
      });
    }

    // Mostrar dialog de backup após a tela inicializar (apenas se a opção estiver ativada)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && contas_prefs.PrefsService.askBackupOnStartup) {
        BackupDialogHelper.showBackupDialog(this);
      }
    });
  }

  Widget _buildThemeToggleButton({required Color iconColor, required double iconSize}) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: contas_prefs.PrefsService.themeNotifier,
      builder: (context, mode, _) {
        final isDarkModeActive = mode == ThemeMode.dark;
        return IconButton(
          icon: Icon(isDarkModeActive ? Icons.dark_mode : Icons.light_mode),
          iconSize: iconSize,
          color: iconColor,
          tooltip: isDarkModeActive ? 'Ativar modo claro' : 'Ativar modo escuro',
          onPressed: () {
            contas_prefs.PrefsService.saveTheme(!isDarkModeActive);
          },
        );
      },
    );
  }


  Future<void> _saveWindowSize() async {
    try {
      final size = await windowManager.getSize();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('windowWidth', size.width);
      await prefs.setDouble('windowHeight', size.height);
    } catch (e) {
      debugPrint('Erro ao salvar tamanho da janela: $e');
    }
  }

  void _changeYear(int delta) {
    if (delta == 0) return;
    setState(() {
      _selectedYear += delta;
      _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
      _monthlyTotalsFuture = _loadMonthlyTotals(_calendarMonth, _selectedYear);
      _annualTotalsFuture = _loadAnnualTotals(_selectedYear);
    });
  }

  void _resetContasDateRangeIfSingleDay() {
    final range = contas_prefs.PrefsService.dateRangeNotifier.value;
    if (!DateUtils.isSameDay(range.start, range.end)) return;
    final monthStart = DateTime(_selectedYear, _calendarMonth, 1);
    final monthEnd = DateTime(_selectedYear, _calendarMonth + 1, 0);
    contas_prefs.PrefsService.saveDateRange(monthStart, monthEnd);
  }

  void _handleTabRequest() {
    final index = contas_prefs.PrefsService.tabRequestNotifier.value;
    if (index == null) return;
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
    contas_prefs.PrefsService.tabRequestNotifier.value = null;
  }

  void _changeMonth(int delta) {
    if (delta == 0) return;
    setState(() {
      int newMonth = _calendarMonth + delta;
      int newYear = _selectedYear;

      while (newMonth < 1) {
        newMonth += 12;
        newYear--;
      }
      while (newMonth > 12) {
        newMonth -= 12;
        newYear++;
      }

      final yearChanged = newYear != _selectedYear;
      _calendarMonth = newMonth;
      _selectedYear = newYear;
      if (yearChanged) {
        _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
      }
      _monthlyTotalsFuture = _loadMonthlyTotals(_calendarMonth, _selectedYear);
    });
  }

  void _changeWeek(int deltaWeeks) {
    if (deltaWeeks == 0) return;
    setState(() {
      _selectedWeek = _selectedWeek.add(Duration(days: 7 * deltaWeeks));
      if (_selectedWeek.year != _selectedYear) {
        _selectedYear = _selectedWeek.year;
        _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
      }
    });
  }

  void _handleHorizontalSwipe(
    DragEndDetails details, {
    required VoidCallback onSwipeLeft,
    required VoidCallback onSwipeRight,
  }) {
    const distanceThreshold = 65;
    const velocityThreshold = 240;
    final dragDistance = _horizontalDragDistance;
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (dragDistance.abs() >= distanceThreshold) {
      if (dragDistance < 0) {
        onSwipeLeft();
      } else {
        onSwipeRight();
      }
    } else if (velocity.abs() >= velocityThreshold) {
      if (velocity < 0) {
        onSwipeLeft();
      } else {
        onSwipeRight();
      }
    }

    _horizontalDragDistance = 0;
  }

  Widget _buildAnnualMonthCard({
    required BuildContext context,
    required int monthIndex,
    required DateTime now,
    required Map<String, String> holidayNames,
    required Set<String> holidayDays,
    required Map<int, ({double pagar, double receber})> annualTotals,
    required bool totalsReady,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 600;
    final month = monthIndex + 1;
    final monthNames = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    final firstDayOfMonth = DateTime(_selectedYear, month, 1);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(_selectedYear, month + 1, 0).day;
    final colorScheme = Theme.of(context).colorScheme;
    final baseDayColor = colorScheme.surfaceContainerHighest;
    final weekendBgColor = colorScheme.surfaceContainerLow;
    final saturdayTextColor = colorScheme.onSurfaceVariant;
    final sundayTextColor = colorScheme.error;
    final holidayBgColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.12),
      colorScheme.surface,
    );
    final holidayTextColor = colorScheme.primary;
    final neutralTextColor = colorScheme.onSurface;
    final holidayEntryColor = colorScheme.onSurfaceVariant;
    final moneyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final monthTotals = annualTotals[month];
    final totalPagar = monthTotals?.pagar ?? 0.0;
    final totalReceber = monthTotals?.receber ?? 0.0;

    final monthHolidayEntries = <MapEntry<int, String>>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final entryKey = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final entryName = holidayNames[entryKey];
      if (entryName != null) {
        monthHolidayEntries.add(MapEntry(day, entryName));
      }
    }
    final visibleHolidayEntries = monthHolidayEntries.take(2).toList();
    final remainingHolidaysCount = monthHolidayEntries.length - 2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(0.5),
        child: Column(
          mainAxisSize: isSmallMobile ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    monthNames[monthIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isSmallMobile ? 12 : 14, fontWeight: FontWeight.w900, color: neutralTextColor),
                  ),
                  if (totalsReady && (totalPagar > 0 || totalReceber > 0)) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (totalPagar > 0) ...[
                          Icon(Icons.arrow_downward, size: isSmallMobile ? 8 : 9, color: colorScheme.error),
                          const SizedBox(width: 2),
                          Text(
                            moneyFormat.format(totalPagar),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 7.5 : 8.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                        if (totalPagar > 0 && totalReceber > 0) ...[
                          const SizedBox(width: 4),
                          Text('|', style: TextStyle(fontSize: isSmallMobile ? 7 : 8, color: neutralTextColor.withValues(alpha: 0.5))),
                          const SizedBox(width: 4),
                        ],
                        if (totalReceber > 0) ...[
                          Icon(Icons.arrow_upward, size: isSmallMobile ? 8 : 9, color: colorScheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            moneyFormat.format(totalReceber),
                            style: TextStyle(
                              fontSize: isSmallMobile ? 7.5 : 8.5,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                  .map(
                    (day) => Expanded(
                      child: Center(
                          child: Text(
                            day,
                            style: TextStyle(fontSize: isSmallMobile ? 7 : 8, fontWeight: FontWeight.bold, color: neutralTextColor),
                          ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalCells = firstDayOfWeek + daysInMonth;
                final rowCount = (totalCells / 7).ceil();
                final availableWidth = constraints.maxWidth - 4; // grid padding (2 horizontal)
                final cellWidth = availableWidth / 7;
                final cellHeight = cellWidth / 1.05; // matches childAspectRatio
                final gridHeight = rowCount * cellHeight;

                return SizedBox(
                  height: gridHeight,
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.05,
                      mainAxisSpacing: 0,
                      crossAxisSpacing: 0,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) {
                      if (index < firstDayOfWeek) {
                        return const SizedBox.shrink();
                      }

                      final day = index - firstDayOfWeek + 1;
                      final dateObj = DateTime(_selectedYear, month, day);
                      final dayOfWeek = dateObj.weekday % 7;
                      final isToday = now.year == _selectedYear && now.month == month && now.day == day;
                      final holidayKey = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final isHoliday = holidayDays.contains(holidayKey);

                      Color bgColor = baseDayColor;
                      Color dayTextColor = neutralTextColor;
                      bool showTodayBorder = false;

                      if (isToday) {
                        bgColor = Color.alphaBlend(
                          colorScheme.primary.withValues(alpha: 0.12),
                          colorScheme.surface,
                        );
                        dayTextColor = colorScheme.primary;
                        showTodayBorder = true;
                      } else if (isHoliday) {
                        bgColor = holidayBgColor; // Azul claro
                        dayTextColor = holidayTextColor; // Azul escuro
                      } else if (dayOfWeek == 0) { // Domingo
                        bgColor = weekendBgColor; // Fundo cinza claro
                        dayTextColor = sundayTextColor; // Texto vermelho
                      } else if (dayOfWeek == 6) { // Sábado
                        bgColor = weekendBgColor; // Fundo cinza claro
                        dayTextColor = saturdayTextColor; // Texto cinza
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: showTodayBorder
                                ? colorScheme.primary
                                : colorScheme.outlineVariant.withValues(alpha: 0.6),
                            width: showTodayBorder ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            day.toString(),
                            style: TextStyle(fontSize: isSmallMobile ? 10 : 13, fontWeight: FontWeight.w700, color: dayTextColor),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            if (visibleHolidayEntries.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in visibleHolidayEntries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '${entry.key} - ${entry.value}',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 8 : 9,
                            fontWeight: FontWeight.w600,
                            color: holidayEntryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (remainingHolidaysCount > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          '+$remainingHolidaysCount feriado${remainingHolidaysCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: isSmallMobile ? 8 : 9,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: holidayEntryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }
  
  void _initializeCities() {
    cities = [
      // === SP E GRANDE SP ===
      CityData(name: 'São Paulo', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-01-25', 'name': 'Aniversário de São Paulo'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santo André', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-08', 'name': 'Aniversário de Santo André'}]),
      CityData(name: 'São Bernardo do Campo', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-08-20', 'name': 'Aniversário de São Bernardo'}]),
      CityData(name: 'São Caetano do Sul', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-07-28', 'name': 'Aniversário de São Caetano'}]),
      CityData(name: 'Diadema', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Diadema'}]),
      CityData(name: 'Mauá', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Mauá'}]),
      CityData(name: 'Ribeirão Pires', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Ribeirão Pires'}]),
      CityData(name: 'Rio Grande da Serra', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-05-03', 'name': 'Aniversário de Rio Grande da Serra'}]),
      CityData(name: 'Guarulhos', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-12-08', 'name': 'Aniversário de Guarulhos'}]),
      CityData(name: 'Osasco', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-02-19', 'name': 'Aniversário de Osasco'}]),
      CityData(name: 'Barueri', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-03-26', 'name': 'Aniversário de Barueri'}]),
      CityData(name: 'Cotia', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-02', 'name': 'Aniversário de Cotia'}]),
      CityData(name: 'Taboão da Serra', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-02-19', 'name': 'Aniversário de Taboão'}]),
      CityData(name: 'Mogi das Cruzes', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-09-01', 'name': 'Aniversário de Mogi'}]),
      CityData(name: 'Suzano', state: 'SP', region: 'SP e Grande SP', municipalHolidays: [{'date': '-04-02', 'name': 'Aniversário de Suzano'}]),

      // === LITORAL SUL ===
      CityData(name: 'Santos', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-26', 'name': 'Aniversário de Santos'}, {'date': '-09-08', 'name': 'Nossa Senhora do Monte Serrat'}]),
      CityData(name: 'São Vicente', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-22', 'name': 'Aniversário de São Vicente'}]),
      CityData(name: 'Guarujá', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-06-30', 'name': 'Aniversário de Guarujá'}]),
      CityData(name: 'Praia Grande', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-01-19', 'name': 'Aniversário de Praia Grande'}]),
      CityData(name: 'Cubatão', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-04-09', 'name': 'Aniversário de Cubatão'}]),
      CityData(name: 'Bertioga', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-05-19', 'name': 'Aniversário de Bertioga'}]),
      CityData(name: 'Mongaguá', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-12-07', 'name': 'Aniversário de Mongaguá'}]),
      CityData(name: 'Itanhaém', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-04-22', 'name': 'Aniversário de Itanhaém'}]),
      CityData(name: 'Peruíbe', state: 'SP', region: 'Litoral Sul', municipalHolidays: [{'date': '-02-18', 'name': 'Aniversário de Peruíbe'}]),

      // === VALE DO PARAÍBA ===
      CityData(name: 'Caçapava', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-14', 'name': 'Aniversário de Caçapava'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Igaratá', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-27', 'name': 'Aniversário de Igaratá'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Jacareí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-08', 'name': 'Aniversário de Jacareí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Jambeiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-24', 'name': 'Aniversário de Jambeiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Monteiro Lobato', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-24', 'name': 'Aniversário de Monteiro Lobato'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Paraibuna', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-14', 'name': 'Aniversário de Paraibuna'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santa Branca', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-04', 'name': 'Aniversário de Santa Branca'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São José dos Campos', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Dia de São José'}, {'date': '-07-27', 'name': 'Aniversário de São José dos Campos'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Campos do Jordão', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-15', 'name': 'Aniversário de Campos do Jordão'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lagoinha', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Lagoinha'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Natividade da Serra', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Natividade da Serra'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Pindamonhangaba', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-07-10', 'name': 'Aniversário de Pindamonhangaba'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Redenção da Serra', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-19', 'name': 'Aniversário de Redenção da Serra'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Santo Antônio do Pinhal', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-05-13', 'name': 'Aniversário de Santo Antônio do Pinhal'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São Bento do Sapucaí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-21', 'name': 'Aniversário de São Bento do Sapucaí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São Luiz do Paraitinga', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-05-08', 'name': 'Aniversário de São Luiz do Paraitinga'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Taubaté', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-05', 'name': 'Aniversário de Taubaté'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Tremembé', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Tremembé'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Aparecida', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-09-08', 'name': 'Aniversário de Aparecida'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cachoeira Paulista', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-28', 'name': 'Aniversário de Cachoeira Paulista'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Canas', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-20', 'name': 'Aniversário de Canas'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cunha', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-04-15', 'name': 'Aniversário de Cunha'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Guaratinguetá', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-02-13', 'name': 'Aniversário de Guaratinguetá'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lorena', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-06-24', 'name': 'Aniversário de Lorena'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Piquete', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-28', 'name': 'Aniversário de Piquete'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Potim', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Potim'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Roseira', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-27', 'name': 'Aniversário de Roseira'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Arapeí', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-02-26', 'name': 'Aniversário de Arapeí'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Areias', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-11-24', 'name': 'Aniversário de Areias'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Bananal', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-11-21', 'name': 'Aniversário de Bananal'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Cruzeiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-10-16', 'name': 'Aniversário de Cruzeiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Lavrinhas', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-12-19', 'name': 'Aniversário de Lavrinhas'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Queluz', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-01-08', 'name': 'Aniversário de Queluz'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'São José do Barreiro', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-08-24', 'name': 'Aniversário de São José do Barreiro'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      CityData(name: 'Silveiras', state: 'SP', region: 'Vale do Paraíba', municipalHolidays: [{'date': '-07-26', 'name': 'Aniversário de Silveiras'}, {'date': '-11-20', 'name': 'Dia da Consciência Negra'}]),
      
      // === LITORAL NORTE ===
      CityData(name: 'Caraguatatuba', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-04-20', 'name': 'Aniversário de Caraguatatuba'}]),
      CityData(name: 'Ilhabela', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-09-03', 'name': 'Aniversário de Ilhabela'}]),
      CityData(name: 'São Sebastião', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-03-16', 'name': 'Aniversário de São Sebastião'}, {'date': '-01-20', 'name': 'Dia de São Sebastião'}]),
      CityData(name: 'Ubatuba', state: 'SP', region: 'Litoral Norte', municipalHolidays: [{'date': '-10-28', 'name': 'Aniversário de Ubatuba'}]),
      
      // === SUL DE MINAS (COM FERIADOS PREENCHIDOS) ===
      CityData(name: 'Alfenas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-15', 'name': 'Aniversário de Alfenas'}]),
      CityData(name: 'Andradas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-02-22', 'name': 'Aniversário de Andradas'}]),
      CityData(name: 'Boa Esperança', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-15', 'name': 'Aniversário de Boa Esperança'}]),
      CityData(name: 'Brazópolis', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Brazópolis'}]),
      CityData(name: 'Cambuí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-13', 'name': 'Aniversário de Cambuí'}]),
      CityData(name: 'Campanha', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-04-12', 'name': 'Feriado Padre Victor'}]),
      CityData(name: 'Campo Belo', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-28', 'name': 'Aniversário de Campo Belo'}]),
      CityData(name: 'Campos Gerais', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Campos Gerais'}]),
      CityData(name: 'Carmo de Minas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Carmo de Minas'}]),
      CityData(name: 'Caxambu', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Caxambu'}]),
      CityData(name: 'Conceição do Rio Verde', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-08-23', 'name': 'Aniversário de Conceição do Rio Verde'}]),
      CityData(name: 'Cristina', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-15', 'name': 'Aniversário de Cristina'}]),
      CityData(name: 'Extrema', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-16', 'name': 'Aniversário de Extrema'}]),
      CityData(name: 'Guaxupé', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-06-01', 'name': 'Aniversário de Guaxupé'}]),
      CityData(name: 'Itajubá', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-03-19', 'name': 'Aniversário de Itajubá'}]),
      CityData(name: 'Itamonte', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-12-17', 'name': 'Aniversário de Itamonte'}]),
      CityData(name: 'Itanhandu', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-07', 'name': 'Aniversário de Itanhandu'}]),
      CityData(name: 'Lavras', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-13', 'name': 'Aniversário de Lavras'}]),
      CityData(name: 'Maria da Fé', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-06-01', 'name': 'Aniversário de Maria da Fé'}]),
      CityData(name: 'Monte Verde (Camanducaia)', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-20', 'name': 'Aniversário de Camanducaia'}]),
      CityData(name: 'Ouro Fino', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-03-16', 'name': 'Aniversário de Ouro Fino'}]),
      CityData(name: 'Paraisópolis', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-01-25', 'name': 'Aniversário de Paraisópolis'}]),
      CityData(name: 'Passa Quatro', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-01', 'name': 'Aniversário de Passa Quatro'}]),
      CityData(name: 'Passos', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-14', 'name': 'Aniversário de Passos'}]),
      CityData(name: 'Pedralva', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-07', 'name': 'Aniversário de Pedralva'}]),
      CityData(name: 'Piumhi', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-20', 'name': 'Aniversário de Piumhi'}]),
      CityData(name: 'Poços de Caldas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-11-06', 'name': 'Aniversário de Poços de Caldas'}]),
      CityData(name: 'Pouso Alegre', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-19', 'name': 'Aniversário de Pouso Alegre'}]),
      CityData(name: 'Santa Rita do Sapucaí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-05-22', 'name': 'Santa Rita de Cássia'}]),
      CityData(name: 'São Gonçalo do Sapucaí', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-27', 'name': 'Aniversário de São Gonçalo'}]),
      CityData(name: 'São Lourenço', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-04-01', 'name': 'Aniversário de São Lourenço'}]),
      CityData(name: 'São Sebastião do Paraíso', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-25', 'name': 'Aniversário de Paraíso'}]),
      CityData(name: 'Três Corações', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-09-23', 'name': 'Aniversário de Três Corações'}]),
      CityData(name: 'Três Pontas', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-07-03', 'name': 'Aniversário de Três Pontas'}]),
      CityData(name: 'Varginha', state: 'MG', region: 'Sul de Minas', municipalHolidays: [{'date': '-10-07', 'name': 'Aniversário de Varginha'}]),
    ];
    
    final allowedCities = HolidayService.regions.values.expand((items) => items).toSet();
    final allowedNormalized = allowedCities.map(_normalizeCity).toSet();
    cities.removeWhere((city) => !allowedNormalized.contains(_normalizeCity(city.name)));
    cities.sort((a, b) => a.name.compareTo(b.name));

    final preferredCity = contas_prefs.PrefsService.cityNotifier.value;
    _selectedCity = _findCityByName(preferredCity) ?? cities.first;
    final municipalByCity = <String, List<String>>{};
    for (final city in cities) {
      municipalByCity[city.name] = city.municipalHolidays
          .map((holiday) => holiday['date'])
          .whereType<String>()
          .toList();
    }
    HolidayService.setMunicipalHolidays(municipalByCity);
  }

  String _normalizeCity(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  }

  CityData? _findCityByName(String name) {
    final target = _normalizeCity(name);
    for (final city in cities) {
      if (_normalizeCity(city.name) == target) {
        return city;
      }
    }
    return null;
  }

  String _regionForCity(String name) {
    for (final entry in HolidayService.regions.entries) {
      if (entry.value.any((city) => _normalizeCity(city) == _normalizeCity(name))) {
        return entry.key;
      }
    }
    return HolidayService.regions.keys.first;
  }

  void _syncCityFromPrefs() {
    if (!mounted) return;
    final preferredCity = contas_prefs.PrefsService.cityNotifier.value;
    final match = _findCityByName(preferredCity);
    if (match == null || match.name == _selectedCity.name) return;
    setState(() {
      _selectedCity = match;
      _holidaysCache.clear();
      _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    contas_prefs.PrefsService.cityNotifier.removeListener(_syncCityFromPrefs);
    contas_prefs.PrefsService.tabRequestNotifier.removeListener(_handleTabRequest);
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferredCity = contas_prefs.PrefsService.cityNotifier.value;
      final match = _findCityByName(preferredCity);
      if (match != null) {
        _selectedCity = match;
      }
      // Sempre usar data atual, não carregar ano anterior
      _selectedYear = DateTime.now().year;
      _calendarMonth = DateTime.now().month;
      final savedDarkMode = prefs.getBool('isDarkMode');
      if (savedDarkMode != null) _isDarkMode = savedDarkMode;
      final savedCalendarType = prefs.getString('calendarType');
      if (savedCalendarType != null &&
          (savedCalendarType == 'semanal' || savedCalendarType == 'mensal' || savedCalendarType == 'anual')) {
        _calendarType = savedCalendarType;
      }
    } catch (e) {
      debugPrint('Erro: $e');
    }
    _holidaysCache.clear();
    setState(() {
      _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
      _annualTotalsFuture = _loadAnnualTotals(_selectedYear);
      _isLoading = false;
    });
    _animationController.forward();
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Não salvar year pois sempre iniciamos com data atual
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setString('calendarType', _calendarType);
    } catch (e) {
      debugPrint('Erro: $e');
    }
  }

  Future<List<Holiday>> _fetchHolidays(int year) {
    if (_holidaysCache.containsKey(year)) {
      return _holidaysCache[year]!;
    }

    final future = _fetchHolidaysFromApi(year).catchError((error) {
      _holidaysCache.remove(year); // Remove da cache em caso de erro
      throw error;
    });

    _holidaysCache[year] = future;
    return future;
  }



  Future<List<Holiday>> _fetchHolidaysFromApi(int year) async {
    Map<String, Holiday> holidaysMap = {};

    try {
      // 1. Carregar feriados nacionais para o ano especificado
      final uri = Uri.parse('https://brasilapi.com.br/api/feriados/v1/$year');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        List jsonList = json.decode(response.body);
        for (var json in jsonList) {
          try {
            final holiday = Holiday.fromJson(json);
            if (holidaysMap.containsKey(holiday.date)) {
              holidaysMap[holiday.date] = holidaysMap[holiday.date]!.mergeWith(holiday);
            } else {
              holidaysMap[holiday.date] = holiday;
            }
          } catch (e) {
            debugPrint('Erro ao processar feriado nacional: $e');
          }
        }
      } else {
         debugPrint('Falha ao carregar feriados para o ano $year. Código: ${response.statusCode}');
      }

      // 2. Carregar feriados municipais para o ano especificado
      for (var holidayData in _selectedCity.municipalHolidays) {
        final dateStr = '$year${holidayData['date']}';
        try {
          final municipalHoliday = Holiday(date: dateStr, name: holidayData['name']!, types: ['Municipal (${_selectedCity.name})']);
          if (holidaysMap.containsKey(dateStr)) {
            holidaysMap[dateStr] = holidaysMap[dateStr]!.mergeWith(municipalHoliday);
          } else {
            holidaysMap[dateStr] = municipalHoliday;
          }
        } catch(e) {
          debugPrint('Erro ao processar feriado municipal: $dateStr - $e');
        }
      }

      // 3. Adicionar feriado bancário no último dia do ano
      final lastDay = DateTime(year, 12, 31);
      if (lastDay.weekday != DateTime.saturday && lastDay.weekday != DateTime.sunday) {
          String specialNote = 'Agências bancárias não abrem para atendimento ao público.';
          final bancarioHoliday = Holiday(date: '$year-12-31', name: 'Último dia do ano', types: ['Bancário'], specialNote: specialNote);
          
          if (holidaysMap.containsKey(bancarioHoliday.date)) {
            holidaysMap[bancarioHoliday.date] = holidaysMap[bancarioHoliday.date]!.mergeWith(bancarioHoliday);
          } else {
            holidaysMap[bancarioHoliday.date] = bancarioHoliday;
          }
      }
      
      final allHolidays = holidaysMap.values.toList();
      allHolidays.sort((a, b) => a.date.compareTo(b.date));
      return allHolidays;
    } catch (e) {
      throw Exception('Erro de conexão ou dados: $e');
    }
  }

  Future<List<Holiday>> _getHolidaysForDisplay(int year) async {
    final futures = [
      _fetchHolidays(year - 1),
      _fetchHolidays(year),
      _fetchHolidays(year + 1),
    ];

    final results = await Future.wait(futures);
    
    // Combina as 3 listas em uma só
    final allHolidays = results.expand((list) => list).toList();
    
    return allHolidays;
  }

  Future<({Holiday? holiday, int daysUntil})> _getNextHoliday() async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    try {
      final holidays = await _getHolidaysForDisplay(today.year);

      // Encontrar o próximo feriado após hoje
      for (final holiday in holidays) {
        final holidayDate = DateTime.parse(holiday.date);
        if (holidayDate.isAfter(todayDate)) {
          final daysUntil = holidayDate.difference(todayDate).inDays;
          return (holiday: holiday, daysUntil: daysUntil);
        }
      }

      return (holiday: null, daysUntil: 0);
    } catch (e) {
      debugPrint('Erro ao buscar próximo feriado: $e');
      return (holiday: null, daysUntil: 0);
    }
  }

  // --- CALCULADORA DE DATAS ---
  void _showDateCalculator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: FutureBuilder<List<Holiday>>(
          future: _getHolidaysForDisplay(_selectedYear),
          builder: (context, snapshot) {
            final holidays = snapshot.data ?? <Holiday>[];
            return DateCalculatorDialog(
              referenceDate: DateTime.now(),
              holidays: holidays,
              selectedCity: _selectedCity,
            );
          },
        ),
      ),
    );
  }

  Future<Uint8List?> _captureCalendarScreenshot(GlobalKey boundaryKey) async {
    try {
      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        return null;
      }
      final ui.Image image = await renderObject.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Erro ao capturar screenshot: $e');
      return null;
    }
  }

  Future<void> _printReport() async {
    try {
      // Capturar screenshot do calendário mensal se aplicável
      Uint8List? calendarScreenshot;
      GlobalKey? screenshotKey;
      if (_calendarType == 'mensal') {
        screenshotKey = _calendarGridKey;
      } else if (_calendarType == 'anual') {
        screenshotKey = _annualCalendarKey;
      }
      if (screenshotKey != null) {
        calendarScreenshot = await _captureCalendarScreenshot(screenshotKey);
      }

      // Gerar PDF com o relatório completo
      final pdf = pw.Document();
      final productName = 'CalendarPRO v$appDisplayVersion';
      const pageMargin = pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36);
      final generatedAt = DateTime.now();

      // Carregar os dados de feriados
      final holidays = await _holidaysFuture;
      final holidaysCurrentYear = holidays.where((h) {
        try {
          final year = DateTime.parse(h.date).year;
          return year == _selectedYear;
        } catch (e) {
          return false;
        }
      }).toList();

      final stats = _calculateStats(holidaysCurrentYear);

      // Ordenar feriados por data
      final uniqueHolidaysMap = <String, Holiday>{};
      for (var holiday in holidaysCurrentYear) {
        if (!uniqueHolidaysMap.containsKey(holiday.date)) {
          uniqueHolidaysMap[holiday.date] = holiday;
        }
      }
      final sortedHolidays = uniqueHolidaysMap.values.toList();
      sortedHolidays.sort((a, b) => a.date.compareTo(b.date));

      // Criar PDF de múltiplas páginas para o calendário completo
      // Página 1: Calendário do mês selecionado
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pageMargin,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                pw.Text(
                  'RELATÓRIO $productName',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Cidade: ${_selectedCity.name}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),

                // Calendário - Mensal ou Anual
                if ((_calendarType == 'mensal' || _calendarType == 'anual') && calendarScreenshot != null) ...[
                  pw.Text(
                    _calendarType == 'mensal'
                        ? 'CALENDÁRIO - ${_getMonthYearText()}'
                        : 'CALENDÁRIO - $_selectedYear',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    width: double.infinity,
                    alignment: pw.Alignment.center,
                    child: pw.Image(
                      pw.MemoryImage(calendarScreenshot),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  pw.SizedBox(height: 24),
                ] else if (_calendarType == 'anual') ...[
                  pw.Text(
                    'CALENDÁRIO - $_selectedYear',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // Grid de 2 colunas com 6 linhas (2x6 = 12 meses)
                  pw.Column(
                    children: [
                      for (int row = 0; row < 6; row++)
                        pw.SizedBox(
                          width: double.infinity,
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: _buildMiniCalendarPdf(row * 2 + 1, _selectedYear, uniqueHolidaysMap),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: _buildMiniCalendarPdf(row * 2 + 2, _selectedYear, uniqueHolidaysMap),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  pw.SizedBox(height: 24),
                ] else ...[
                  pw.Text(
                    _getMonthYearText(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildCalendarTablePdf(_calendarMonth, _selectedYear, uniqueHolidaysMap),
                  pw.SizedBox(height: 24),
                ],

                // Tabela de Resumo
                pw.Text(
                  'RESUMO $productName - $_selectedYear',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                // Tabela com estatísticas principais
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.blue),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Descrição', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Quantidade', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    ...[
                      ['Total de Feriados', stats.totalFeriadosUnicos.toString()],
                      ['Dias Úteis', stats.diasUteis.toString()],
                      ['Finais de Semana', stats.finaisSemana.toString()],
                    ].asMap().entries.map((entry) {
                      final isEven = entry.key.isEven;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.grey50),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(entry.value[0], style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(entry.value[1], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 12),
              ],
            );
          },
        ),
      );

      // Página 2: Por tipo e lista detalhada de feriados
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pageMargin,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RELATÓRIO $productName',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Cidade: ${_selectedCity.name}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Por Tipo',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.blue),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Tipo de Feriado', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Total', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    ...[
                      ['Nacionais', stats.nacionais.toString(), PdfColors.lightBlue100],
                      ['Municipais', stats.municipais.toString(), PdfColors.yellow100],
                      ['Bancários', stats.bancarios.toString(), PdfColors.cyan100],
                      ['Estaduais', stats.estaduais.toString(), PdfColors.purple100],
                    ].asMap().entries.map((entry) {
                      final label = entry.value[0];
                      final value = entry.value[1];
                      final color = entry.value[2] as PdfColor;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: color),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(label as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(value as String, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Lista Detalhada de Feriados - $_selectedYear',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.blue),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Feriado', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Data', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Dia', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Tipo(s)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                      ],
                    ),
                    ...sortedHolidays.asMap().entries.map((entry) {
                      final isEven = entry.key.isEven;
                      final holiday = entry.value;
                      final date = DateTime.parse(holiday.date);
                      final dayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
                      final dayName = dayNames[date.weekday % 7];
                      final formattedDate = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                      final types = holiday.types.join(', ');

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : PdfColors.grey50),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(holiday.name, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(formattedDate, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(dayName, style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(types, style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Gerado em ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(generatedAt)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
              ],
            );
          },
        ),
      );

      // Mostrar diálogo de impressão
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          return pdf.save();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao imprimir: $e')),
        );
      }
    }
  }

  String _getMonthYearText() {
    final monthNames = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    return 'Calendário - ${monthNames[_calendarMonth - 1]} / $_selectedYear';
  }

  Widget _buildPremiumTab(String label, IconData icon, int index) {
    return AnimatedBuilder(
      animation: _tabController.animation!,
      builder: (context, child) {
        // Calcular progresso de animação para esta aba
        final value = _tabController.animation!.value;
        final animProgress = (value - index).abs().clamp(0.0, 1.0);
        final currentIconSize = 20.0 + (2.0 * (1 - animProgress));
        
        return Tab(
          height: 52,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: currentIconSize),
              const SizedBox(height: 3),
              Text(label),
            ],
          ),
        );
      },
    );
  }

  pw.Widget _buildCalendarTablePdf(int month, int year, Map<String, Holiday> holidayMap) {
    // Replicar exatamente a lógica da tela (_buildCalendarGrid)
    final now = DateTime(year, month, 1);
    final firstDayOfWeek = (now.weekday == 7) ? 0 : now.weekday;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final prevMonthDays = DateTime(year, month, 0).day;

    int prevMonth = month == 1 ? 12 : month - 1;
    int prevYear = month == 1 ? year - 1 : year;

    int nextMonth = month == 12 ? 1 : month + 1;
    int nextYear = month == 12 ? year + 1 : year;

    final List<String> dayHeaders = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    List<({int day, int month, int year, bool isCurrentMonth})> calendarDays = [];

    // Dias do mês anterior
    for (int i = prevMonthDays - firstDayOfWeek + 1; i <= prevMonthDays; i++) {
      calendarDays.add((day: i, month: prevMonth, year: prevYear, isCurrentMonth: false));
    }

    // Dias do mês atual
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add((day: i, month: month, year: year, isCurrentMonth: true));
    }

    // Dias do próximo mês
    int remainingCells = (7 - (calendarDays.length % 7)) % 7;
    for (int i = 1; i <= remainingCells; i++) {
      calendarDays.add((day: i, month: nextMonth, year: nextYear, isCurrentMonth: false));
    }

    final tableRows = <pw.TableRow>[];

    // Cabeçalho com dias da semana
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blue),
        children: dayHeaders.map((dayHeader) {
          final isWeekend = dayHeader == 'DOM' || dayHeader == 'SAB';
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            decoration: pw.BoxDecoration(
              color: isWeekend ? PdfColors.red : PdfColors.blue,
              border: pw.Border.all(color: PdfColors.black, width: 1),
            ),
            child: pw.Text(
              dayHeader,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );

    // Dividir em semanas
    for (int i = 0; i < calendarDays.length; i += 7) {
      final week = calendarDays.sublist(i, i + 7);
      tableRows.add(
        pw.TableRow(
          children: week.map((dayData) {
            final day = dayData.day;
            final dayMonth = dayData.month;
            final dayYear = dayData.year;
            final isCurrentMonth = dayData.isCurrentMonth;
            final dateObj = DateTime(dayYear, dayMonth, day);
            final dayOfWeek = (dateObj.weekday == 7) ? 0 : dateObj.weekday;
            final holidayKey = '$dayYear-${dayMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final isHoliday = holidayMap.containsKey(holidayKey);
            final holidayName = isHoliday ? holidayMap[holidayKey]?.name : null;

            PdfColor bgColor = PdfColors.white;
            PdfColor textColor = PdfColors.black;

            if (isHoliday) {
              bgColor = PdfColors.green;
              textColor = PdfColors.white;
            } else if (dayOfWeek == 0) {
              bgColor = PdfColors.red;
              textColor = PdfColors.white;
            } else if (dayOfWeek == 6) {
              bgColor = PdfColor.fromHex('#EF9A9A');
              textColor = PdfColors.white;
            } else if (!isCurrentMonth) {
              bgColor = PdfColor.fromHex('#4B4B4B');
              textColor = PdfColors.white;
            }

            return pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: bgColor,
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    day.toString(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (isHoliday && holidayName != null)
                    pw.SizedBox(height: 1),
                  if (isHoliday && holidayName != null)
                    pw.Text(
                      holidayName,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 5,
                        fontWeight: pw.FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 1),
      columnWidths: {
        for (int i = 0; i < 7; i++) i: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }

  pw.Widget _buildMiniCalendarPdf(int month, int year, Map<String, Holiday> holidayMap) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    // Converter: weekday retorna 1=seg, 2=ter, ..., 7=dom
    // Queremos: 0=dom, 1=seg, 2=ter, ..., 6=sab
    final weekdayStart = (firstDay.weekday == 7) ? 0 : firstDay.weekday;
    final monthNames = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    final dayHeaders = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final tableRows = <pw.TableRow>[];

    // Cabeçalho com nome do mês
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.blue),
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: pw.Text(
              '${monthNames[month - 1]} $year',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // Cabeçalho com dias da semana
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey),
        children: dayHeaders.map((dayHeader) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 1),
            child: pw.Text(
              dayHeader,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          );
        }).toList(),
      ),
    );

    // Montar as semanas
    List<String> currentWeek = [];

    // Preencher dias vazios antes do primeiro dia
    for (int i = 0; i < weekdayStart; i++) {
      currentWeek.add('');
    }

    // Preencher dias do mês
    for (int day = 1; day <= daysInMonth; day++) {
      currentWeek.add(day.toString());

      if (currentWeek.length == 7) {
        // Adicionar linha com 7 dias
        tableRows.add(
          pw.TableRow(
            children: currentWeek.map((dayStr) {
              if (dayStr.isEmpty) {
                return pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Text(''),
                );
              }

              final day = int.parse(dayStr);
              final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final holiday = holidayMap[dateStr];
              final isHoliday = holiday != null;
              final date = DateTime(year, month, day);
              final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

              return pw.Container(
                padding: const pw.EdgeInsets.all(2),
                decoration: pw.BoxDecoration(
                  color: isHoliday ? PdfColors.green : (isWeekend ? PdfColors.red100 : PdfColors.white),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  day.toString(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: isHoliday ? PdfColors.white : (isWeekend ? PdfColors.white : PdfColors.black),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              );
            }).toList(),
          ),
        );
        currentWeek = [];
      }
    }

    // Preencher última semana se necessário
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add('');
      }

      tableRows.add(
        pw.TableRow(
          children: currentWeek.map((dayStr) {
            if (dayStr.isEmpty) {
              return pw.Container(
                padding: const pw.EdgeInsets.all(2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(''),
              );
            }

            final day = int.parse(dayStr);
            final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final holiday = holidayMap[dateStr];
            final isHoliday = holiday != null;
            final date = DateTime(year, month, day);
            final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

            return pw.Container(
              padding: const pw.EdgeInsets.all(2),
              decoration: pw.BoxDecoration(
                color: isHoliday ? PdfColors.green : (isWeekend ? PdfColors.red100 : PdfColors.white),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Text(
                day.toString(),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: isHoliday ? PdfColors.white : (isWeekend ? PdfColors.white : PdfColors.black),
                ),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        for (int i = 0; i < 7; i++) i: const pw.FlexColumnWidth(1),
      },
      children: tableRows,
    );
  }

  HolidayStats _calculateStats(List<Holiday> holidays) {
    final stats = HolidayStats();
    final Map<String, Holiday> uniqueHolidaysMap = {}; // Map para manter apenas um por data

    // Primeiro, remover duplicatas por data e manter apenas uma por data
    for (var holiday in holidays) {
      if (!uniqueHolidaysMap.containsKey(holiday.date)) {
        uniqueHolidaysMap[holiday.date] = holiday;
      }
    }

    // Contar estatísticas baseado em feriados únicos
    for (var holiday in uniqueHolidaysMap.values) {
      bool isNacional = false, isEstadual = false, isMunicipal = false, isBancario = false;

      // Determinar tipos com prioridade: Nacional > Estadual > Municipal > Bancário
      for (var type in holiday.types) {
        if (type.contains('Nacional')) isNacional = true;
        if (type.contains('Estadual')) isEstadual = true;
        if (type.contains('Municipal')) isMunicipal = true;
        if (type.contains('Bancário')) isBancario = true;
      }

      // Contar por tipo (cada feriado conta uma vez, em sua categoria prioritária)
      if (isNacional) {
        stats.nacionais++;
      } else if (isEstadual) {
        stats.estaduais++;
      } else if (isMunicipal) {
        stats.municipais++;
      } else if (isBancario) {
        stats.bancarios++;
      }

      stats.totalFeriadosUnicos++;

      try {
        final date = DateFormat('yyyy-MM-dd').parse(holiday.date);
        final month = date.month;
        final monthNames = {1: 'Janeiro', 2: 'Fevereiro', 3: 'Março', 4: 'Abril', 5: 'Maio', 6: 'Junho', 7: 'Julho', 8: 'Agosto', 9: 'Setembro', 10: 'Outubro', 11: 'Novembro', 12: 'Dezembro'};
        final monthName = monthNames[month] ?? 'Mês $month';
        final isWeekend = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);
        stats.addMonthStat(month, monthName, isWeekend);
        switch (date.weekday) {
          case DateTime.monday: stats.segundas++; stats.diasUteis++; break;
          case DateTime.tuesday: stats.tercas++; stats.diasUteis++; break;
          case DateTime.wednesday: stats.quartas++; stats.diasUteis++; break;
          case DateTime.thursday: stats.quintas++; stats.diasUteis++; break;
          case DateTime.friday: stats.sextas++; stats.diasUteis++; break;
          case DateTime.saturday: stats.sabados++; stats.finaisSemana++; break;
          case DateTime.sunday: stats.domingos++; stats.finaisSemana++; break;
        }
      } catch (e) {
        // Tratamento de erro na análise de feriado
      }
    }

    return stats;
  }

  void _showCitySelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredCities = searchController.text.isEmpty
              ? cities
              : cities
                  .where((city) =>
                      city.name.toLowerCase().contains(searchController.text.toLowerCase()) ||
                      city.state.toLowerCase().contains(searchController.text.toLowerCase()) ||
                      city.region.toLowerCase().contains(searchController.text.toLowerCase()))
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
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
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
                      hintText: 'Buscar cidade, estado ou região...',
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
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
                              final isSelected = city.name == _selectedCity.name;
                              return ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                                ),
                                title: Text(city.name),
                                subtitle: Text('${city.state} - ${city.region}'),
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
                                  contas_prefs.PrefsService.saveLocation(
                                    _regionForCity(city.name),
                                    city.name,
                                  );
                                  _savePreferences();
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

  // --- RESUMO QUE APARECE NA TELA PRINCIPAL (LIMPO E CORRIGIDO PARA DARK MODE) ---
  Widget _buildMainStatsSummary(HolidayStats stats, double fontSize, {bool isSmallMobile = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;
    final error = colorScheme.error;
    return Card(
      elevation: 2,
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: Theme.of(context).colorScheme.onPrimary,
                    tooltip: 'Ano anterior',
                    onPressed: () => _changeYear(-1),
                  ),
                  Text(
                    '$_selectedYear',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize + 12,
                          color: Theme.of(context).colorScheme.onPrimary,
                          letterSpacing: 1.0,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: Theme.of(context).colorScheme.onPrimary,
                    tooltip: 'Próximo ano',
                    onPressed: () => _changeYear(1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showCitySelector(),
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
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCity.name,
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
          const SizedBox(height: 8),
          Text(
            'RESUMO DO ANO $_selectedYear',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: fontSize + 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Divider(height: 8),
          isSmallMobile
                ? Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildStatBadgeCompact('Total de Feriados', stats.totalFeriadosUnicos, primary, fontSize)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildStatBadgeCompact('Dias Úteis', stats.diasUteis, secondary, fontSize)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _buildStatBadgeCompact('Finais de Semana', stats.finaisSemana, error, fontSize)),
                        ],
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildStatBadge('Total de Feriados', stats.totalFeriadosUnicos, primary, fontSize)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatBadge('Dias Úteis', stats.diasUteis, secondary, fontSize)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatBadge('Finais de Semana', stats.finaisSemana, error, fontSize)),
                    ],
                  ),
            const Divider(height: 8),
            Text('Por Tipo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _buildStatRow(context, 'Nacionais', stats.nacionais, backgroundColor: _typeRowBackground(context, colorScheme.primary)),
            _buildStatRow(context, 'Municipais', stats.municipais, backgroundColor: _typeRowBackground(context, colorScheme.secondary)),
            _buildStatRow(context, 'Bancários', stats.bancarios, backgroundColor: _typeRowBackground(context, colorScheme.tertiary)),
            _buildStatRow(context, 'Estaduais', stats.estaduais, backgroundColor: _typeRowBackground(context, colorScheme.primaryContainer)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayStatsChips(HolidayStats stats, double fontSize) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feriados por Dia da Semana',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildDayChip(context, 'Seg', stats.segundas, colorScheme.primary, fontSize),
                _buildDayChip(context, 'Ter', stats.tercas, colorScheme.secondary, fontSize),
                _buildDayChip(context, 'Qua', stats.quartas, colorScheme.tertiary, fontSize),
                _buildDayChip(context, 'Qui', stats.quintas, colorScheme.primaryContainer, fontSize),
                _buildDayChip(context, 'Sex', stats.sextas, colorScheme.secondaryContainer, fontSize),
                _buildDayChip(context, 'Sab', stats.sabados, colorScheme.error, fontSize),
                _buildDayChip(context, 'Dom', stats.domingos, colorScheme.errorContainer, fontSize),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(BuildContext context, String label, int count, Color color, double fontSize) {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: adaptiveOnSurface(context).withValues(alpha: 0.8),
                  fontSize: fontSize - 1,
                ),
            ),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: fontSize + 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, int value, Color color, double fontSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: fontSize + 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize - 2,
                  color: color.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Versão compacta do badge para mobile com dois itens na mesma linha
  Widget _buildStatBadgeCompact(String label, int value, Color color, double fontSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 2.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: fontSize + 8,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize - 3,
                  color: color.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _typeRowBackground(BuildContext context, Color base) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? base.withValues(alpha: 0.25) : base.withValues(alpha: 0.12);
  }

  // --- MODIFICADO: _buildStatRow COM CORES DINÂMICAS ---
  Widget _buildStatRow(BuildContext context, String label, int value, {Color? backgroundColor}) {
    final brightness = Theme.of(context).brightness;
    final textColor = adaptiveOnSurface(context);
    final chipColor = brightness == Brightness.dark ? adaptiveSurfaceVariant(context) : adaptiveSurfaceVariant(context).withValues(alpha: 0.9);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Data inválida';
    try {
      final fullDate = DateFormat('dd \'de\' MMMM', 'pt_BR').format(date);
      final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date);
      String capitalizedDay = dayOfWeek.substring(0, 1).toUpperCase() + dayOfWeek.substring(1);
      return '$fullDate - $capitalizedDay';
    } catch (e) {
      return 'Erro de formatação';
    }
  }

  /// Normaliza o ano para 4 dígitos (ex: 26 -> 2026)
  int _normalizeYear(int? year) {
    if (year == null) return DateTime.now().year;
    if (year < 100) {
      return 2000 + year;
    }
    return year;
  }

  /// Busca contas de um dia específico para exibição na tabela semanal
  Future<List<Map<String, dynamic>>> _getAccountsForDay(int day, int month, int year) async {
    try {
      await _contasInitFuture;
    } catch (e) {
      debugPrint('Erro ao inicializar banco de contas: $e');
    }

    try {
      final accounts = await DatabaseHelper.instance.readAllAccountsRaw();
      final db = await DatabaseHelper.instance.database;
      final types = await DatabaseHelper.instance.readAllTypes();
      final categories = await DatabaseHelper.instance.readAllAccountCategories();
      final allPayments = await DatabaseHelper.instance.readAllPayments();
      
      // Mapeia IDs de contas que têm lançamentos
      final paymentsByAccountId = <int, double>{};
      for (final payment in allPayments) {
        paymentsByAccountId[payment.accountId] =
            (paymentsByAccountId[payment.accountId] ?? 0.0) + payment.value;
      }
      
      int? recebimentosTypeId;
      for (final type in types) {
        if (type.name.trim().toLowerCase() == 'recebimentos') {
          recebimentosTypeId = type.id;
          break;
        }
      }

      final typeMap = {for (var t in types) t.id!: t.name};
      final typeLogoMap = {
        for (final t in types)
          if (t.id != null && (t.logo?.trim().isNotEmpty ?? false))
            t.id!: t.logo!.trim(),
      };
      final accountById = <int, dynamic>{};
      for (final acc in accounts) {
        if (acc.id != null) {
          accountById[acc.id!] = acc;
        }
      }

      bool hasRecurrenceStarted(Account rec) {
        final hasStartDate = rec.year != null && rec.month != null;
        if (!hasStartDate) return true;
        final recYear = _normalizeYear(rec.year);
        return recYear < year || (recYear == year && rec.month! <= month);
      }

      final dayAccounts = <Map<String, dynamic>>[];
      final seenIds = <int>{};  // Para evitar duplicatas
      final launchedCardParents = <String>{};
      final launchedRecurringParents = <String>{};
      for (final account in accounts) {
        final hasLaunchInstance =
            account.value > 0 || (account.id != null && (paymentsByAccountId[account.id!] ?? 0) > 0);
        if (account.recurrenceId != null && account.cardBrand == null && hasLaunchInstance) {
          final parentId = account.recurrenceId!;
          final childMonth = account.month ?? month;
          final childYear = _normalizeYear(account.year);
          launchedRecurringParents.add('$parentId-$childMonth-$childYear');
        }
        if (account.recurrenceId != null && account.cardBrand != null && hasLaunchInstance) {
          final parentId = account.recurrenceId!;
          final childMonth = account.month ?? month;
          final childYear = _normalizeYear(account.year);
          launchedCardParents.add('$parentId-$childMonth-$childYear');
        }
      }

      final cardForecastById = <int, double>{};
      final cardParents = accounts
          .where((a) => a.cardBrand != null && a.recurrenceId == null && a.id != null)
          .toList();
      for (final card in cardParents) {
        if (card.id == null) continue;
        final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(
            card.id!, month, year);
        final recurringRes = await db.query(
          'accounts',
          where: 'cardId = ? AND isRecurrent = 1',
          whereArgs: [card.id],
        );
        final subs = recurringRes.map((e) => Account.fromMap(e)).toList();

        double totalForecast = 0.0;
        for (final exp in expenses) {
          totalForecast += exp.value;
        }
        for (final sub in subs) {
          if (expenses.any((e) => e.recurrenceId == sub.id)) continue;
          if (!hasRecurrenceStarted(sub)) continue;
          totalForecast += sub.value;
        }
        if (totalForecast > 0) {
          cardForecastById[card.id!] = totalForecast;
        }
      }

      for (final account in accounts) {
        if (account.observation == '[CANCELADA]') continue;
        if (account.cardBrand != null && account.recurrenceId == null) {
          final parentKey = '${account.id}-${account.month ?? month}-${_normalizeYear(account.year)}';
          if (launchedCardParents.contains(parentKey)) {
            continue;
          }
        }
        if (account.isRecurrent && account.recurrenceId == null && account.cardBrand == null) {
          final parentKey = '${account.id}-${account.month ?? month}-${_normalizeYear(account.year)}';
          if (launchedRecurringParents.contains(parentKey)) {
            continue;
          }
          if (!hasRecurrenceStarted(account)) {
            continue;
          }
        }

        final accYear = account.year != null ? _normalizeYear(account.year) : year;
        final accMonth = account.month ?? month;
        final accDay = account.dueDay;

        // Data original cadastrada
        final originalDate = DateTime(accYear, accMonth, accDay);
        // Data ajustada: pula finais de semana/feriados da cidade selecionada
        DateTime adjustedDate = originalDate;
        // Usa HolidayService para verificar finais de semana/feriados
        while (HolidayService.isWeekend(adjustedDate) ||
            HolidayService.isHoliday(adjustedDate, _selectedCity.name)) {
          // Regra simples: empurra para o próximo dia útil
          adjustedDate = adjustedDate.add(const Duration(days: 1));
        }

        if (adjustedDate.year == year && adjustedDate.month == month && adjustedDate.day == day) {
          // Evita duplicatas pelo ID
          if (account.id != null) {
            if (seenIds.contains(account.id)) {
              debugPrint('⚠️ Conta duplicada ignorada: ID ${account.id}, ${account.description}');
              continue;
            }
            seenIds.add(account.id!);
          }

          final typeName = typeMap[account.typeId] ?? 'Outro';
          String typeIcon = typeLogoMap[account.typeId] ?? '📋';
          if (account.recurrenceId != null) {
            final parent = accountById[account.recurrenceId!];
            final parentTypeId = parent?.typeId;
            final parentIcon = parentTypeId != null ? typeLogoMap[parentTypeId] : null;
            if (parentIcon != null && parentIcon.isNotEmpty) {
              typeIcon = parentIcon;
            }
          }

          // Busca categoria secundária
          String categoryName = 'Outros';
          if (account.categoryId != null) {
            try {
              final category = categories.firstWhere(
                (c) => c.id == account.categoryId,
              );
              categoryName = category.categoria;
            } catch (e) {
              categoryName = 'Outros';
            }
          }

          final hasLaunch = account.id != null && (paymentsByAccountId[account.id!] ?? 0) > 0;
          final isInstallment = account.installmentTotal != null || account.installmentIndex != null;
          final isRecurringParent =
              account.isRecurrent && account.recurrenceId == null && !isInstallment;
          final isRecurringChild = account.recurrenceId != null;
          final isCardParent = account.cardBrand != null && account.recurrenceId == null;
          final plannedValue = (account.estimatedValue != null && account.estimatedValue! > 0)
              ? account.estimatedValue!
              : account.value;
          double effectiveValue = account.value;
          if (!hasLaunch && isRecurringParent) {
            effectiveValue = plannedValue;
          }
          if (!hasLaunch && isCardParent && account.id != null && cardForecastById.containsKey(account.id)) {
            effectiveValue = cardForecastById[account.id!]!;
          }
          dayAccounts.add({
            'account': account,
            'typeName': typeName,
            'typeIcon': typeIcon,
            'categoryName': categoryName,
            'isRecebimento': recebimentosTypeId != null && account.typeId == recebimentosTypeId,
            'isRecurringParent': isRecurringParent,
            'isRecurringChild': isRecurringChild,
            'isCardParent': isCardParent,
            'isInstallment': isInstallment,
            'value': effectiveValue,
            'launchedValue': account.id != null ? paymentsByAccountId[account.id!] : null,
            'description': account.description,
            'adjustedDate': adjustedDate,
            'originalDate': originalDate,
          });
        }
      }

      dayAccounts.sort((a, b) => a['description'].toString().compareTo(b['description'].toString()));
      return dayAccounts;
    } catch (e) {
      debugPrint('Erro ao buscar contas do dia: $e');
      return [];
    }
  }

  Future<Map<int, ({double previsto, double lancado, int previstoCount, int lancadoCount, double recebimentos, int recebimentosCount, double avulsas, int avulsasCount, double recebimentosPrevisto, int recebimentosPrevistoCount, double recebimentosAvulsas, int recebimentosAvulsasCount})>>
      _loadMonthlyTotals(int month, int year) async {
    try {
      await _contasInitFuture;
    } catch (e) {
      debugPrint('Erro ao inicializar banco de contas: $e');
    }

    try {
      final accounts = await DatabaseHelper.instance.readAllAccountsRaw();
      final db = await DatabaseHelper.instance.database;
      final types = await DatabaseHelper.instance.readAllTypes();
      final allPayments = await DatabaseHelper.instance.readAllPayments();
      int? recebimentosTypeId;
      for (final type in types) {
        if (type.name.trim().toLowerCase() == 'recebimentos') {
          recebimentosTypeId = type.id;
          break;
        }
      }
      bool isRecebimento(dynamic acc) =>
          recebimentosTypeId != null && acc.typeId == recebimentosTypeId;
      final totalsByDay =
          <int, ({double previsto, double lancado, int previstoCount, int lancadoCount, double recebimentos, int recebimentosCount, double avulsas, int avulsasCount, double recebimentosPrevisto, int recebimentosPrevistoCount, double recebimentosAvulsas, int recebimentosAvulsasCount})>{};
      final paymentAccountIds = <int>{};
      for (final payment in allPayments) {
        paymentAccountIds.add(payment.accountId);
      }

      bool hasRecurrenceStarted(dynamic acc) {
        if (acc.year == null || acc.month == null) return true;
        final accYear = _normalizeYear(acc.year);
        if (accYear < year) return true;
        return accYear == year && acc.month <= month;
      }

      void addPrevisto(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto + value,
          lancado: current.lancado,
          previstoCount: current.previstoCount + 1,
          lancadoCount: current.lancadoCount,
          recebimentos: current.recebimentos,
          recebimentosCount: current.recebimentosCount,
          avulsas: current.avulsas,
          avulsasCount: current.avulsasCount,
          recebimentosPrevisto: current.recebimentosPrevisto,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount,
          recebimentosAvulsas: current.recebimentosAvulsas,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount,
        );
      }

      void addLancado(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto,
          lancado: current.lancado + value,
          previstoCount: current.previstoCount,
          lancadoCount: current.lancadoCount + 1,
          recebimentos: current.recebimentos,
          recebimentosCount: current.recebimentosCount,
          avulsas: current.avulsas,
          avulsasCount: current.avulsasCount,
          recebimentosPrevisto: current.recebimentosPrevisto,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount,
          recebimentosAvulsas: current.recebimentosAvulsas,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount,
        );
      }

      void addRecebimento(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto,
          lancado: current.lancado,
          previstoCount: current.previstoCount,
          lancadoCount: current.lancadoCount,
          recebimentos: current.recebimentos + value,
          recebimentosCount: current.recebimentosCount + 1,
          avulsas: current.avulsas,
          avulsasCount: current.avulsasCount,
          recebimentosPrevisto: current.recebimentosPrevisto,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount,
          recebimentosAvulsas: current.recebimentosAvulsas,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount,
        );
      }

      void addAvulsa(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto,
          lancado: current.lancado,
          previstoCount: current.previstoCount,
          lancadoCount: current.lancadoCount,
          recebimentos: current.recebimentos,
          recebimentosCount: current.recebimentosCount,
          avulsas: current.avulsas + value,
          avulsasCount: current.avulsasCount + 1,
          recebimentosPrevisto: current.recebimentosPrevisto,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount,
          recebimentosAvulsas: current.recebimentosAvulsas,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount,
        );
      }

      void addRecebimentoPrevisto(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto,
          lancado: current.lancado,
          previstoCount: current.previstoCount,
          lancadoCount: current.lancadoCount,
          recebimentos: current.recebimentos,
          recebimentosCount: current.recebimentosCount,
          avulsas: current.avulsas,
          avulsasCount: current.avulsasCount,
          recebimentosPrevisto: current.recebimentosPrevisto + value,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount + 1,
          recebimentosAvulsas: current.recebimentosAvulsas,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount,
        );
      }

      void addRecebimentoAvulsa(int dueDay, double value) {
        final current = totalsByDay[dueDay] ??
            (previsto: 0.0, lancado: 0.0, previstoCount: 0, lancadoCount: 0, recebimentos: 0.0, recebimentosCount: 0, avulsas: 0.0, avulsasCount: 0, recebimentosPrevisto: 0.0, recebimentosPrevistoCount: 0, recebimentosAvulsas: 0.0, recebimentosAvulsasCount: 0);
        totalsByDay[dueDay] = (
          previsto: current.previsto,
          lancado: current.lancado,
          previstoCount: current.previstoCount,
          lancadoCount: current.lancadoCount,
          recebimentos: current.recebimentos,
          recebimentosCount: current.recebimentosCount,
          avulsas: current.avulsas,
          avulsasCount: current.avulsasCount,
          recebimentosPrevisto: current.recebimentosPrevisto,
          recebimentosPrevistoCount: current.recebimentosPrevistoCount,
          recebimentosAvulsas: current.recebimentosAvulsas + value,
          recebimentosAvulsasCount: current.recebimentosAvulsasCount + 1,
        );
      }

      // 🗓️ Calcular dia efetivo ajustado por feriados
      int getEffectiveDay(dynamic acc, int targetMonth, int targetYear) {
        final accYear = acc.year ?? targetYear;
        final accMonth = acc.month ?? targetMonth;
        int day = acc.dueDay;
        final maxDays = DateTime(accYear, accMonth + 1, 0).day;
        if (day > maxDays) day = maxDays;
        
        DateTime effectiveDate = DateTime(accYear, accMonth, day);
        final isWeekend = effectiveDate.weekday == DateTime.saturday || effectiveDate.weekday == DateTime.sunday;
        final isHoliday = HolidayService.isHoliday(effectiveDate, _selectedCity.name);
        
        if (isWeekend || isHoliday) {
          final payInAdvance = acc.payInAdvance ?? false;
          if (payInAdvance) {
            while (effectiveDate.weekday == DateTime.saturday || 
                   effectiveDate.weekday == DateTime.sunday ||
                   HolidayService.isHoliday(effectiveDate, _selectedCity.name)) {
              effectiveDate = effectiveDate.subtract(const Duration(days: 1));
            }
          } else {
            while (effectiveDate.weekday == DateTime.saturday || 
                   effectiveDate.weekday == DateTime.sunday ||
                   HolidayService.isHoliday(effectiveDate, _selectedCity.name)) {
              effectiveDate = effectiveDate.add(const Duration(days: 1));
            }
          }
        }
        
        return effectiveDate.day;
      }

      final contasAccounts =
          accounts.where((acc) => acc.cardId == null && !isRecebimento(acc)).toList();

      final monthAccounts =
          contasAccounts.where((acc) => acc.month == month && _normalizeYear(acc.year) == year).toList();

      final monthRecebimentos = accounts
          .where((acc) =>
              acc.month == month &&
              _normalizeYear(acc.year) == year &&
              acc.cardId == null &&
              isRecebimento(acc))
          .toList();

      final childrenByRecurrence = <int, List<dynamic>>{};
      final payRecurringParents = <int, dynamic>{};
      final receiveRecurringParents = <int, dynamic>{};
      for (final acc in accounts) {
        if (!acc.isRecurrent || acc.recurrenceId != null) continue;
        if (acc.id == null) continue;
        if (isRecebimento(acc)) {
          receiveRecurringParents[acc.id!] = acc;
        } else if (acc.cardId == null) {
          payRecurringParents[acc.id!] = acc;
        }
      }
      for (final acc in monthAccounts) {
        final recurrenceId = acc.recurrenceId;
        if (recurrenceId == null) continue;
        childrenByRecurrence.putIfAbsent(recurrenceId, () => []).add(acc);
      }

      for (final acc in monthAccounts) {
        if (acc.isRecurrent) continue;
        if (acc.recurrenceId != null) continue;
        final effectiveDay = getEffectiveDay(acc, month, year);
        final hasLaunch =
            acc.value > 0 || (acc.id != null && paymentAccountIds.contains(acc.id));
        addAvulsa(effectiveDay, acc.value);
        if (hasLaunch) {
          addLancado(effectiveDay, acc.value);
        }
      }

      for (final entry in childrenByRecurrence.entries) {
        final list = entry.value;
        list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        final selected = list.first;
        final effectiveDay = getEffectiveDay(selected, month, year);
        final hasLaunch =
            selected.value > 0 || (selected.id != null && paymentAccountIds.contains(selected.id));
        if (hasLaunch) {
          addLancado(effectiveDay, selected.value);
        }
      }

      for (final acc in accounts) {
        if (!acc.isRecurrent) continue;
        if (isRecebimento(acc)) continue;
        if (acc.recurrenceId != null) continue;
        if (acc.cardId != null) continue;
        if (!hasRecurrenceStarted(acc)) continue;
        final recurrenceId = acc.id;
        if (recurrenceId == null) continue;
        final effectiveDay = getEffectiveDay(acc, month, year);
        final previstoValue = acc.estimatedValue ?? acc.value;
        addPrevisto(effectiveDay, previstoValue);
      }

      // Previstos de cartao de credito (fatura prevista do mes)
      final cardParents = accounts
          .where((acc) => acc.cardBrand != null && acc.recurrenceId == null && acc.id != null)
          .toList();
      for (final card in cardParents) {
        if (card.id == null) continue;
        final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(
            card.id!, month, year);
        final recurringRes = await db.query(
          'accounts',
          where: 'cardId = ? AND isRecurrent = 1',
          whereArgs: [card.id],
        );
        final subs = recurringRes.map((e) => Account.fromMap(e)).toList();

        double totalForecast = 0.0;
        for (final exp in expenses) {
          totalForecast += exp.value;
        }
        for (final sub in subs) {
          if (expenses.any((e) => e.recurrenceId == sub.id)) continue;
          if (!hasRecurrenceStarted(sub)) continue;
          totalForecast += sub.value;
        }
        if (totalForecast <= 0) continue;
        final effectiveDay = getEffectiveDay(card, month, year);
        addPrevisto(effectiveDay, totalForecast);
      }

      final recebimentosByRecurrence = <int, List<dynamic>>{};
      for (final acc in monthRecebimentos) {
        final recurrenceId = acc.recurrenceId;
        if (recurrenceId == null) continue;
        recebimentosByRecurrence.putIfAbsent(recurrenceId, () => []).add(acc);
      }

      for (final acc in monthRecebimentos) {
        if (acc.isRecurrent) continue;
        if (acc.recurrenceId != null) continue;
        final effectiveDay = getEffectiveDay(acc, month, year);
        final hasLaunch =
            acc.value > 0 || (acc.id != null && paymentAccountIds.contains(acc.id));
        addRecebimentoAvulsa(effectiveDay, acc.value);
        if (hasLaunch) {
          addRecebimento(effectiveDay, acc.value);
        }
      }

      for (final entry in recebimentosByRecurrence.entries) {
        final list = entry.value;
        list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        final selected = list.first;
        final effectiveDay = getEffectiveDay(selected, month, year);
        final hasLaunch =
            selected.value > 0 || (selected.id != null && paymentAccountIds.contains(selected.id));
        if (hasLaunch) {
          addRecebimento(effectiveDay, selected.value);
        }
      }

      for (final entry in receiveRecurringParents.entries) {
        final acc = entry.value;
        if (!hasRecurrenceStarted(acc)) continue;
        final effectiveDay = getEffectiveDay(acc, month, year);
        final previstoValue = acc.estimatedValue ?? acc.value;
        addRecebimentoPrevisto(effectiveDay, previstoValue);
      }

      // Recebimentos entram no total somente quando houver lancamento.

      return totalsByDay;
    } catch (e) {
      debugPrint('Erro ao carregar totais por dia: $e');
      return {};
    }
  }

  Future<Map<int, ({double pagar, double receber})>> _loadAnnualTotals(int year) async {
    final totalsByMonth = <int, ({double pagar, double receber})>{};
    for (int month = 1; month <= 12; month++) {
      final totalsByDay = await _loadMonthlyTotals(month, year);
      double pagar = 0.0;
      double receber = 0.0;
      for (final totals in totalsByDay.values) {
        pagar += totals.previsto + totals.lancado;
        receber += totals.recebimentos;
      }
      totalsByMonth[month] = (pagar: pagar, receber: receber);
    }
    return totalsByMonth;
  }

  Future<
          Map<
              String,
              ({
                double previsto,
                double lancado,
                int previstoCount,
                int lancadoCount,
                double recebimentos,
                int recebimentosCount,
                double avulsas,
                int avulsasCount,
                double recebimentosPrevisto,
                int recebimentosPrevistoCount,
                double recebimentosAvulsas,
                int recebimentosAvulsasCount
              })>> _loadWeeklyTotals(DateTime startOfWeek) async {
    final dates = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    final monthKeys = <String, ({int month, int year})>{};
    for (final date in dates) {
      monthKeys['${date.year}-${date.month}'] = (month: date.month, year: date.year);
    }

    final totalsByMonthKey =
        <String, Map<int, ({double previsto, double lancado, int previstoCount, int lancadoCount, double recebimentos, int recebimentosCount, double avulsas, int avulsasCount, double recebimentosPrevisto, int recebimentosPrevistoCount, double recebimentosAvulsas, int recebimentosAvulsasCount})>>{};

    await Future.wait(
      monthKeys.entries.map((entry) async {
        totalsByMonthKey[entry.key] =
            await _loadMonthlyTotals(entry.value.month, entry.value.year);
      }),
    );

    const empty = (
      previsto: 0.0,
      lancado: 0.0,
      previstoCount: 0,
      lancadoCount: 0,
      recebimentos: 0.0,
      recebimentosCount: 0,
      avulsas: 0.0,
      avulsasCount: 0,
      recebimentosPrevisto: 0.0,
      recebimentosPrevistoCount: 0,
      recebimentosAvulsas: 0.0,
      recebimentosAvulsasCount: 0,
    );

    final result = <
        String,
        ({
          double previsto,
          double lancado,
          int previstoCount,
          int lancadoCount,
          double recebimentos,
          int recebimentosCount,
          double avulsas,
          int avulsasCount,
          double recebimentosPrevisto,
          int recebimentosPrevistoCount,
          double recebimentosAvulsas,
          int recebimentosAvulsasCount
        })>{};

    for (final date in dates) {
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final monthKey = '${date.year}-${date.month}';
      result[dateKey] = totalsByMonthKey[monthKey]?[date.day] ?? empty;
    }

    return result;
  }

  void _openAccountsForDay(int day, int month, int year) {
    final date = DateTime(year, month, day);
    _skipNextContasReset = true;
    contas_prefs.PrefsService.setTabReturnIndex(_tabController.index);
    contas_prefs.PrefsService.saveDateRange(date, date);
    _tabController.animateTo(0);
  }

  Widget _buildCalendarContainer({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      color: colorScheme.surface,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallMobile = screenWidth < 600;
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate cell size based on available space (7 columns, ~6 rows)
    final cellWidth = (screenWidth - 120) / 7;
    final cellHeight = (screenHeight - 300) / 6;
    final cellSize = cellWidth < cellHeight ? cellWidth : cellHeight;

    // Responsive font sizing based on CELL SIZE (proportional to fit)
    final baseFontSize = cellSize / 10;
    final double dayNumberSize = baseFontSize * 2.1;
    final double hojeTextSize = baseFontSize * 1.0;
    final double moneyTextSize = baseFontSize * 1.25;
    final double holidayTextSize = baseFontSize * 0.95;
    final double minHolidayWidth = cellSize * 0.80;     // Min 80% of cell width
    final double maxHolidayWidth = cellSize * 0.95;     // Max 95% of cell width

    final moneyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dayAmountFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);
    
    final now = DateTime(_selectedYear, _calendarMonth, 1);
    final firstDayOfWeek = now.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
    final daysInMonth = DateTime(_selectedYear, _calendarMonth + 1, 0).day;
    final prevMonthDays = DateTime(_selectedYear, _calendarMonth, 0).day;
    
    // Calcular mês anterior
    int prevMonth = _calendarMonth == 1 ? 12 : _calendarMonth - 1;
    int prevYear = _calendarMonth == 1 ? _selectedYear - 1 : _selectedYear;
    
    // Calcular próximo mês/ano
    int nextMonth = _calendarMonth == 12 ? 1 : _calendarMonth + 1;
    int nextYear = _calendarMonth == 12 ? _selectedYear + 1 : _selectedYear;
    
    
    final today = DateTime.now();
    final isCurrentMonth = today.year == _selectedYear && today.month == _calendarMonth;
    final todayDay = isCurrentMonth ? today.day : -1;
    
    final List<String> dayHeaders = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    List<({int day, int month, int year, bool isCurrentMonth})> calendarDays = [];
    
    // Dias do mês anterior (apenas os necessários para preencher o inicio da primeira semana)
    for (int i = prevMonthDays - firstDayOfWeek + 1; i <= prevMonthDays; i++) {
      calendarDays.add((day: i, month: prevMonth, year: prevYear, isCurrentMonth: false));
    }
    
    // Dias do mês atual
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add((day: i, month: _calendarMonth, year: _selectedYear, isCurrentMonth: true));
    }
    
    // Dias do próximo mês para completar o grid
    int remainingCells = (7 - (calendarDays.length % 7)) % 7;
    for (int i = 1; i <= remainingCells; i++) {
      calendarDays.add((day: i, month: nextMonth, year: nextYear, isCurrentMonth: false));
    }
    
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        Map<String, String> holidayNames = {};
        Set<String> holidayDays = {};

        if (snapshot.hasData) {
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';

              // Verificar se é do mês atual, anterior ou próximo
              if ((holidayDate.month == _calendarMonth && holidayDate.year == _selectedYear) ||
                  (holidayDate.month == prevMonth && holidayDate.year == prevYear) ||
                  (holidayDate.month == nextMonth && holidayDate.year == nextYear)) {
                holidayDays.add(key);
                holidayNames[key] = holiday.name;
              }
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
        }

        return FutureBuilder<
            Map<int, ({double previsto, double lancado, int previstoCount, int lancadoCount, double recebimentos, int recebimentosCount, double avulsas, int avulsasCount, double recebimentosPrevisto, int recebimentosPrevistoCount, double recebimentosAvulsas, int recebimentosAvulsasCount})>>(
          future: _monthlyTotalsFuture,
          builder: (context, totalsSnapshot) {
            final totalsByDay = totalsSnapshot.data ?? {};
            double monthPayTotal = 0.0;
            double monthReceiveTotal = 0.0;
            double monthPayPrevistoTotal = 0.0;
            double monthReceivePrevistoTotal = 0.0;
            for (int day = 1; day <= daysInMonth; day++) {
              final daily = totalsByDay[day];
              if (daily == null) continue;
              monthPayTotal += (daily.previsto + daily.lancado);
              monthPayPrevistoTotal += (daily.previsto + daily.avulsas);
              monthReceiveTotal += daily.recebimentos;
              monthReceivePrevistoTotal += (daily.recebimentosPrevisto + daily.recebimentosAvulsas);
            }
            return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
          onHorizontalDragUpdate: (details) {
            _horizontalDragDistance += details.delta.dx;
          },
          onHorizontalDragCancel: () => _horizontalDragDistance = 0,
          onHorizontalDragEnd: (details) {
            _handleHorizontalSwipe(
              details,
              onSwipeLeft: () => _changeMonth(1),
              onSwipeRight: () => _changeMonth(-1),
            );
          },
          child: Center(
            child: Column(
              children: [
                MonthHeader(
                  title: _getMonthYearText().replaceFirst('Calendário - ', ''),
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                ),
                const SizedBox(height: AppSpacing.md),
                FilterBar(
                  options: const [
                    FilterBarOption(value: 'semanal', label: 'Semanal'),
                    FilterBarOption(value: 'mensal', label: 'Mensal'),
                    FilterBarOption(value: 'anual', label: 'Anual'),
                  ],
                  selectedValue: _calendarType,
                  onSelected: (type) {
                    setState(() {
                      _calendarType = type;
                    });
                    _savePreferences();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  decoration: const BoxDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 40),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  // Card A PAGAR (primeiro - esquerda)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Color.alphaBlend(
                                          colorScheme.error.withValues(alpha: 0.08),
                                          colorScheme.surface,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.error.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.trending_down_rounded,
                                                  color: colorScheme.error,
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'A PAGAR',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                  color: colorScheme.onSurfaceVariant,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              moneyFormat.format(monthPayTotal),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: colorScheme.error,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Previsto: ${moneyFormat.format(monthPayPrevistoTotal)}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Card A RECEBER (segundo - direita)
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Color.alphaBlend(
                                          colorScheme.primary.withValues(alpha: 0.08),
                                          colorScheme.surface,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Icon(
                                                  Icons.trending_up_rounded,
                                                  color: colorScheme.primary,
                                                  size: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'A RECEBER',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 10,
                                                  color: colorScheme.onSurfaceVariant,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              moneyFormat.format(monthReceiveTotal),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Previsto: ${moneyFormat.format(monthReceivePrevistoTotal)}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: dayHeaders.map((day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: dayNumberSize,
                                      fontWeight: FontWeight.bold,
                                      color: day == 'DOM'
                                          ? colorScheme.error
                                          : (day == 'SAB'
                                              ? colorScheme.onSurfaceVariant
                                              : colorScheme.onSurface),
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 4),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7,
                                childAspectRatio: 0.95,
                                mainAxisSpacing: 0.01,
                                crossAxisSpacing: 0.01,
                              ),
                              itemCount: calendarDays.length,
                              itemBuilder: (context, index) {
                                final dayData = calendarDays[index];
                                final day = dayData.day;
                                final month = dayData.month;
                                final year = dayData.year;
                                final isCurrentMonth = dayData.isCurrentMonth;
                                final dateObj = DateTime(year, month, day);
                                final weekday = dateObj.weekday; // 1=segunda, 7=domingo
                                final dayOfWeek = weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
                                final isToday = isCurrentMonth && day == todayDay;
                                final holidayKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                                final isHoliday = holidayDays.contains(holidayKey);
                                final holidayName = isHoliday ? holidayNames[holidayKey] : null;
                                final dailyTotals = isCurrentMonth ? totalsByDay[day] : null;
                                final previsto = dailyTotals?.previsto ?? 0.0;
                                final lancado = dailyTotals?.lancado ?? 0.0;
                                final recebimentos = dailyTotals?.recebimentos ?? 0.0;
                                final hasTotals = (previsto + lancado) > 0 || recebimentos > 0;
                                
                                // Calcula tamanho de fonte adaptativo baseado nos valores
                                double adaptiveFontSize = moneyTextSize * 0.8;
                                if (hasTotals) {
                                  final pagarText = 'R\$ ${dayAmountFormat.format(previsto + lancado)}';
                                  final receberText = 'R\$ ${dayAmountFormat.format(recebimentos)}';
                                  final longestText = pagarText.length > receberText.length ? pagarText : receberText;
                                  
                                  // Ajusta fonte baseado no comprimento do maior valor
                                  if (longestText.length > 12) {
                                    adaptiveFontSize = moneyTextSize * 0.6;
                                  } else if (longestText.length > 10) {
                                    adaptiveFontSize = moneyTextSize * 0.7;
                                  }
                                }
                                
                                Color bgColor = colorScheme.surface;
                                Color textColor = colorScheme.onSurface;
                                final cellBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.6);
                                double opacity = 1.0;

                                if (isToday) {
                                  textColor = colorScheme.onPrimaryContainer;
                                } else if (isHoliday) {
                                  bgColor = colorScheme.surfaceContainerHighest;
                                  textColor = colorScheme.onSurface;
                                  opacity = 1.0;
                                } else if (dayOfWeek == 0) { // Domingo
                                  bgColor = colorScheme.errorContainer.withValues(alpha: 0.4);
                                  textColor = colorScheme.error;
                                } else if (dayOfWeek == 6) { // Sábado
                                  bgColor = colorScheme.surfaceContainerHighest;
                                  textColor = colorScheme.onSurfaceVariant;
                                } else if (!isCurrentMonth) {
                                  bgColor = colorScheme.surfaceContainerHighest;
                                  opacity = 1.0;
                                  textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
                                }
                                
                                return Tooltip(
                                  message: holidayName ?? '',
                                  child: GestureDetector(
                                    onTap: () => _openAccountsForDay(day, month, year),
                                    child: Container(
                                          decoration: BoxDecoration(
                                            color: isToday
                                                ? colorScheme.primaryContainer
                                                : bgColor.withValues(alpha: opacity),
                                            border: Border.all(
                                              color: isToday ? colorScheme.primary : cellBorderColor,
                                              width: isToday ? 2.0 : 1.0,
                                            ),
                                            borderRadius: BorderRadius.circular(10.0),
                                          ),
                                      padding: const EdgeInsets.all(6.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isToday && hasTotals)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 2),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: colorScheme.primary, width: 1),
                                                ),
                                                child: Text(
                                                  'Hoje',
                                                  style: TextStyle(
                                                    fontSize: hojeTextSize * 0.7,
                                                    fontWeight: FontWeight.w600,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Text(
                                            day.toString(),
                                            style: TextStyle(
                                              fontSize: dayNumberSize,
                                              fontWeight: FontWeight.w900,
                                              color: isToday ? colorScheme.primary : textColor,
                                            ),
                                          ),
                                          // Valores com setas (limpo e simples)
                                          if ((previsto + lancado) > 0)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 3),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_downward,
                                                      size: adaptiveFontSize,
                                                      color: colorScheme.error,
                                                    ),
                                                    const SizedBox(width: 1),
                                                    Flexible(
                                                      child: Text(
                                                        'R\$ ${dayAmountFormat.format(previsto + lancado)}',
                                                        style: TextStyle(
                                                          fontSize: adaptiveFontSize,
                                                          fontWeight: FontWeight.w700,
                                                          color: colorScheme.error,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (recebimentos > 0)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: const EdgeInsets.only(top: 3),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.arrow_upward,
                                                      size: adaptiveFontSize,
                                                      color: colorScheme.primary,
                                                    ),
                                                    const SizedBox(width: 1),
                                                    Flexible(
                                                      child: Text(
                                                        'R\$ ${dayAmountFormat.format(recebimentos)}',
                                                        style: TextStyle(
                                                          fontSize: adaptiveFontSize,
                                                          fontWeight: FontWeight.w700,
                                                          color: colorScheme.primary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (isToday && !hasTotals)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: colorScheme.primary, width: 1),
                                                ),
                                                child: Text(
                                                  'Hoje',
                                                  style: TextStyle(
                                                    fontSize: hojeTextSize * 0.7,
                                                    fontWeight: FontWeight.w600,
                                                    color: colorScheme.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (isHoliday && holidayName != null)
                                            Flexible(
                                              child: Container(
                                                constraints: BoxConstraints(
                                                  minWidth: minHolidayWidth,
                                                  maxWidth: maxHolidayWidth,
                                                ),
                                                padding: const EdgeInsets.only(top: 0.0),
                                                child: Text(
                                                  holidayName,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(fontSize: holidayTextSize, fontWeight: FontWeight.w600, color: textColor),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // Legenda discreta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 12,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Pagamentos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.arrow_upward,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Recebimentos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  // --- CALENDÁRIO SEMANAL ---
  Widget _buildWeeklyCalendar() {
    final startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday % 7));
    final weekDays = <({String label, DateTime date})>[];
    final dayLabels = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    final moneyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final monthNamesComplete = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    final colorScheme = Theme.of(context).colorScheme;

    // Calcular o número da semana (ISO 8601)
    final jan4 = DateTime(startOfWeek.year, 1, 4);
    final jan4Weekday = jan4.weekday % 7;
    final startOfYear = jan4.subtract(Duration(days: jan4Weekday));
    final weekNumber = ((startOfWeek.difference(startOfYear).inDays) ~/ 7) + 1;

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      weekDays.add((label: dayLabels[i], date: date));
    }
    
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        Map<String, String> holidayNames = {};
        Set<String> holidayDays = {};
        
        // Mostrar loading enquanto carrega
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Transform.scale(
            scale: 0.92,
            alignment: Alignment.topCenter,
            child: Card(
              elevation: 1,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    SizedBox(height: 16),
                    Text('Carregando feriados...', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (snapshot.hasData) {
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              holidayDays.add(key);
              holidayNames[key] = holiday.name;
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
        }
        
        return FutureBuilder<
            Map<
                String,
                ({
                  double previsto,
                  double lancado,
                  int previstoCount,
                  int lancadoCount,
                  double recebimentos,
                  int recebimentosCount,
                  double avulsas,
                  int avulsasCount,
                  double recebimentosPrevisto,
                  int recebimentosPrevistoCount,
                  double recebimentosAvulsas,
                  int recebimentosAvulsasCount
                })>>(
          future: _loadWeeklyTotals(startOfWeek),
          builder: (context, totalsSnapshot) {
            final totalsByDate = totalsSnapshot.data ?? {};
            double weekPayTotal = 0.0;
            double weekReceiveTotal = 0.0;
            double weekPayPrevistoTotal = 0.0;
            double weekReceivePrevistoTotal = 0.0;
            for (final day in weekDays) {
              final key =
                  '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
              final daily = totalsByDate[key];
              if (daily == null) continue;
              weekPayTotal += daily.lancado;
              weekPayPrevistoTotal += (daily.previsto + daily.avulsas);
              weekReceiveTotal += daily.recebimentos;
              weekReceivePrevistoTotal += (daily.recebimentosPrevisto + daily.recebimentosAvulsas);
            }
            final displayWeekPayTotal = weekPayTotal;
            final displayWeekReceiveTotal = weekReceiveTotal;

            return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
          onHorizontalDragUpdate: (details) {
            _horizontalDragDistance += details.delta.dx;
          },
          onHorizontalDragCancel: () => _horizontalDragDistance = 0,
          onHorizontalDragEnd: (details) {
            _handleHorizontalSwipe(
              details,
              onSwipeLeft: () => _changeWeek(1),
              onSwipeRight: () => _changeWeek(-1),
            );
          },
          child: Transform.scale(
              scale: 1,
              alignment: Alignment.topCenter,
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Card(
                      elevation: 1,
                      color: colorScheme.surface,
                      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: Column(
                          children: [
                            MonthHeader(
                              title: '${monthNamesComplete[startOfWeek.month - 1].toUpperCase()} ${startOfWeek.year}',
                              subtitle: 'Semana #$weekNumber',
                              onPrevious: () => _changeWeek(-1),
                              onNext: () => _changeWeek(1),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            FilterBar(
                              options: const [
                                FilterBarOption(value: 'semanal', label: 'Semanal'),
                                FilterBarOption(value: 'mensal', label: 'Mensal'),
                                FilterBarOption(value: 'anual', label: 'Anual'),
                              ],
                              selectedValue: _calendarType,
                              onSelected: (type) {
                                setState(() {
                                  _calendarType = type;
                                });
                                _savePreferences();
                              },
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                            // Card A PAGAR
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                    colorScheme.error.withValues(alpha: 0.08),
                                    colorScheme.surface,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'A PAGAR',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: colorScheme.error.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.trending_down_rounded,
                                            color: colorScheme.error,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  moneyFormat.format(displayWeekPayTotal),
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w900,
                                                    color: colorScheme.error,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Previsto ${moneyFormat.format(weekPayPrevistoTotal)}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: colorScheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Card A RECEBER
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Color.alphaBlend(
                                    colorScheme.primary.withValues(alpha: 0.08),
                                    colorScheme.surface,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'A RECEBER',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.trending_up_rounded,
                                            color: colorScheme.primary,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  moneyFormat.format(displayWeekReceiveTotal),
                                                  style: TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w900,
                                                    color: colorScheme.primary,
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Previsto ${moneyFormat.format(weekReceivePrevistoTotal)}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: colorScheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Card(
                      elevation: 1,
                      color: colorScheme.surface,
                      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Column(
                          children: weekDays.map((day) {
                              final now = DateTime.now();
                              final isToday = day.date.year == now.year && day.date.month == now.month && day.date.day == now.day;
                              final holidayKey = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
                              final isHoliday = holidayDays.contains(holidayKey);
                              final holidayName = isHoliday ? holidayNames[holidayKey] : null;
                              final totalsKey =
                                  '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
                              final dailyTotals = totalsByDate[totalsKey];
                              
                              // Visual mais sutil para feriados e fins de semana
                              Color bgColor = colorScheme.surface;
                              Color? borderLeftColor;
                              Color textColor = colorScheme.onSurface;

                              if (isHoliday) {
                                bgColor = colorScheme.tertiaryContainer;
                                borderLeftColor = colorScheme.tertiary;
                                textColor = colorScheme.onTertiaryContainer;
                              } else if (day.label == 'DOM') {
                                bgColor = colorScheme.errorContainer.withValues(alpha: 0.4);
                                borderLeftColor = colorScheme.error;
                                textColor = colorScheme.onSurface;
                              } else if (day.label == 'SAB') {
                                bgColor = colorScheme.surfaceContainerHighest;
                                borderLeftColor = colorScheme.error.withValues(alpha: 0.7);
                                textColor = colorScheme.onSurface;
                              }

                              return GestureDetector(
                                onTap: () => _openAccountsForDay(
                                  day.date.day,
                                  day.date.month,
                                  day.date.year,
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                        future: _getAccountsForDay(day.date.day, day.date.month, day.date.year),
                                        builder: (context, snapshot) {
                                          final dayAccounts = snapshot.data ?? [];
                                          final hasAccounts = dayAccounts.isNotEmpty;
                                          final payAccounts = dayAccounts.where((accData) {
                                            final isReceber = accData['isRecebimento'] as bool;
                                            final value = accData['value'] as double;
                                            final launchedValue = accData['launchedValue'] as double?;
                                            final hasLaunch = launchedValue != null && launchedValue > 0;
                                            final isRecurringChild = accData['isRecurringChild'] as bool? ?? false;
                                            final isRecurringParent = accData['isRecurringParent'] as bool? ?? false;
                                            final isCardParent = accData['isCardParent'] as bool? ?? false;
                                            final isParentEntry = isRecurringParent || isCardParent;
                                            final isUnlaunchedZero = !hasLaunch && value <= 0;
                                            if (isReceber) return false;
                                            if (hasLaunch) return true;
                                            if (isParentEntry && value > 0) return true;
                                            if (isRecurringChild && isUnlaunchedZero) return false;
                                            return value > 0;
                                          }).toList();
                                          final receiveAccounts = dayAccounts.where((accData) {
                                            final isReceber = accData['isRecebimento'] as bool;
                                            final value = accData['value'] as double;
                                            final launchedValue = accData['launchedValue'] as double?;
                                            final hasLaunch = launchedValue != null && launchedValue > 0;
                                            final isRecurringChild = accData['isRecurringChild'] as bool? ?? false;
                                            final isRecurringParent = accData['isRecurringParent'] as bool? ?? false;
                                            final isCardParent = accData['isCardParent'] as bool? ?? false;
                                            final isParentEntry = isRecurringParent || isCardParent;
                                            final isUnlaunchedZero =
                                                !hasLaunch && value <= 0;
                                            if (!isReceber) return false;
                                            if (hasLaunch) {
                                              return true;
                                            }
                                            if (isParentEntry && value > 0) {
                                              return true;
                                            }
                                            if (isRecurringChild && isUnlaunchedZero) {
                                              return false;
                                            }
                                            return value > 0;
                                          }).toList();

                                          double accountDisplayValue(Map<String, dynamic> accData) {
                                            final value = accData['value'] as double;
                                            final launchedValue = accData['launchedValue'] as double?;
                                            final hasLaunch = launchedValue != null && launchedValue > 0;
                                            final isRecurringParent =
                                                accData['isRecurringParent'] as bool? ?? false;
                                            final isCardParent = accData['isCardParent'] as bool? ?? false;
                                            final isParentEntry = isRecurringParent || isCardParent;
                                            if (hasLaunch) {
                                              return isParentEntry ? launchedValue : value;
                                            }
                                            return value;
                                          }

                                          final payTotal =
                                              payAccounts.fold<double>(0.0, (sum, acc) => sum + accountDisplayValue(acc));
                                          final receiveTotal = receiveAccounts.fold<double>(
                                              0.0, (sum, acc) => sum + accountDisplayValue(acc));
                                          final showPayTotal =
                                              hasAccounts && (payTotal > 0 || (dailyTotals?.previsto ?? 0) > 0);
                                          final showReceiveTotal = hasAccounts &&
                                              (receiveTotal > 0 || (dailyTotals?.recebimentosPrevisto ?? 0) > 0);

                                          Widget buildAccountBadge(Map<String, dynamic> accData, bool alignRight) {
                                            final value = accData['value'] as double;
                                            final launchedValue = accData['launchedValue'] as double?;
                                            final description = accData['description'] as String? ?? '';
                                            final typeIcon = accData['typeIcon'] as String;
                                            final isReceber = accData['isRecebimento'] as bool;
                                            final account = accData['account'];
                                            final isCard = isReceber && (account?.cardBrand != null);
                                            
                                            // Cores elegantes para os chips
                                            final chipTextColor = isReceber ? colorScheme.primary : colorScheme.error;
                                            final chipBgColor = isReceber
                                              ? colorScheme.primaryContainer.withValues(alpha: 0.6)
                                              : colorScheme.errorContainer.withValues(alpha: 0.6);
                                            final chipBorderColor = colorScheme.outlineVariant.withValues(alpha: 0.6);
                                            
                                            final hasLaunch = launchedValue != null && launchedValue > 0;
                                            final isRecurringParent = accData['isRecurringParent'] as bool? ?? false;
                                            final isCardParent = accData['isCardParent'] as bool? ?? false;
                                            final isInstallment = accData['isInstallment'] as bool? ?? false;
                                            final isParentEntry = isRecurringParent || isCardParent;
                                            final displayValue =
                                                isParentEntry && hasLaunch ? launchedValue : value;
                                            final cardBank =
                                                (account?.cardBank ?? account?.description ?? '').toString().trim();
                                            final displayDescription = isCard && cardBank.isNotEmpty
                                                ? cardBank
                                                : description;
                                            final showPlannedMark =
                                                isParentEntry && !hasLaunch && value > 0 && !isInstallment;

                                            return Container(
                                              constraints: const BoxConstraints(minHeight: 24),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: chipBgColor,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: chipBorderColor.withValues(alpha: 0.5), width: 0.5),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isCard)
                                                    _buildCardBrandLogo(account?.cardBrand)
                                                  else
                                                    Text(
                                                      typeIcon,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: chipTextColor,
                                                      ),
                                                    ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: displayDescription,
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w600,
                                                              color: showPlannedMark ? colorScheme.tertiary : chipTextColor,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: ' ${moneyFormat.format(displayValue)}',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: showPlannedMark ? colorScheme.tertiary : chipTextColor,
                                                            ),
                                                          ),
                                                          if (showPlannedMark)
                                                            TextSpan(
                                                              text: ' P',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w700,
                                                                color: colorScheme.tertiary,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      textAlign: alignRight ? TextAlign.right : TextAlign.left,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Cabeçalho do dia mais organizado
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        day.label,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: colorScheme.onSurfaceVariant,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '${day.date.day}',
                                                        style: TextStyle(
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w800,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                      const Spacer(),
                                                      if (isHoliday && holidayName != null)
                                                        Expanded(
                                                          child: Text(
                                                            holidayName,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            textAlign: TextAlign.right,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                              color: textColor.withValues(alpha: 0.8),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  if (showPayTotal || showReceiveTotal) ...[
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        if (showPayTotal)
                                                          Container(
                                                            height: 24,
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme.error,
                                                              borderRadius: BorderRadius.circular(5),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                moneyFormat.format(payTotal),
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: colorScheme.onError,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        if (showPayTotal && showReceiveTotal)
                                                          const SizedBox(width: 4),
                                                        if (showReceiveTotal)
                                                          Container(
                                                            height: 24,
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                            decoration: BoxDecoration(
                                                              color: colorScheme.primary,
                                                              borderRadius: BorderRadius.circular(5),
                                                            ),
                                                            child: Center(
                                                              child: Text(
                                                                moneyFormat.format(receiveTotal),
                                                                style: TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: colorScheme.onPrimary,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        if (showPayTotal && showReceiveTotal) ...[
                                                          const SizedBox(width: 6),
                                                          Builder(
                                                            builder: (context) {
                                                              final balance = receiveTotal - payTotal;
                                                              final absBalance = balance.abs();
                                                              final balanceText = balance < 0 
                                                                  ? '-R\$ ${absBalance.toStringAsFixed(2).replaceAll('.', ',')}'
                                                                  : 'R\$ ${absBalance.toStringAsFixed(2).replaceAll('.', ',')}';
                                                              final bgColor = balance > 0 
                                                                  ? colorScheme.primary
                                                                  : (balance < 0 ? colorScheme.error : colorScheme.onSurfaceVariant);
                                                              
                                                              return Container(
                                                                height: 24,
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  color: bgColor,
                                                                  borderRadius: BorderRadius.circular(5),
                                                                  border: Border.all(
                                                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                                                    width: 0.5,
                                                                  ),
                                                                ),
                                                                child: Center(
                                                                  child: Text(
                                                                    'Saldo do dia: $balanceText',
                                                                    style: TextStyle(
                                                                      fontSize: 8.5,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              if (payAccounts.isEmpty && receiveAccounts.isEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                                  child: Center(
                                                    child: Text(
                                                      'Sem lançamentos',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Color(0xFF9CA3AF),
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          if (payAccounts.isNotEmpty) ...[
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  Icons.arrow_downward_rounded,
                                                                  size: 10,
                                                                  color: colorScheme.error,
                                                                ),
                                                                const SizedBox(width: 3),
                                                                Text(
                                                                  'Pagamentos',
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: colorScheme.onSurfaceVariant,
                                                                    letterSpacing: 0.3,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                          ],
                                                          for (final accData in payAccounts) ...[
                                                            buildAccountBadge(accData, false),
                                                            const SizedBox(height: 3),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                        children: [
                                                          if (receiveAccounts.isNotEmpty) ...[
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Text(
                                                                  'Recebimentos',
                                                                  style: TextStyle(
                                                                    fontSize: 9,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: colorScheme.onSurfaceVariant,
                                                                    letterSpacing: 0.3,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 3),
                                                                Icon(
                                                                  Icons.arrow_upward_rounded,
                                                                  size: 10,
                                                                  color: colorScheme.primary,
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                          ],
                                                          for (final accData in receiveAccounts) ...[
                                                            Align(
                                                              alignment: Alignment.centerRight,
                                                              child: buildAccountBadge(accData, true),
                                                            ),
                                                            const SizedBox(height: 3),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                        ],
                                      ),
                                    ),
                                    // Faixa lateral colorida para feriados/fins de semana
                                    if (borderLeftColor != null)
                                      Positioned(
                                        left: 0,
                                        top: 8,
                                        bottom: 8,
                                        child: Container(
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: borderLeftColor,
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              bottomLeft: Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    // Badge "HOJE"
                                    if (isToday)
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(3),
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.outlineVariant,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'HOJE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  // --- CALENDÁRIO ANUAL ---
  Widget _buildCardBrandLogo(String? brand) {
    final normalized = (brand ?? '').trim().toUpperCase();
    String? assetPath;
    if (normalized == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS' || normalized == 'AMERICANEXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (normalized == 'MASTER' || normalized == 'MASTERCARD' || normalized == 'MASTER CARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (normalized == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        width: 14,
        height: 14,
        fit: BoxFit.contain,
      );
    }

    return Text(
      normalized.isEmpty ? 'CC' : normalized,
      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildAnnualCalendar() {
    return FutureBuilder<List<Holiday>>(
      future: _holidaysFuture,
      builder: (context, snapshot) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallMobile = screenWidth < 600;
        final Map<String, String> holidayNames = {};
        final Set<String> holidayDays = {};

        if (snapshot.hasData) {
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              holidayDays.add(key);
              holidayNames[key] = holiday.name;
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
        }

        return FutureBuilder<Map<int, ({double pagar, double receber})>>(
          future: _annualTotalsFuture,
          builder: (context, totalsSnapshot) {
            final annualTotals = totalsSnapshot.data ?? <int, ({double pagar, double receber})>{};
            final totalsReady = totalsSnapshot.connectionState == ConnectionState.done;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
              onHorizontalDragUpdate: (details) {
                _horizontalDragDistance += details.delta.dx;
              },
              onHorizontalDragCancel: () => _horizontalDragDistance = 0,
              onHorizontalDragEnd: (details) {
                _handleHorizontalSwipe(
                  details,
                  onSwipeLeft: () => _changeYear(1),
                  onSwipeRight: () => _changeYear(-1),
                );
              },
              child: Card(
                elevation: 0,
                color: Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.all(isSmallMobile ? 4 : 8),
                  child: Column(
                    children: [
                      MonthHeader(
                        title: '$_selectedYear',
                        onPrevious: () => _changeYear(-1),
                        onNext: () => _changeYear(1),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilterBar(
                        options: const [
                          FilterBarOption(value: 'semanal', label: 'Semanal'),
                          FilterBarOption(value: 'mensal', label: 'Mensal'),
                          FilterBarOption(value: 'anual', label: 'Anual'),
                        ],
                        selectedValue: _calendarType,
                        onSelected: (type) {
                          setState(() {
                            _calendarType = type;
                          });
                          _savePreferences();
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                  // GRID DOS MESES
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final double monthCardHeight = isSmallMobile ? 200 : 280;
                      const double verticalSpacingTop = 2;
                      const double verticalSpacingBetweenRows = 8;
                      const double verticalSpacingBottom = 4;
                      final double gridHorizontalPadding = isSmallMobile ? 8.0 : 24.0;

                      Widget buildMonthRow(List<int> monthIndices) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < monthIndices.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: monthCardHeight,
                                  child: _buildAnnualMonthCard(
                                    context: context,
                                    monthIndex: monthIndices[i],
                                    now: now,
                                    holidayNames: holidayNames,
                                    holidayDays: holidayDays,
                                    annualTotals: annualTotals,
                                    totalsReady: totalsReady,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallMobile ? 4 : gridHorizontalPadding,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            SizedBox(height: verticalSpacingTop),
                            if (isSmallMobile) ...[
                              // 2 colunas em mobile pequeno
                              buildMonthRow([0, 1]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([2, 3]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([4, 5]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([6, 7]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([8, 9]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([10, 11]),
                            ] else ...[
                              // 4 colunas em desktop/tablet
                              buildMonthRow([0, 1, 2, 3]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([4, 5, 6, 7]),
                              SizedBox(height: verticalSpacingBetweenRows),
                              buildMonthRow([8, 9, 10, 11]),
                            ],
                            SizedBox(height: verticalSpacingBottom),
                          ],
                        ),
                      );
                    },
                  ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // === SHELL FIXO: AppBar nunca rola ===
  Widget _buildFixedAppBar(bool isSmallMobile, bool isMobile) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.7)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 12 : 16, vertical: isSmallMobile ? 8 : 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ContasPRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isSmallMobile ? 17 : 20, color: Colors.white)),
                  Text('by Aguinaldo Liesack Baptistini', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmallMobile ? 10 : 11, color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
              if (_nextHolidayData?.holiday != null)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Chip(
                    label: Text('${_nextHolidayData!.holiday!.name} • ${_nextHolidayData!.daysUntil}d', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isSmallMobile ? 10 : 10.5, color: Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                    backgroundColor: Colors.amber.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.4), width: 1)),
                  ),
                ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.print, color: Colors.white), iconSize: isMobile ? 22 : 20, tooltip: 'Imprimir Relatório', onPressed: () => _printReport()),
              IconButton(icon: const Icon(Icons.calculate, color: Colors.white), iconSize: isMobile ? 22 : 20, tooltip: 'Calcular Datas', onPressed: () => _showDateCalculator(context)),
              _buildThemeToggleButton(iconColor: Colors.white, iconSize: isMobile ? 22 : 20),
              IconButton(icon: const Icon(Icons.settings, color: Colors.white), iconSize: isMobile ? 22 : 20, tooltip: 'Preferências', onPressed: () => showDialog(context: context, builder: (ctx) => Dialog(child: const SettingsScreen()))),
            ],
          ),
        ),
      ),
    );
  }

  // === SHELL FIXO: TabBar nunca rola ===
  Widget _buildFixedTabBar(double cardPadding) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: 8),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        labelColor: colorScheme.primary,
        unselectedLabelColor: const Color(0xFF6B7280),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colorScheme.primary.withValues(alpha: 0.08),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
        ),
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        tabs: [
          _buildPremiumTab('Contas', Icons.dashboard_outlined, 0),
          _buildPremiumTab('Calendário', Icons.calendar_month, 1),
          _buildPremiumTab('Feriados', Icons.list_alt, 2),
          _buildPremiumTab('Tabelas', Icons.table_chart, 3),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isSmallMobile = screenWidth < 600;
    final double fontSize = isMobile ? 18.0 : 16.0;
    final double cardPadding = isMobile ? 20.0 : 16.0;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: Theme.of(context).textTheme.titleMedium)])));
    }

    // === ARQUITETURA SHELL FIXO ===
    // AppBar e TabBar NUNCA rolam - cada aba gerencia seu próprio scroll
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          _buildFixedAppBar(isSmallMobile, isMobile),
          _buildFixedTabBar(cardPadding),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ABA CONTAS
                const ContasResumoTab(),
                // ABA CALENDÁRIO - scroll interno (sem header redundante)
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_calendarType == 'mensal')
                        _buildCalendarContainer(child: RepaintBoundary(key: _calendarGridKey, child: _buildCalendarGrid()))
                      else if (_calendarType == 'semanal')
                        _buildCalendarContainer(child: _buildWeeklyCalendar())
                      else if (_calendarType == 'anual')
                        _buildCalendarContainer(child: RepaintBoundary(key: _annualCalendarKey, child: _buildAnnualCalendar())),
                    ],
                  ),
                ),
                // ABA FERIADOS - scroll interno
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.all(cardPadding),
                  child: _buildFeriadosContent(fontSize, isSmallMobile),
                ),
                // ABA TABELAS
                const TablesScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Conteúdo da aba Feriados (extraído para método separado)
  Widget _buildFeriadosContent(double fontSize, bool isSmallMobile) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Feriados',
      subtitle: 'Ano $_selectedYear',
      child: FutureBuilder<List<Holiday>>(
        future: _holidaysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const EmptyState(icon: Icons.event_busy, title: 'Carregando feriados...');
          } else if (snapshot.hasError) {
            return EmptyState(icon: Icons.error_outline, title: 'Erro ao carregar feriados', subtitle: '${snapshot.error}');
          } else if (snapshot.hasData) {
            final holidays = snapshot.data!;
            if (holidays.isEmpty) return const EmptyState(icon: Icons.event_busy, title: 'Nenhum feriado encontrado');
            final holidaysCurrentYear = holidays.where((h) { try { return DateTime.parse(h.date).year == _selectedYear; } catch (_) { return false; } }).toList();
            final Map<String, Holiday> uniqueHolidaysMap = {};
            for (var holiday in holidaysCurrentYear) { if (!uniqueHolidaysMap.containsKey(holiday.date)) uniqueHolidaysMap[holiday.date] = holiday; }
            final uniqueHolidays = uniqueHolidaysMap.values.toList();
            final stats = _calculateStats(holidaysCurrentYear);
            Color typeColor(String type) {
              if (type.contains('Bancário')) return colorScheme.secondary;
              if (type.contains('Nacional')) return colorScheme.primary;
              if (type.contains('Estadual')) return colorScheme.tertiary;
              if (type.contains('Municipal')) return colorScheme.secondaryContainer;
              return colorScheme.onSurfaceVariant;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainStatsSummary(stats, fontSize, isSmallMobile: isSmallMobile),
                _buildWeekdayStatsChips(stats, fontSize),
                const SizedBox(height: AppSpacing.sm),
                SectionHeader(title: 'Lista de Feriados de $_selectedYear', icon: Icons.event_note),
                const SizedBox(height: AppSpacing.md),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: uniqueHolidays.length,
                  itemBuilder: (context, index) {
                    final holiday = uniqueHolidays[index];
                    final formattedDate = _formatDate(holiday.date);
                    DateTime? parsed; try { parsed = DateFormat('yyyy-MM-dd').parse(holiday.date); } catch (_) {}
                    final dayLabel = parsed != null ? parsed.day.toString().padLeft(2, '0') : '--';
                    final weekdayLabel = parsed != null ? DateFormat('EEE', 'pt_BR').format(parsed).replaceAll('.', '').toUpperCase() : '--';
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6))),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ui_date.DatePill(day: dayLabel, weekday: weekdayLabel),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(holiday.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: AppSpacing.xs),
                                Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: holiday.types.map((type) => ui_chips.MiniChip(label: type, textColor: typeColor(type))).toList()),
                                if (holiday.specialNote != null) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm),
                                    decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6))),
                                    child: Row(children: [Icon(Icons.access_time, size: 16, color: colorScheme.onSurfaceVariant), const SizedBox(width: AppSpacing.sm), Expanded(child: Text(holiday.specialNote!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)))]),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class ContasTab extends StatefulWidget {
  const ContasTab({super.key});

  @override
  State<ContasTab> createState() => _ContasTabState();
}

class ContasResumoTab extends StatefulWidget {
  const ContasResumoTab({super.key});

  @override
  State<ContasResumoTab> createState() => _ContasResumoTabState();
}

class _ContasResumoTabState extends State<ContasResumoTab> {
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await configureContasDatabaseIfNeeded();

      await contas_prefs.PrefsService.init();
      contas_prefs.PrefsService.setEmbeddedMode(false);

      try {
        await contas_db.DatabaseInitializationService.instance.initializeDatabase();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = e;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Carregando Contas...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                'Erro ao abrir o módulo Contas',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: contas_dash.DashboardScreen(
        appBarColorOverride: const Color(0xFF795548),
        totalLabelOverride: 'TOTAL DO MÊS',
        totalForecastLabelOverride: 'PREVISTO NO MÊS',
        emptyTextOverride: 'Nenhuma conta, cartão ou recebimento neste mês.',
        excludeTypeNameFilter: null,
        typeNameFilter: null,
      ),
    );
  }
}

class _ContasTabState extends State<ContasTab> {
  bool _ready = false;
  bool _migrationRequired = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await configureContasDatabaseIfNeeded();

      await contas_prefs.PrefsService.init();
      contas_prefs.PrefsService.setEmbeddedMode(false);

      try {
        await contas_db.DatabaseInitializationService.instance.initializeDatabase();
      } catch (_) {
        _migrationRequired = true;
      }

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Carregando Contas...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                'Erro ao abrir o módulo Contas',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: contas_app.FinanceApp(
        migrationRequired: _migrationRequired,
        initialTabIndex: 0,
      ),
    );
  }
}



class RecebimentosTab extends StatefulWidget {
  const RecebimentosTab({super.key});

  @override
  State<RecebimentosTab> createState() => _RecebimentosTabState();
}

class _RecebimentosTabState extends State<RecebimentosTab> {
  bool _ready = false;
  bool _migrationRequired = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await configureContasDatabaseIfNeeded();

      await contas_prefs.PrefsService.init();
      contas_prefs.PrefsService.setEmbeddedMode(false);

      try {
        await contas_db.DatabaseInitializationService.instance.initializeDatabase();
      } catch (_) {
        _migrationRequired = true;
      }

      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Carregando Recebimentos...', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                'Erro ao abrir o módulo Recebimentos',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$_error',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: contas_app.FinanceApp(
        migrationRequired: _migrationRequired,
        initialTabIndex: 1,
      ),
    );
  }
}

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  Widget? _currentScreen;

  @override
  Widget build(BuildContext context) {
    final items = [
      _TableShortcut(
        title: 'Contas a Pagar',
        subtitle: 'Categorias para contas a pagar',
        icon: Icons.category,
        builder: () => const AccountTypesScreen(),
      ),
      _TableShortcut(
        title: 'Contas a Receber',
        subtitle: 'Categorias para contas a receber',
        icon: Icons.savings,
        builder: () => const RecebimentosTableScreen(),
      ),
      _TableShortcut(
        title: 'Contas Bancarias',
        subtitle: 'Bancos e contas',
        icon: Icons.account_balance,
        builder: () => const BankAccountsScreen(),
      ),
      _TableShortcut(
        title: 'Formas de Pagamento/Recebimento',
        subtitle: 'Cartão, boleto, etc.',
        icon: Icons.payments,
        builder: () => const PaymentMethodsScreen(),
      ),
    ];

    if (_currentScreen != null) {
      String? tableTitle;
      if (_currentScreen is AccountTypesScreen) {
        tableTitle = 'Contas a Pagar';
      } else if (_currentScreen is RecebimentosTableScreen) {
        tableTitle = 'Contas a Receber';
      } else if (_currentScreen is BankAccountsScreen) {
        tableTitle = 'Contas Bancárias';
      } else if (_currentScreen is PaymentMethodsScreen) {
        tableTitle = 'Formas de Pagamento/Recebimento';
      }

      return AppScaffold(
        title: tableTitle ?? 'Tabelas',
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Voltar',
            onPressed: () => setState(() => _currentScreen = null),
          ),
        ],
        child: _currentScreen!,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Tabelas',
      contentPadding: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _buildTableShortcutTile(context, items[i], colorScheme),
              if (i < items.length - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableShortcutTile(
    BuildContext context,
    _TableShortcut item,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(item.icon, color: colorScheme.onPrimaryContainer),
        ),
        title: Text(item.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          item.subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: () => setState(() => _currentScreen = item.builder()),
      ),
    );
  }
}

class _TableShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function() builder;

  const _TableShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

// === FIM DO ARQUIVO ===
