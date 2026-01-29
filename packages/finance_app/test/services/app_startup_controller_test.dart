import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_app/services/app_startup_controller.dart';

void main() {
  group('AppTab enum', () {
    test('has correct index values', () {
      expect(AppTab.contas.index, 0);
      expect(AppTab.calendario.index, 1);
      expect(AppTab.feriados.index, 2);
      expect(AppTab.tabelas.index, 3);
      expect(AppTab.config.index, 4);
    });

    test('fromIndex returns correct tab', () {
      expect(AppTabExtension.fromIndex(0), AppTab.contas);
      expect(AppTabExtension.fromIndex(1), AppTab.calendario);
      expect(AppTabExtension.fromIndex(2), AppTab.feriados);
      expect(AppTabExtension.fromIndex(3), AppTab.tabelas);
      expect(AppTabExtension.fromIndex(4), AppTab.config);
    });

    test('fromIndex returns contas for invalid index', () {
      expect(AppTabExtension.fromIndex(-1), AppTab.contas);
      expect(AppTabExtension.fromIndex(5), AppTab.contas);
      expect(AppTabExtension.fromIndex(100), AppTab.contas);
    });
  });

  group('AppStartupState', () {
    test('defaultState creates state with contas tab', () {
      final state = AppStartupState.defaultState();
      expect(state.initialTab, AppTab.contas);
      expect(state.forceToday, true);
      expect(state.useLastSession, false);
    });

    test('defaultState uses current date as anchor', () {
      final state = AppStartupState.defaultState();
      final now = DateTime.now();
      expect(state.initialAnchorDate.year, now.year);
      expect(state.initialAnchorDate.month, now.month);
      expect(state.initialAnchorDate.day, now.day);
    });

    test('constructor accepts custom values', () {
      final customDate = DateTime(2025, 6, 15);
      final state = AppStartupState(
        initialTab: AppTab.calendario,
        initialAnchorDate: customDate,
        forceToday: false,
        useLastSession: true,
      );
      expect(state.initialTab, AppTab.calendario);
      expect(state.initialAnchorDate, customDate);
      expect(state.forceToday, false);
      expect(state.useLastSession, true);
    });
  });

  group('AppStartupController', () {
    setUp(() {
      // Reset controller state before each test
      AppStartupController.reset();
      // Setup mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('init returns default state when no preferences saved', () async {
      final state = await AppStartupController.init();
      expect(state.initialTab, AppTab.contas);
      expect(state.useLastSession, false);
    });

    test('init returns contas even when useLastSession is false', () async {
      SharedPreferences.setMockInitialValues({
        'last_tab_index': 2, // feriados
        'use_last_session': false,
      });
      final state = await AppStartupController.init();
      expect(state.initialTab, AppTab.contas);
    });

    test('init restores last tab when useLastSession is true', () async {
      SharedPreferences.setMockInitialValues({
        'last_tab_index': 2, // feriados
        'use_last_session': true,
      });
      final state = await AppStartupController.init();
      expect(state.initialTab, AppTab.feriados);
    });

    test('init ignores invalid tab index', () async {
      SharedPreferences.setMockInitialValues({
        'last_tab_index': 99, // invalid
        'use_last_session': true,
      });
      final state = await AppStartupController.init();
      expect(state.initialTab, AppTab.contas);
    });

    test('saveCurrentTab updates notifier and persists', () async {
      await AppStartupController.init();
      await AppStartupController.saveCurrentTab(3);

      expect(AppStartupController.currentTabNotifier.value, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('last_tab_index'), 3);
    });

    test('saveCurrentTab ignores invalid index', () async {
      await AppStartupController.init();
      await AppStartupController.saveCurrentTab(0);
      await AppStartupController.saveCurrentTab(-1);

      expect(AppStartupController.currentTabNotifier.value, 0);
    });

    test('saveUseLastSession persists preference', () async {
      await AppStartupController.saveUseLastSession(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_last_session'), true);
    });

    test('getUseLastSession returns saved preference', () async {
      SharedPreferences.setMockInitialValues({
        'use_last_session': true,
      });

      final result = await AppStartupController.getUseLastSession();
      expect(result, true);
    });

    test('getUseLastSession returns false when not set', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await AppStartupController.getUseLastSession();
      expect(result, false);
    });

    test('triggerJumpToToday sets and resets notifier', () async {
      await AppStartupController.init();

      bool wasTriggered = false;
      AppStartupController.jumpToTodayNotifier.addListener(() {
        if (AppStartupController.jumpToTodayNotifier.value) {
          wasTriggered = true;
        }
      });

      AppStartupController.triggerJumpToToday();
      expect(wasTriggered, true);

      // Wait for microtask to reset
      await Future.microtask(() {});
      expect(AppStartupController.jumpToTodayNotifier.value, false);
    });

    test('reset clears all state', () async {
      await AppStartupController.init();
      await AppStartupController.saveCurrentTab(2);

      AppStartupController.reset();

      expect(AppStartupController.currentTabNotifier.value, 0);
      expect(AppStartupController.jumpToTodayNotifier.value, false);
    });

    test('initialTabIndex returns correct value', () async {
      SharedPreferences.setMockInitialValues({
        'last_tab_index': 1,
        'use_last_session': true,
      });
      await AppStartupController.init();

      expect(AppStartupController.initialTabIndex, 1);
    });

    test('initialAnchorDate returns today', () async {
      await AppStartupController.init();

      final now = DateTime.now();
      final anchor = AppStartupController.initialAnchorDate;
      expect(anchor.year, now.year);
      expect(anchor.month, now.month);
      expect(anchor.day, now.day);
    });

    test('saveLastViewModeContas persists mode', () async {
      await AppStartupController.saveLastViewModeContas('week');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_view_mode_contas'), 'week');
    });

    test('getLastViewModeContas returns saved mode', () async {
      SharedPreferences.setMockInitialValues({
        'last_view_mode_contas': 'week',
      });

      final result = await AppStartupController.getLastViewModeContas();
      expect(result, 'week');
    });

    test('getLastViewModeContas returns month when not set', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await AppStartupController.getLastViewModeContas();
      expect(result, 'month');
    });

    test('saveLastViewModeCalendar persists mode', () async {
      await AppStartupController.saveLastViewModeCalendar('weekly');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_view_mode_calendar'), 'weekly');
    });

    test('getLastViewModeCalendar returns saved mode', () async {
      SharedPreferences.setMockInitialValues({
        'last_view_mode_calendar': 'yearly',
      });

      final result = await AppStartupController.getLastViewModeCalendar();
      expect(result, 'yearly');
    });

    test('getLastViewModeCalendar returns monthly when not set', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await AppStartupController.getLastViewModeCalendar();
      expect(result, 'monthly');
    });
  });
}
