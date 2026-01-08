import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'holiday_service.dart';
import '../models/database_config.dart';

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

  // Database Protection Settings
  static bool autoBackupEnabled = true;
  static bool askBackupOnStartup = false;
  static int integrityCheckIntervalDays = 7;
  static DateTime? lastIntegrityCheck;
  static int backupRetentionCount = 5;

  static bool get embeddedMode => _embeddedMode;

  static void setEmbeddedMode(bool value) {
    _embeddedMode = value;
  }

  static DateTimeRange _defaultDateRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return DateTimeRange(start: start, end: end);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Tema
    final isDark = prefs.getBool('isDark') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    // Localização
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

    final range = await loadDateRange();
    dateRangeNotifier.value = DateTimeRange(start: range.start, end: range.end);

    // Database Protection Settings
    autoBackupEnabled = prefs.getBool('db_auto_backup_enabled') ?? true;
    askBackupOnStartup = prefs.getBool('db_ask_backup_on_startup') ?? false;
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

  static Future<void> saveAskBackupOnStartup(bool ask) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('db_ask_backup_on_startup', ask);
    askBackupOnStartup = ask;
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

  // PostgreSQL Database Configuration
  static Future<DatabaseConfig> loadDatabaseConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('db_config');

    if (configJson == null) {
      // Retornar configuração padrão vazia
      return DatabaseConfig(
        host: '',
        port: 5432,
        database: '',
        username: '',
        password: '',
        enabled: false,
      );
    }

    try {
      // Decodificar JSON
      final List<dynamic> decoded = Uri.decodeComponent(configJson)
          .split('|')
          .asMap()
          .entries
          .map((e) => e.value)
          .toList();

      return DatabaseConfig.fromJson({
        'host': decoded[0],
        'port': int.tryParse(decoded[1] ?? '5432') ?? 5432,
        'database': decoded[2],
        'username': decoded[3],
        'password': decoded[4],
        'enabled': decoded.length > 5 ? decoded[5] == 'true' : false,
      });
    } catch (e) {
      // Se houver erro ao decodificar, retornar configuração vazia
      return DatabaseConfig(
        host: '',
        port: 5432,
        database: '',
        username: '',
        password: '',
        enabled: false,
      );
    }
  }

  static Future<void> saveDatabaseConfig(DatabaseConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    // Usar formato simples para compatibilidade
    final configString =
        '${config.host}|${config.port}|${config.database}|${config.username}|${config.password}|${config.enabled}';
    await prefs.setString('db_config', configString);
  }

  static Future<void> clearDatabaseConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('db_config');
  }
}
