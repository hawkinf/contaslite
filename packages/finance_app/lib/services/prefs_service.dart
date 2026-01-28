import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'holiday_service.dart';
import '../models/contas_view_state_snapshot.dart';
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
  static final ValueNotifier<bool> compactModeNotifier = ValueNotifier(false);

  /// Provider para capturar o estado atual da dashboard (Contas)
  /// O dashboard registra sua função de snapshot aqui
  static ContasViewStateSnapshot? Function()? dashboardExportStateProvider;

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
    final prefs = await _safePrefs();

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

    // SEMPRE iniciar com o mês atual no startup (ignora data salva)
    dateRangeNotifier.value = _defaultDateRange();

    // Modo compacto da dashboard
    compactModeNotifier.value = prefs.getBool('dashboard_compact_mode') ?? false;

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
    final prefs = await _safePrefs();
    await prefs.setBool('isDark', isDark);
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> saveCompactMode(bool compact) async {
    final prefs = await _safePrefs();
    await prefs.setBool('dashboard_compact_mode', compact);
    compactModeNotifier.value = compact;
  }

  static Future<void> saveLocation(String region, String city) async {
    final prefs = await _safePrefs();
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
  final prefs = await _safePrefs();
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
    final prefs = await _safePrefs();
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
    final prefs = await _safePrefs();
    await prefs.setBool('db_auto_backup_enabled', enabled);
    autoBackupEnabled = enabled;
  }

  static Future<void> saveAskBackupOnStartup(bool ask) async {
    final prefs = await _safePrefs();
    await prefs.setBool('db_ask_backup_on_startup', ask);
    askBackupOnStartup = ask;
  }

  static Future<void> saveIntegrityCheckInterval(int days) async {
    final prefs = await _safePrefs();
    await prefs.setInt('db_integrity_check_interval', days);
    integrityCheckIntervalDays = days;
  }

  static Future<void> saveBackupRetentionCount(int count) async {
    final prefs = await _safePrefs();
    await prefs.setInt('db_backup_retention_count', count);
    backupRetentionCount = count;
  }

  static Future<void> saveLastIntegrityCheck(DateTime dateTime) async {
    final prefs = await _safePrefs();
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
    final prefs = await _safePrefs();
    final configJson = prefs.getString('db_config');
    String redactConfig(String? raw) {
      if (raw == null) return 'null';
      return raw.replaceAll(RegExp(r'password:[^|]*'), 'password:***');
    }
    debugPrint('🔧 [PrefsService] Carregando config, raw: ${redactConfig(configJson)}');

    if (configJson == null) {
      debugPrint('🔧 [PrefsService] Nenhuma config encontrada, retornando padrão');
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
      // Decodificar formato key:value|key:value
      final Map<String, dynamic> configMap = {};
      final pairs = Uri.decodeComponent(configJson).split('|');
        final redactedPairs = pairs
          .map((pair) => pair.startsWith('password:') ? 'password:***' : pair)
          .toList();
        debugPrint('🔧 [PrefsService] Pares encontrados: $redactedPairs');
      
      for (final pair in pairs) {
        // Usar indexOf para encontrar o primeiro ':' e dividir ali
        final colonIndex = pair.indexOf(':');
        if (colonIndex > 0) {
          final key = pair.substring(0, colonIndex);
          final value = pair.substring(colonIndex + 1);
          
          // Converter valores
          if (key == 'port') {
            configMap[key] = int.tryParse(value) ?? 5432;
          } else if (key == 'enabled') {
            configMap[key] = value == 'true';
          } else if (value == 'null') {
            configMap[key] = null;
          } else {
            configMap[key] = value;
          }
        }
      }

      final redactedMap = Map<String, dynamic>.from(configMap);
      if (redactedMap.containsKey('password')) {
        redactedMap['password'] = '***';
      }
      debugPrint('🔧 [PrefsService] ConfigMap decodificado: $redactedMap');
      final config = DatabaseConfig.fromJson(configMap);
      debugPrint('🔧 [PrefsService] Config final: apiUrl=${config.apiUrl}');
      return config;
    } catch (e) {
      debugPrint('Erro ao carregar config do banco: $e');
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
    final prefs = await _safePrefs();
    // Salvar como JSON para incluir apiUrl
    final configMap = config.toJson();
    debugPrint('🔧 [PrefsService] Salvando config: $configMap');
    final configString = configMap.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
    debugPrint('🔧 [PrefsService] String serializada: $configString');
    await prefs.setString('db_config', configString);
    debugPrint('🔧 [PrefsService] Config salva com sucesso');
  }

  static Future<void> clearDatabaseConfig() async {
    final prefs = await _safePrefs();
    await prefs.remove('db_config');
  }

  // Obtém SharedPreferences com recuperação automática em caso de corrupção
  static Future<SharedPreferences> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on FormatException catch (e) {
      debugPrint('🔧 SharedPreferences corrompido, limpando arquivo: $e');
      await _clearCorruptedPrefsFile();
      return await SharedPreferences.getInstance();
    }
  }

  static Future<void> _clearCorruptedPrefsFile() async {
    if (kIsWeb) return; // Web não usa arquivo local
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    try {
      final supportDir = await getApplicationSupportDirectory();
      final prefsFile = File('${supportDir.path}/shared_preferences.json');
      if (await prefsFile.exists()) {
        await prefsFile.delete();
        debugPrint('🔧 shared_preferences.json removido para recriação');
      }
    } catch (e) {
      debugPrint('🔧 Falha ao limpar shared_preferences.json: $e');
    }
  }
}
