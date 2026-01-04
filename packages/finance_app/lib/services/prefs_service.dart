import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'holiday_service.dart';

class PrefsService {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<String> regionNotifier = ValueNotifier('Vale do Paraíba');
  static final ValueNotifier<String> cityNotifier =
      ValueNotifier('São José dos Campos');
  static final ValueNotifier<DateTimeRange> dateRangeNotifier =
      ValueNotifier(_defaultDateRange());
  static final ValueNotifier<int?> tabRequestNotifier = ValueNotifier(null);
  static final ValueNotifier<int?> tabReturnNotifier = ValueNotifier(null);
  static bool _embeddedMode = false;

  // Debug
  static final bool _debugEnabled = true;

  // Database Protection Settings
  static bool autoBackupEnabled = true;
  static int integrityCheckIntervalDays = 7;
  static DateTime? lastIntegrityCheck;
  static int backupRetentionCount = 5;

  static bool get embeddedMode => _embeddedMode;

  static void setEmbeddedMode(bool value) {
    _embeddedMode = value;
  }

  static void _log(String message) {
    if (_debugEnabled) {
      debugPrint('🔧 PrefsService: $message');
    }
  }

  static DateTimeRange _defaultDateRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  static Future<void> init() async {
    _log('init() - iniciando...');
    final prefs = await SharedPreferences.getInstance();

    // Tema
    _log('init() - carregando tema...');
    final isDark = prefs.getBool('isDark') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _log('init() - tema carregado: ${isDark ? "dark" : "light"}');

    // Localização
    _log('init() - carregando localização...');
    String savedRegion = prefs.getString('region') ?? 'Vale do Paraíba';
    if (!HolidayService.regions.containsKey(savedRegion)) {
      savedRegion = 'Vale do Paraíba';
    }
    regionNotifier.value = savedRegion;

    String savedCity = prefs.getString('city') ?? 'São José dos Campos';
    List<String> cities = HolidayService.regions[savedRegion] ?? [];
    if (!cities.contains(savedCity)) {
      savedCity = cities.isNotEmpty ? cities.first : 'São José dos Campos';
    }
    cityNotifier.value = savedCity;
    _log('init() - localização carregada: $savedCity, $savedRegion');

    _log('init() - carregando intervalo de datas...');
    final range = await loadDateRange();
    dateRangeNotifier.value = DateTimeRange(start: range.start, end: range.end);
    _log('init() - intervalo de datas carregado');

    // Database Protection Settings
    _log('init() - carregando configurações de proteção de banco...');
    autoBackupEnabled = prefs.getBool('db_auto_backup_enabled') ?? true;
    integrityCheckIntervalDays = prefs.getInt('db_integrity_check_interval') ?? 7;
    backupRetentionCount = prefs.getInt('db_backup_retention_count') ?? 5;

    final lastCheckStr = prefs.getString('db_last_integrity_check');
    if (lastCheckStr != null) {
      try {
        lastIntegrityCheck = DateTime.parse(lastCheckStr);
      } catch (e) {
        lastIntegrityCheck = null;
      }
    }
    _log('init() - concluído com sucesso');
  }

  static Future<void> saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> saveLocation(String region, String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('region', region);
    await prefs.setString('city', city);
    regionNotifier.value = region;
    cityNotifier.value = city;
  }

  // --- NOVOS MÉTODOS DE DATA ---
  
  static Future<void> shiftDateRange(int offsetMonths) async {
    final current = dateRangeNotifier.value;
    final newStart = DateTime(current.start.year, current.start.month + offsetMonths, 1);
    final newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    await saveDateRange(newStart, newEnd);
  }

static Future<void> saveDateRange(DateTime start, DateTime end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('startDate', start.toIso8601String());
    await prefs.setString('endDate', end.toIso8601String());
    dateRangeNotifier.value = DateTimeRange(start: start, end: end);
  }


  static void requestTabChange(int index) {
    tabRequestNotifier.value = index;
  }

  static void setTabReturnIndex(int index) {
    tabReturnNotifier.value = index;
  }

  static Future<({DateTime start, DateTime end})> loadDateRange() async {
    final prefs = await SharedPreferences.getInstance();
    String? startStr = prefs.getString('startDate');
    String? endStr = prefs.getString('endDate');

    DateTime now = DateTime.now();
    // Default: Início e Fim do mês corrente
    DateTime start = DateTime(now.year, now.month, 1);
    DateTime end = DateTime(now.year, now.month + 1, 0); // Último dia do mês

    if (startStr != null) start = DateTime.parse(startStr);
    if (endStr != null) end = DateTime.parse(endStr);

    return (start: start, end: end);
  }

  // --- DATABASE PROTECTION SETTINGS ---

  static Future<void> saveAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('db_auto_backup_enabled', enabled);
    autoBackupEnabled = enabled;
  }

  static Future<void> saveIntegrityCheckInterval(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('db_integrity_check_interval', days);
    integrityCheckIntervalDays = days;
  }

  static Future<void> saveBackupRetentionCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('db_backup_retention_count', count);
    backupRetentionCount = count;
  }

  static Future<void> saveLastIntegrityCheck(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_last_integrity_check', dateTime.toIso8601String());
    lastIntegrityCheck = dateTime;
  }

  static bool shouldPerformIntegrityCheck() {
    if (lastIntegrityCheck == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastIntegrityCheck!).inDays;

    return difference >= integrityCheckIntervalDays;
  }
}
