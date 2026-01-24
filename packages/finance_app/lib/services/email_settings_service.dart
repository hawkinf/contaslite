import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'prefs_service.dart';

/// Modelo para configurações de email
class EmailSettings {
  final bool isEnabled;
  final String frequency; // 'daily', 'weekly', 'biweekly', 'monthly'
  final int sendHour;
  final int sendMinute;
  final int weeklyDay; // 0=Dom, 1=Seg, ..., 6=Sab
  final int monthlyDay; // 1-28
  final DateTime? lastSentAt;
  final DateTime? nextSendAt;

  EmailSettings({
    this.isEnabled = false,
    this.frequency = 'daily',
    this.sendHour = 3,
    this.sendMinute = 0,
    this.weeklyDay = 1,
    this.monthlyDay = 1,
    this.lastSentAt,
    this.nextSendAt,
  });

  factory EmailSettings.fromJson(Map<String, dynamic> json) {
    return EmailSettings(
      isEnabled: json['isEnabled'] ?? false,
      frequency: json['frequency'] ?? 'daily',
      sendHour: json['sendHour'] ?? 3,
      sendMinute: json['sendMinute'] ?? 0,
      weeklyDay: json['weeklyDay'] ?? 1,
      monthlyDay: json['monthlyDay'] ?? 1,
      lastSentAt: json['lastSentAt'] != null
          ? DateTime.tryParse(json['lastSentAt'])
          : null,
      nextSendAt: json['nextSendAt'] != null
          ? DateTime.tryParse(json['nextSendAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'frequency': frequency,
      'sendHour': sendHour,
      'sendMinute': sendMinute,
      'weeklyDay': weeklyDay,
      'monthlyDay': monthlyDay,
    };
  }

  EmailSettings copyWith({
    bool? isEnabled,
    String? frequency,
    int? sendHour,
    int? sendMinute,
    int? weeklyDay,
    int? monthlyDay,
  }) {
    return EmailSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      frequency: frequency ?? this.frequency,
      sendHour: sendHour ?? this.sendHour,
      sendMinute: sendMinute ?? this.sendMinute,
      weeklyDay: weeklyDay ?? this.weeklyDay,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      lastSentAt: lastSentAt,
      nextSendAt: nextSendAt,
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'Diário';
      case 'weekly':
        return 'Semanal';
      case 'biweekly':
        return 'Quinzenal';
      case 'monthly':
        return 'Mensal';
      default:
        return frequency;
    }
  }

  String get weeklyDayLabel {
    const days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return days[weeklyDay];
  }

  String get sendTimeLabel {
    final hour = sendHour.toString().padLeft(2, '0');
    final minute = sendMinute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Status do serviço de email
class EmailStatus {
  final bool configured;
  final bool schedulerRunning;

  EmailStatus({
    this.configured = false,
    this.schedulerRunning = false,
  });

  factory EmailStatus.fromJson(Map<String, dynamic> json) {
    return EmailStatus(
      configured: json['configured'] ?? false,
      schedulerRunning: json['schedulerRunning'] ?? false,
    );
  }
}

/// Serviço para gerenciar configurações de email
class EmailSettingsService {
  static final EmailSettingsService instance = EmailSettingsService._();

  EmailSettingsService._();

  http.Client? _httpClient;
  String? _apiBaseUrl;

  /// Notificador de configurações de email
  final ValueNotifier<EmailSettings?> settingsNotifier = ValueNotifier(null);

  /// Notificador de status do serviço
  final ValueNotifier<EmailStatus?> statusNotifier = ValueNotifier(null);

  /// Notificador de loading
  final ValueNotifier<bool> loadingNotifier = ValueNotifier(false);

  /// Inicializa o serviço
  Future<void> initialize() async {
    _httpClient = http.Client();

    final config = await PrefsService.loadDatabaseConfig();

    if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
      _apiBaseUrl = config.apiUrl;
    } else if (config.enabled && config.host.isNotEmpty) {
      _apiBaseUrl = 'http://${config.host}:3000';
    } else {
      _apiBaseUrl = 'http://192.227.184.162:3000';
    }

    debugPrint('📧 EmailSettingsService inicializado com URL: $_apiBaseUrl');
  }

  /// Obtém headers de autenticação
  Map<String, String> _getHeaders() {
    final token = AuthService.instance.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Carrega configurações de email do servidor
  Future<EmailSettings?> loadSettings() async {
    if (!AuthService.instance.isAuthenticated) {
      return null;
    }

    try {
      loadingNotifier.value = true;

      final response = await _httpClient!.get(
        Uri.parse('$_apiBaseUrl/api/email/settings'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final settings = EmailSettings.fromJson(json['data']);
          settingsNotifier.value = settings;
          return settings;
        }
      }

      debugPrint('❌ Erro ao carregar configurações de email: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ Exceção ao carregar configurações de email: $e');
      return null;
    } finally {
      loadingNotifier.value = false;
    }
  }

  /// Atualiza configurações de email no servidor
  Future<bool> updateSettings(EmailSettings settings) async {
    if (!AuthService.instance.isAuthenticated) {
      return false;
    }

    try {
      loadingNotifier.value = true;

      final response = await _httpClient!.put(
        Uri.parse('$_apiBaseUrl/api/email/settings'),
        headers: _getHeaders(),
        body: jsonEncode(settings.toJson()),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final updatedSettings = EmailSettings.fromJson(json['data']);
          settingsNotifier.value = updatedSettings;
          return true;
        }
      }

      debugPrint('❌ Erro ao atualizar configurações: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Exceção ao atualizar configurações: $e');
      return false;
    } finally {
      loadingNotifier.value = false;
    }
  }

  /// Envia email de teste
  Future<({bool success, String message})> sendTestEmail() async {
    if (!AuthService.instance.isAuthenticated) {
      return (success: false, message: 'Não autenticado');
    }

    try {
      loadingNotifier.value = true;

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/api/email/test'),
        headers: _getHeaders(),
      );

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['success'] == true) {
        return (success: true, message: (json['message'] as String?) ?? 'Email enviado com sucesso');
      }

      return (success: false, message: (json['error'] as String?) ?? 'Erro ao enviar email');
    } catch (e) {
      debugPrint('❌ Exceção ao enviar email de teste: $e');
      return (success: false, message: 'Erro de conexão: $e');
    } finally {
      loadingNotifier.value = false;
    }
  }

  /// Verifica status do serviço de email
  Future<EmailStatus?> checkStatus() async {
    if (!AuthService.instance.isAuthenticated) {
      return null;
    }

    try {
      final response = await _httpClient!.get(
        Uri.parse('$_apiBaseUrl/api/email/status'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final status = EmailStatus.fromJson(json['data']);
          statusNotifier.value = status;
          return status;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Exceção ao verificar status: $e');
      return null;
    }
  }
}
