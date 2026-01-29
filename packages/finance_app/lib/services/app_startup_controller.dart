import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum para as abas do app
enum AppTab {
  contas,
  calendario,
  feriados,
  tabelas,
  config,
}

/// Extensão para converter AppTab em índice e vice-versa
extension AppTabExtension on AppTab {
  int get index {
    switch (this) {
      case AppTab.contas:
        return 0;
      case AppTab.calendario:
        return 1;
      case AppTab.feriados:
        return 2;
      case AppTab.tabelas:
        return 3;
      case AppTab.config:
        return 4;
    }
  }

  static AppTab fromIndex(int index) {
    switch (index) {
      case 0:
        return AppTab.contas;
      case 1:
        return AppTab.calendario;
      case 2:
        return AppTab.feriados;
      case 3:
        return AppTab.tabelas;
      case 4:
        return AppTab.config;
      default:
        return AppTab.contas;
    }
  }
}

/// Estado de inicialização do app
class AppStartupState {
  /// Aba inicial a ser aberta
  final AppTab initialTab;

  /// Data âncora inicial (sempre hoje por default)
  final DateTime initialAnchorDate;

  /// Se deve forçar posicionamento no "hoje"
  final bool forceToday;

  /// Se deve usar última sessão (preferência do usuário)
  final bool useLastSession;

  const AppStartupState({
    this.initialTab = AppTab.contas,
    required this.initialAnchorDate,
    this.forceToday = true,
    this.useLastSession = false,
  });

  /// Estado padrão: Contas + hoje
  factory AppStartupState.defaultState() {
    return AppStartupState(
      initialTab: AppTab.contas,
      initialAnchorDate: DateTime.now(),
      forceToday: true,
      useLastSession: false,
    );
  }
}

/// Controller centralizado para estado de inicialização do app.
///
/// Responsabilidades:
/// - Determinar qual aba abrir no launch
/// - Garantir que a tela Contas receba "âncora" = hoje
/// - Garantir que Calendário selecione hoje se for aberto
/// - Restaurar última aba/modo se configurado
class AppStartupController {
  static const String _lastTabKey = 'last_tab_index';
  static const String _useLastSessionKey = 'use_last_session';
  static const String _lastViewModeContasKey = 'last_view_mode_contas';
  static const String _lastViewModeCalendarKey = 'last_view_mode_calendar';

  /// Notifier para a aba atual (para persistência)
  static final ValueNotifier<int> currentTabNotifier = ValueNotifier(0);

  /// Notifier para indicar que o app deve ir para "hoje"
  static final ValueNotifier<bool> jumpToTodayNotifier = ValueNotifier(false);

  /// Flag para indicar se a inicialização já foi feita
  static bool _didInit = false;

  /// Estado atual de startup
  static AppStartupState? _startupState;

  /// Obtém o estado de startup
  static AppStartupState get startupState =>
      _startupState ?? AppStartupState.defaultState();

  /// Inicializa o controller e determina o estado inicial
  static Future<AppStartupState> init() async {
    if (_didInit) return startupState;

    final prefs = await SharedPreferences.getInstance();

    // Verificar se deve usar última sessão
    final useLastSession = prefs.getBool(_useLastSessionKey) ?? false;

    AppTab initialTab = AppTab.contas; // Default SEMPRE é Contas

    if (useLastSession) {
      // Restaurar última aba se configurado
      final savedTabIndex = prefs.getInt(_lastTabKey);
      if (savedTabIndex != null &&
          savedTabIndex >= 0 &&
          savedTabIndex < AppTab.values.length) {
        initialTab = AppTabExtension.fromIndex(savedTabIndex);
      }
    }

    // Criar estado de startup
    _startupState = AppStartupState(
      initialTab: initialTab,
      initialAnchorDate: DateTime.now(),
      forceToday: true,
      useLastSession: useLastSession,
    );

    // Atualizar notifier
    currentTabNotifier.value = initialTab.index;

    _didInit = true;
    debugPrint(
        '🚀 [AppStartupController] Inicializado: tab=${initialTab.name}, useLastSession=$useLastSession');

    return _startupState!;
  }

  /// Salva a aba atual (para persistência)
  static Future<void> saveCurrentTab(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= AppTab.values.length) return;

    currentTabNotifier.value = tabIndex;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastTabKey, tabIndex);
    debugPrint(
        '💾 [AppStartupController] Aba salva: ${AppTabExtension.fromIndex(tabIndex).name}');
  }

  /// Salva preferência de usar última sessão
  static Future<void> saveUseLastSession(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useLastSessionKey, value);
  }

  /// Obtém preferência de usar última sessão
  static Future<bool> getUseLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useLastSessionKey) ?? false;
  }

  /// Salva o último modo de visualização da aba Contas
  static Future<void> saveLastViewModeContas(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastViewModeContasKey, mode);
  }

  /// Obtém o último modo de visualização da aba Contas
  static Future<String> getLastViewModeContas() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastViewModeContasKey) ?? 'month'; // Default: mensal
  }

  /// Salva o último modo de visualização do Calendário
  static Future<void> saveLastViewModeCalendar(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastViewModeCalendarKey, mode);
  }

  /// Obtém o último modo de visualização do Calendário
  static Future<String> getLastViewModeCalendar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastViewModeCalendarKey) ?? 'monthly'; // Default: mensal
  }

  /// Dispara evento para ir para "hoje" nas telas
  static void triggerJumpToToday() {
    jumpToTodayNotifier.value = true;
    // Reset após um frame
    Future.microtask(() {
      jumpToTodayNotifier.value = false;
    });
  }

  /// Reseta o estado de inicialização (útil para testes)
  static void reset() {
    _didInit = false;
    _startupState = null;
    currentTabNotifier.value = 0;
    jumpToTodayNotifier.value = false;
  }

  /// Obtém o índice da aba inicial
  static int get initialTabIndex => startupState.initialTab.index;

  /// Obtém a data âncora inicial
  static DateTime get initialAnchorDate => startupState.initialAnchorDate;
}
