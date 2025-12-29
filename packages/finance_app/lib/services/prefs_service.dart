import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'holiday_service.dart';

class PrefsService {
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<String> regionNotifier = ValueNotifier('Vale do Paraíba');
  static final ValueNotifier<String> cityNotifier = ValueNotifier('São José dos Campos');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Tema
    final isDark = prefs.getBool('isDark') ?? false;
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    // Localização
    String savedRegion = prefs.getString('region') ?? 'Vale do Paraíba';
    if (!HolidayService.regions.containsKey(savedRegion)) savedRegion = 'Vale do Paraíba';
    regionNotifier.value = savedRegion;

    String savedCity = prefs.getString('city') ?? 'São José dos Campos';
    List<String> cities = HolidayService.regions[savedRegion] ?? [];
    if (!cities.contains(savedCity)) savedCity = cities.isNotEmpty ? cities.first : 'São José dos Campos';
    cityNotifier.value = savedCity;
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
  static Future<void> saveDateRange(DateTime start, DateTime end) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('startDate', start.toIso8601String());
    await prefs.setString('endDate', end.toIso8601String());
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
}