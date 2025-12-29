import 'package:finance_app/screens/account_types_screen.dart';
import 'package:finance_app/screens/credit_card_form.dart';
import 'package:finance_app/screens/bank_accounts_screen.dart';
import 'package:finance_app/screens/payment_methods_screen.dart';
import 'package:finance_app/screens/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
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

import 'package:finance_app/main.dart' as contas_app;
import 'package:finance_app/services/database_initialization_service.dart' as contas_db;
import 'package:finance_app/services/prefs_service.dart' as contas_prefs;

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
  
  // Inicializar window_manager para desktop
  if (GetPlatform.isDesktop) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      // Cargar tamaño guardado o usar default
      final prefs = await SharedPreferences.getInstance();
      final savedWidth = prefs.getDouble('windowWidth') ?? 1200;
      final savedHeight = prefs.getDouble('windowHeight') ?? 800;
      
      await windowManager.setSize(Size(savedWidth, savedHeight));
      await windowManager.show();
    });
  }
  
  await initializeDateFormatting('pt_BR', null); 
  Intl.defaultLocale = 'pt_BR'; 
  runApp(const MyApp());
}

// Detectar plataforma
class GetPlatform {
  static bool get isDesktop => !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
}

// =======================================================
// === MODELOS DE DADOS ===
// =======================================================

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
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDarkMode = prefs.getBool('isDarkMode') ?? false;
      setState(() {
        _isDarkMode = savedDarkMode;
      });
    } catch (e) {
      debugPrint('Erro ao carregar tema: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ContasPRO',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2), brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      home: HolidayScreen(
        onThemeChanged: (isDark) {
          setState(() {
            _isDarkMode = isDark;
          });
        },
      ),
    );
  }
}

// =======================================================
// === TELA PRINCIPAL ===
// =======================================================

class HolidayScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final DateTime? initialDate;

  const HolidayScreen({super.key, required this.onThemeChanged, this.initialDate});

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
  late AnimationController _animationController;
  late TabController _tabController;
  bool _isLoading = false;
  bool _isDarkMode = false;
  final Map<int, Future<List<Holiday>>> _holidaysCache = {};
  double _horizontalDragDistance = 0;

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
    _initializeCities();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _tabController = TabController(length: 3, vsync: this);
    
    // Inicializar _holidaysFuture antes de qualquer coisa
    _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
    
    _loadPreferences();
    
    // Setup para salvar tamanho da janela periodicamente em desktop
    if (GetPlatform.isDesktop) {
      Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) _saveWindowSize();
      });
    }
  }
  
  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedYear = now.year;
      _calendarMonth = now.month;
      _selectedWeek = now;
      _holidaysFuture = _getHolidaysForDisplay(_selectedYear);
    });
    _savePreferences();
  }
  
  Widget _buildTodayButton() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 600;

    if (isSmallMobile) {
      // Em mobile, usar ícone de reset
      return IconButton(
        icon: const Icon(Icons.restore),
        iconSize: 24,
        color: Theme.of(context).colorScheme.primary,
        tooltip: 'Voltar para hoje',
        onPressed: _goToToday,
      );
    }

    // Em desktop, usar botão
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: _goToToday,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
        child: const Text('Hoje'),
      ),
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
    });
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
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 600;
    final month = monthIndex + 1;
    final monthNames = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    final firstDayOfMonth = DateTime(_selectedYear, month, 1);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(_selectedYear, month + 1, 0).day;
    const baseDayColor = Color(0xFFE5E6EA);
    const saturdayColor = Color(0xFFF7B3B3);
    const sundayColor = Color(0xFFD75252);
    const holidayColor = Color(0xFF3F9441);

    final monthHolidayEntries = <MapEntry<int, String>>[];
    for (int day = 1; day <= daysInMonth; day++) {
      final entryKey = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final entryName = holidayNames[entryKey];
      if (entryName != null) {
        monthHolidayEntries.add(MapEntry(day, entryName));
      }
    }
    final visibleHolidayEntries = monthHolidayEntries.take(4).toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 1.5),
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
              child: Text(
                monthNames[monthIndex],
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isSmallMobile ? 12 : 14, fontWeight: FontWeight.w900),
              ),
            ),
            Row(
              children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(fontSize: isSmallMobile ? 7 : 8, fontWeight: FontWeight.bold),
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
                      Color textColor = Colors.black;
                      Color? todayHighlightColor;

                      if (isToday) {
                        todayHighlightColor = Colors.yellow[600] ?? Colors.yellow;
                        textColor = Colors.black;
                      } else if (isHoliday) {
                        bgColor = holidayColor;
                        textColor = Colors.white;
                      } else if (dayOfWeek == 0) {
                        bgColor = sundayColor;
                        textColor = Colors.white;
                      } else if (dayOfWeek == 6) {
                        bgColor = saturdayColor;
                        textColor = Colors.white;
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(color: Colors.black, width: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (todayHighlightColor != null)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: todayHighlightColor,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                              ),
                            Text(
                              day.toString(),
                              style: TextStyle(fontSize: isSmallMobile ? 10 : 13, fontWeight: FontWeight.w700, color: textColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            if (visibleHolidayEntries.isNotEmpty) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in visibleHolidayEntries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              '${entry.key} - ${entry.value}',
                              style: TextStyle(fontSize: isSmallMobile ? 8 : 9, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
    
    cities.sort((a, b) => a.name.compareTo(b.name));
    
    _selectedCity = cities.firstWhere((city) => city.name == 'São José dos Campos', orElse: () => cities.first);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCityName = prefs.getString('selectedCity');
      if (savedCityName != null) {
        final cityIndex = cities.indexWhere((city) => city.name == savedCityName);
        if (cityIndex != -1) {
          _selectedCity = cities[cityIndex];
        }
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
      _isLoading = false;
    });
    _animationController.forward();
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCity', _selectedCity.name);
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

  // --- MENU SOBRE (LAYOUT RESTAURADO COM SWITCH ABAIXO DO AUTOR) ---
  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          size: 50,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'CalendarPRO v$appDisplayVersion',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Versão $appVersion (Build $appBuild) - ${_selectedCity.name}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Desenvolvido por',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aguinaldo Liesack Baptistini',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // === PREFERÊNCIAS (REGIÃO E CIDADE) ===
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Preferências',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // BOTÃO DE MODO ESCURO (MOVIDO PARA CÁ)
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      'Modo Escuro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _isDarkMode ? 'Ativado' : 'Desativado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    secondary: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    value: _isDarkMode,
                    onChanged: (bool value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _savePreferences();
                      widget.onThemeChanged(value);
                      Navigator.pop(context);
                    },
                  ),
                ),
                
                const SizedBox(height: 16),

                // Fonte da API
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.api,
                        size: 32,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fonte de Dados',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BrasilAPI',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        apiSource,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('FECHAR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCitySelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filtrar cidades baseado no texto de busca
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
                  // Título
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
                  // Campo de busca
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
                    onChanged: (value) {
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  // Lista de cidades filtrada
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

  void _printReport() async {
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
          case DateTime.saturday: case DateTime.sunday: stats.finaisSemana++; break;
        }
      } catch (e) {
        // Tratamento de erro na análise de feriado
      }
    }

    return stats;
  }

  // --- RESUMO QUE APARECE NA TELA PRINCIPAL (LIMPO E CORRIGIDO PARA DARK MODE) ---
  Widget _buildMainStatsSummary(HolidayStats stats, double fontSize, {bool isSmallMobile = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 2,
      // Cor de fundo do card adaptativa
      color: Theme.of(context).cardTheme.color,
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card clicável para selecionar cidade
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
            const SizedBox(height: 16),
            Text('RESUMO DO ANO $_selectedYear', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 2, color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 8),
            isSmallMobile
              ? Column(
                  children: [
                    // Primeira linha: Total de Feriados + Dias Úteis
                    Row(
                      children: [
                        Expanded(child: _buildStatBadgeCompact('Total de Feriados', stats.totalFeriadosUnicos, Colors.green, fontSize)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatBadgeCompact('Dias Úteis', stats.diasUteis, Colors.indigo, fontSize)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Segunda linha: Finais de Semana
                    Row(
                      children: [
                        Expanded(child: _buildStatBadgeCompact('Finais de Semana', stats.finaisSemana, Colors.red, fontSize)),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildStatBadge('Total de Feriados', stats.totalFeriadosUnicos, Colors.green, fontSize)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatBadge('Dias Úteis', stats.diasUteis, Colors.indigo, fontSize)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatBadge('Finais de Semana', stats.finaisSemana, Colors.red, fontSize)),
                  ],
                ),
            const Divider(height: 8),
             Text('Por Tipo', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            // Uso de cores dinâmicas para fundo (claro em Light, transparente em Dark) e texto (preto em Light, branco em Dark)
            _buildStatRow(context, 'Nacionais', stats.nacionais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50]),
            _buildStatRow(context, 'Municipais', stats.municipais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange[50]),
            _buildStatRow(context, 'Bancários', stats.bancarios, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.teal.withValues(alpha: 0.2) : Colors.teal[50]),
            _buildStatRow(context, 'Estaduais', stats.estaduais, isDark ? Colors.white : Colors.black87, backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple[50]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatBadge(String label, int value, Color color, double fontSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Forma decorativa com borda arredondada estilo "fita"
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
        // Forma decorativa com borda arredondada - mais compacta para mobile
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

  // --- MODIFICADO: _buildStatRow COM CORES DINÂMICAS ---
  Widget _buildStatRow(BuildContext context, String label, int value, Color textColor, {Color? backgroundColor}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
                // Badge de número: Cinza claro no Light, Cinza Escuro no Dark
                color: isDark ? Colors.grey[800] : Colors.grey[200], 
                borderRadius: BorderRadius.circular(8)
            ),
            child: Text(value.toString(), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS AUXILIARES ---
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


  Widget _buildCalendarGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isSmallMobile = screenWidth < 600;
    final double fontSize = isMobile ? 11.0 : 13.0;
    final double headerFontSize = isMobile ? 13.0 : 15.0;
    
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
    
    final monthName = ['JANEIRO', 'FEVEREIRO', 'MARÇO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'][_calendarMonth - 1];
    
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
        
        debugPrint('=== Calendário Debug ===');
        debugPrint('Mês selecionado: $_calendarMonth, Ano: $_selectedYear');
        debugPrint('Mês anterior: $prevMonth/$prevYear');
        debugPrint('Próximo mês: $nextMonth/$nextYear');
        debugPrint('Dados do snapshot: ${snapshot.hasData}');
        
        if (snapshot.hasData) {
          debugPrint('Total de feriados carregados: ${snapshot.data!.length}');
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              debugPrint('Processando feriado: ${holiday.name} em ${holiday.date} (key: $key)');
              
              // Verificar se é do mês atual, anterior ou próximo
              if ((holidayDate.month == _calendarMonth && holidayDate.year == _selectedYear) ||
                  (holidayDate.month == prevMonth && holidayDate.year == prevYear) ||
                  (holidayDate.month == nextMonth && holidayDate.year == nextYear)) {
                debugPrint('✓ Feriado ADICIONADO: ${holiday.name}');
                holidayDays.add(key);
                holidayNames[key] = holiday.name;
              } else {
                debugPrint('✗ Feriado IGNORADO: ${holiday.name}');
              }
            } catch (e) {
              debugPrint('Erro ao parsear feriado: ${holiday.date} - $e');
            }
          }
          debugPrint('Total de feriados para este mês: ${holidayDays.length}');
        } else if (snapshot.hasError) {
          debugPrint('ERRO ao carregar feriados: ${snapshot.error}');
        } else {
          debugPrint('Carregando feriados...');
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
                if (isSmallMobile)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                            tooltip: 'Mês anterior',
                            iconSize: 28,
                          ),
                          Text(
                            '$monthName $_selectedYear',
                            style: TextStyle(
                              fontSize: isSmallMobile ? 20 : 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.blue,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _changeMonth(1),
                            tooltip: 'Próximo mês',
                            iconSize: 28,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildTodayButton(),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 100,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _calendarType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                items: const [
                                  DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                                  DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                                  DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                                ],
                                onChanged: (type) {
                                  if (type != null) {
                                    setState(() {
                                      _calendarType = type;
                                    });
                                    _savePreferences();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          '$monthName $_selectedYear',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.blue,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTodayButton(),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: _calendarType,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                  items: const [
                                    DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                                    DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                                    DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                                  ],
                                  onChanged: (type) {
                                    if (type != null) {
                                      setState(() {
                                        _calendarType = type;
                                      });
                                      _savePreferences();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallMobile ? 8 : 40),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: dayHeaders.map((day) => Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: headerFontSize * 0.8,
                                      fontWeight: FontWeight.bold,
                                      color: day == 'DOM' || day == 'SAB'
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.onSurface,
                                      backgroundColor: day == 'DOM'
                                          ? Colors.red
                                          : (day == 'SAB'
                                              ? const Color(0xFFEF9A9A)
                                              : Colors.transparent),
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
                                
                                Color bgColor = Colors.white;
                                Color textColor = Theme.of(context).colorScheme.onSurface;
                                double opacity = 1.0;
                                Color? todayHighlightColor;

                                if (isToday) {
                                  todayHighlightColor = Colors.yellow[600] ?? Colors.yellow;
                                  textColor = Colors.black;
                                } else if (isHoliday) {
                                  bgColor = isCurrentMonth ? Colors.green : (Colors.lightGreen[300] ?? Colors.lightGreen);
                                  textColor = isCurrentMonth ? Colors.white : (Colors.grey[700] ?? Colors.grey);
                                  opacity = 1.0;
                                } else if (dayOfWeek == 0) { // Domingo
                                  bgColor = Colors.red;
                                  textColor = Colors.white;
                                } else if (dayOfWeek == 6) { // Sábado
                                  bgColor = Color(0xFFEF9A9A);
                                  textColor = Colors.white;
                                } else if (!isCurrentMonth) {
                                  bgColor = Colors.grey[600] ?? Colors.grey;
                                  opacity = 0.6;
                                  textColor = Colors.white;
                                }
                                
                                return Tooltip(
                                  message: holidayName ?? '',
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: bgColor.withValues(alpha: opacity),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 2.0,
                                      ),
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    padding: EdgeInsets.all(1.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (todayHighlightColor != null)
                                              Container(
                                                width: isSmallMobile ? 36 : 66,
                                                height: isSmallMobile ? 36 : 66,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: todayHighlightColor,
                                                  border: Border.all(color: Colors.black, width: 3),
                                                ),
                                              ),
                                            Text(
                                              day.toString(),
                                              style: TextStyle(fontSize: fontSize * (isSmallMobile ? 1.4 : 1.7), fontWeight: FontWeight.w900, color: textColor),
                                            ),
                                          ],
                                        ),
                                        if (isToday)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              'HOJE',
                                              style: TextStyle(fontSize: fontSize * 0.9, fontWeight: FontWeight.w700, color: Colors.black),
                                            ),
                                          ),
                                        if (isHoliday && holidayName != null)
                                          Flexible(
                                            child: Padding(
                                              padding: const EdgeInsets.only(top: 0.0),
                                              child: Text(
                                                holidayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: fontSize * (isSmallMobile ? 0.75 : 0.85), fontWeight: FontWeight.w600, color: textColor),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (!isSmallMobile)
                        Positioned(
                          left: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tightFor(width: isSmallMobile ? 48 : 56, height: isSmallMobile ? 48 : 56),
                              iconSize: 30,
                              splashRadius: 30,
                              icon: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  size: 24,
                                  color: Colors.white,
                                  weight: 700,
                                ),
                              ),
                              onPressed: () => _changeMonth(-1),
                            ),
                          ),
                        ),
                      if (!isSmallMobile)
                        Positioned(
                          right: 12,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints.tightFor(width: isSmallMobile ? 48 : 56, height: isSmallMobile ? 48 : 56),
                              iconSize: 30,
                              splashRadius: 30,
                              icon: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 24,
                                  color: Colors.white,
                                  weight: 700,
                                ),
                              ),
                              onPressed: () => _changeMonth(1),
                            ),
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
  }

  // --- CALENDÁRIO SEMANAL ---
  Widget _buildWeeklyCalendar() {
    final startOfWeek = _selectedWeek.subtract(Duration(days: _selectedWeek.weekday % 7));
    final weekDays = <({String label, DateTime date})>[];
    final dayLabels = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    final monthNamesComplete = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

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
          debugPrint('=== SEMANAL DEBUG ===');
          debugPrint('Total de feriados carregados: ${snapshot.data!.length}');
          for (final holiday in snapshot.data!) {
            try {
              final holidayDate = DateTime.parse(holiday.date);
              final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
              holidayDays.add(key);
              holidayNames[key] = holiday.name;
              debugPrint('Feriado: ${holiday.name} em $key');
            } catch (e) {
              // Erro ao parsear feriado
            }
          }
          debugPrint('Feriados da semana ${startOfWeek.toIso8601String()}: ${holidayDays.length}');
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
              onSwipeLeft: () => _changeWeek(1),
              onSwipeRight: () => _changeWeek(-1),
            );
          },
          child: Transform.scale(
            scale: 0.92,
            alignment: Alignment.topCenter,
            child: Card(
              elevation: 1,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(
                                text: 'Semana #$weekNumber\n',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.blue),
                              ),
                              TextSpan(
                                text: '${monthNamesComplete[startOfWeek.month - 1]} ${startOfWeek.year}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTodayButton(),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 120,
                              height: 32,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: _calendarType,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                  items: const [
                                    DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                                    DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                                    DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                                  ],
                                  onChanged: (type) {
                                    if (type != null) {
                                      setState(() {
                                        _calendarType = type;
                                      });
                                      _savePreferences();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 40,
                              icon: Icon(Icons.arrow_circle_left_rounded),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _changeWeek(-1),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: weekDays.map((day) {
                              final now = DateTime.now();
                              final isToday = day.date.year == now.year && day.date.month == now.month && day.date.day == now.day;
                              final holidayKey = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
                              final isHoliday = holidayDays.contains(holidayKey);
                              final holidayName = isHoliday ? holidayNames[holidayKey] : null;

                              Color bgColor = Colors.white;
                              Color textColor = Theme.of(context).colorScheme.onSurface;

                              if (isToday) {
                                bgColor = Colors.blue;
                                textColor = Colors.white;
                              } else if (isHoliday) {
                                bgColor = Colors.green;
                                textColor = Colors.white;
                              } else if (day.label == 'DOM') {
                                bgColor = Colors.red;
                                textColor = Colors.white;
                              } else if (day.label == 'SAB') {
                                bgColor = Color(0xFFEF9A9A);
                                textColor = Colors.white;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.black, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      day.label,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${day.date.day}',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          if (isToday)
                                            Text('HOJE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor)),
                                          if (isHoliday && holidayName != null)
                                            Text(
                                              holidayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Center(
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 40,
                              icon: Icon(Icons.arrow_circle_right_rounded),
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () => _changeWeek(1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- CALENDÁRIO ANUAL ---
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

        Widget buildYearNavButton({required bool isNext}) {
          final double arrowDiameter = isSmallMobile ? 32.0 : 36.0;
          return GestureDetector(
            onTap: () => _changeYear(isNext ? 1 : -1),
            child: Container(
              width: arrowDiameter,
              height: arrowDiameter,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1E88E5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 6),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2.2),
                ),
                child: Center(
                  child: Icon(
                    isNext ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
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
              onSwipeLeft: () => _changeYear(1),
              onSwipeRight: () => _changeYear(-1),
            );
          },
          child: Card(
            elevation: 1,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: EdgeInsets.all(isSmallMobile ? 8 : 16),
                child: Column(
                children: [
                  // CABEÇALHO COM CONTROLES DO ANO E TIPO DE CALENDÁRIO
                  if (isSmallMobile)
                    SizedBox(
                      height: 60,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildYearNavButton(isNext: false),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF0D47A1), Color(0xFF2196F3)],
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                              ],
                              border: Border.all(color: Colors.white70, width: 2),
                            ),
                            child: Text(
                              '$_selectedYear',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          buildYearNavButton(isNext: true),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButton<String>(
                                value: _calendarType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                items: const [
                                  DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                                  DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                                  DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                                ],
                                onChanged: (type) {
                                  if (type != null) {
                                    setState(() {
                                      _calendarType = type;
                                    });
                                    _savePreferences();
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 72,
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                buildYearNavButton(isNext: false),
                                const SizedBox(width: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF0D47A1), Color(0xFF2196F3)],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                                    ],
                                    border: Border.all(color: Colors.white70, width: 2),
                                  ),
                                  child: Text(
                                    '$_selectedYear',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                buildYearNavButton(isNext: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTodayButton(),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 130,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.outline,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _calendarType,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                                    items: const [
                                      DropdownMenuItem<String>(value: 'semanal', child: Text('Semanal')),
                                      DropdownMenuItem<String>(value: 'mensal', child: Text('Mensal')),
                                      DropdownMenuItem<String>(value: 'anual', child: Text('Anual')),
                                    ],
                                    onChanged: (type) {
                                      if (type != null) {
                                        setState(() {
                                          _calendarType = type;
                                        });
                                        _savePreferences();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  // GRID DOS MESES
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final double monthCardHeight = isSmallMobile ? 200 : 280;
                      const double verticalSpacingTop = 2;
                      const double verticalSpacingBetweenRows = 4;
                      const double verticalSpacingBottom = 4;
                      final double gridHorizontalPadding = isSmallMobile ? 8.0 : 32.0;

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
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isSmallMobile = screenWidth < 600;
    final double fontSize = isMobile ? 18.0 : 16.0;
    final double cardPadding = isMobile ? 20.0 : 16.0;

    if (_isLoading) {
      return Scaffold(body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: Theme.of(context).textTheme.titleMedium)])));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: isSmallMobile ? 150 : (isMobile ? 55 : 53),
            pinned: true,
            centerTitle: true,
            actions: isMobile ? [] : [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.account_balance),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Bancos',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BankAccountsScreen(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.payment),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Formas de Pagamento',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.category),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Tabelas',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountTypesScreen(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.credit_card),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Novo Cartão',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreditCardFormScreen(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.print),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Imprimir Relatório',
                  onPressed: () => _printReport(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.calculate),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Calcular Datas',
                  onPressed: () => _showDateCalculator(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.settings),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Configurações',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  iconSize: isMobile ? 28 : 24,
                  tooltip: 'Sobre',
                  onPressed: _showAbout,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'ContasPRO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isSmallMobile ? 18 : 20,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'by Aguinaldo Liesack Baptistini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallMobile ? 10 : 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isSmallMobile)
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print),
                      iconSize: 24,
                      tooltip: 'Imprimir Relatório',
                      color: Colors.white,
                      onPressed: () => _printReport(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calculate),
                      iconSize: 24,
                      tooltip: 'Calcular Datas',
                      color: Colors.white,
                      onPressed: () => _showDateCalculator(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      iconSize: 24,
                      tooltip: 'Sobre',
                      color: Colors.white,
                      onPressed: _showAbout,
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: cardPadding, right: cardPadding, top: cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TABBAR COM DUAS ABAS
                  TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Calendário', icon: Icon(Icons.calendar_month)),
                      Tab(text: 'Resumo', icon: Icon(Icons.list_alt)),
                      Tab(text: 'Contas', icon: Icon(Icons.receipt_long)),
                    ],
                  ),
                  // TABBARVIEW COM O CONTEÚDO DAS DUAS ABAS
                  SizedBox(
                    height: MediaQuery.of(context).size.height - (isSmallMobile ? 120 : 100),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // ABA 1: CALENDÁRIO
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // CALENDÁRIO CONFORME TIPO SELECIONADO
                              if (_calendarType == 'mensal')
                                RepaintBoundary(
                                  key: _calendarGridKey,
                                  child: _buildCalendarGrid(),
                                )
                              else if (_calendarType == 'semanal')
                                _buildWeeklyCalendar()
                              else if (_calendarType == 'anual')
                                RepaintBoundary(
                                  key: _annualCalendarKey,
                                  child: _buildAnnualCalendar(),
                                ),
                            ],
                          ),
                        ),
                        // ABA 2: RESUMO DE FERIADOS
                        SingleChildScrollView(
                          child: FutureBuilder<List<Holiday>>(
                            future: _holidaysFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [CircularProgressIndicator(color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16), Text('Carregando feriados...', style: TextStyle(color: Colors.grey[600], fontSize: fontSize))])));
                              } else if (snapshot.hasError) {
                                return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [Icon(Icons.error_outline, size: 48, color: Colors.red[300]), const SizedBox(height: 16), Text('Erro ao carregar feriados', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: fontSize), textAlign: TextAlign.center), const SizedBox(height: 8), Text('${snapshot.error}', style: TextStyle(color: Colors.grey[600], fontSize: fontSize - 4), textAlign: TextAlign.center)])));
                              } else if (snapshot.hasData) {
                                final holidays = snapshot.data!;
                                if (holidays.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Column(children: [Icon(Icons.event_busy, size: 48, color: Colors.grey[400]), const SizedBox(height: 16), Text('Nenhum feriado encontrado', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: fontSize))])));

                                // Filtra apenas feriados do ano selecionado
                                final holidaysCurrentYear = holidays.where((h) {
                                  try {
                                    final year = DateTime.parse(h.date).year;
                                    return year == _selectedYear;
                                  } catch (e) {
                                    return false;
                                  }
                                }).toList();

                                // Deduplica feriados por data
                                final Map<String, Holiday> uniqueHolidaysMap = {};
                                for (var holiday in holidaysCurrentYear) {
                                  if (!uniqueHolidaysMap.containsKey(holiday.date)) {
                                    uniqueHolidaysMap[holiday.date] = holiday;
                                  }
                                }
                                final uniqueHolidays = uniqueHolidaysMap.values.toList();

                                final stats = _calculateStats(holidaysCurrentYear);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMainStatsSummary(stats, fontSize, isSmallMobile: isSmallMobile), // ESTATISTICAS NA TELA PRINCIPAL (LIMPO E COLORIDO)
                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Row(children: [Icon(Icons.event_note, color: Theme.of(context).colorScheme.primary, size: isMobile ? 28 : 24), const SizedBox(width: 8), Expanded(child: Text('Lista de Feriados de $_selectedYear', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: fontSize + 4)))])),
                                    SizedBox(height: isMobile ? 16 : 12),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: uniqueHolidays.length,
                                      itemBuilder: (context, index) {
                                        final holiday = uniqueHolidays[index];
                                        final formattedDate = _formatDate(holiday.date);
                                        bool isWeekend = false;
                                        try { isWeekend = (DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.saturday || DateFormat('yyyy-MM-dd').parse(holiday.date).weekday == DateTime.sunday); } catch (e) {
                                          // Ignorar erro na análise de fim de semana
                                        }
                                        return Card(
                                          elevation: 1,
                                          color: null,
                                          margin: EdgeInsets.only(bottom: isMobile ? 12 : 8),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () { HapticFeedback.lightImpact(); },
                                            child: Padding(
                                              padding: EdgeInsets.all(isMobile ? 18 : 16),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Column(children: holiday.types.map((type) {
                                                    Color typeColor = Colors.grey;
                                                    if (type.contains('Bancário')) typeColor = Colors.teal;
                                                    if (type.contains('Nacional')) typeColor = Colors.blue;
                                                    if (type.contains('Estadual')) typeColor = Colors.purple;
                                                    if (type.contains('Municipal')) typeColor = Colors.orange;
                                                    return Container(margin: const EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(isMobile ? 14 : 12), decoration: BoxDecoration(color: isWeekend ? Colors.red[100] : typeColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.event, color: isWeekend ? Colors.red : typeColor, size: isMobile ? 28 : 24));
                                                  }).toList()),
                                                  SizedBox(width: isMobile ? 18 : 16),
                                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(holiday.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobile ? fontSize + 2 : fontSize)), SizedBox(height: isMobile ? 6 : 4), Text(formattedDate, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700], fontSize: isMobile ? fontSize : fontSize - 2)), SizedBox(height: isMobile ? 6 : 4), Wrap(spacing: 6, runSpacing: 6, children: holiday.types.map((type) { Color typeColor = Colors.grey; if (type.contains('Bancário')) typeColor = Colors.teal; if (type.contains('Nacional')) typeColor = Colors.blue; if (type.contains('Estadual')) typeColor = Colors.purple; if (type.contains('Municipal')) typeColor = Colors.orange; return Container(padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 8, vertical: isMobile ? 6 : 4), decoration: BoxDecoration(color: isWeekend ? Colors.red[50] : typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(type, style: TextStyle(fontSize: isMobile ? 13 : 11, color: isWeekend ? Colors.red : typeColor, fontWeight: FontWeight.w600))); }).toList()), if (holiday.specialNote != null) ...[SizedBox(height: isMobile ? 8 : 6), Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: isWeekend ? Colors.red[50] : Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: isWeekend ? Colors.red[200]! : Colors.amber.withValues(alpha: 0.3), width: 1)), child: Row(children: [Icon(Icons.access_time, size: isMobile ? 18 : 16, color: isWeekend ? Colors.red : Colors.amber[800]), SizedBox(width: isMobile ? 8 : 6), Expanded(child: Text(holiday.specialNote!, style: TextStyle(fontSize: isMobile ? 13 : 11, color: isWeekend ? Colors.red[900] : Colors.amber[900], fontWeight: FontWeight.w500))) ]))]])),
                                                  if (isWeekend) Container(padding: EdgeInsets.all(isMobile ? 10 : 8), decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle), child: Icon(Icons.weekend, color: Colors.red, size: isMobile ? 24 : 20)),
                                                ],
                                              ),
                                            ),
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
                        ),
                        // ABA 3: CONTAS (pacote ../contas)
                        const ContasTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContasTab extends StatefulWidget {
  const ContasTab({super.key});

  @override
  State<ContasTab> createState() => _ContasTabState();
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
      child: contas_app.FinanceApp(migrationRequired: _migrationRequired),
    );
  }
}

// === FIM DO ARQUIVO ===
