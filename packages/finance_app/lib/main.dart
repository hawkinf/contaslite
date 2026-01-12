import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/prefs_service.dart';
import 'services/database_initialization_service.dart';
import 'services/auth_service.dart';
import 'screens/home_screen.dart';
import 'screens/database_migration_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Iniciando app...');

  // Capture global errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 FlutterError: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };

  try {
    // Inicialização do banco de dados para desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('📱 Configurando banco de dados para desktop...');
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('✓ Banco de dados configurado');
    }

    // Inicialização dos serviços
    debugPrint('⚙️  Inicializando PrefsService...');
    await PrefsService.init();
    debugPrint('✓ PrefsService inicializado');

    debugPrint('🌍 Inicializando formatação de data...');
    await initializeDateFormatting('pt_BR', null);
    debugPrint('✓ Formatação de data inicializada');

    // Inicializar banco de dados com categorias padrão se vazio
    bool migrationRequired = false;
    try {
      debugPrint('💾 Inicializando banco de dados...');
      await DatabaseInitializationService.instance.initializeDatabase();
      debugPrint('✓ Banco de dados inicializado');
    } catch (e) {
      debugPrint('❌ Erro ao inicializar banco de dados: $e');
      debugPrintStack(stackTrace: StackTrace.current);
      migrationRequired = true;
    }

    // Inicializar serviço de autenticação
    debugPrint('🔐 Inicializando AuthService...');
    await AuthService.instance.initialize();
    final isAuthenticated = AuthService.instance.isAuthenticated;
    debugPrint('✓ AuthService inicializado (autenticado: $isAuthenticated)');

    debugPrint('📲 Executando app...');
    runApp(FinanceApp(
      migrationRequired: migrationRequired,
      showLogin: !isAuthenticated,
    ));
  } catch (e, st) {
    debugPrint('🔴 ERRO FATAL NA INICIALIZAÇÃO: $e');
    debugPrintStack(stackTrace: st);
    rethrow;
  }
}

class FinanceApp extends StatefulWidget {
  final bool migrationRequired;
  final int initialTabIndex;
  final bool showLogin;

  const FinanceApp({
    super.key,
    this.migrationRequired = false,
    this.initialTabIndex = 0,
    this.showLogin = false,
  });

  @override
  State<FinanceApp> createState() => _FinanceAppState();
}

class _FinanceAppState extends State<FinanceApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    debugPrint('🎨 FinanceApp: initState iniciado');
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🎨 FinanceApp: Observer adicionado');
  }

  @override
  void dispose() {
    debugPrint('🎨 FinanceApp: dispose iniciado');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📊 AppLifecycleState: $state');
    if (state == AppLifecycleState.detached) {
      // App está sendo encerrado
      debugPrint('🔌 App encerrado');
      // Backup automático desabilitado por enquanto - causa travamento em algumas situações
      // BackupService.instance.createBackup();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 FinanceApp: build chamado');
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PrefsService.themeNotifier,
      builder: (context, themeMode, _) {
        debugPrint('🎨 FinanceApp: ValueListenableBuilder builder chamado, themeMode=$themeMode');
        return MaterialApp(
          title: 'Contas a Pagar',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,

          // Configuração de Localizações para DatePicker
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

          // TEMA CLARO
          theme: _buildLightTheme(),

          // TEMA ESCURO
          darkTheme: _buildDarkTheme(),

          home: ValueListenableBuilder<AuthState>(
            valueListenable: AuthService.instance.authStateNotifier,
            builder: (context, authState, _) {
              if (widget.migrationRequired) {
                return const DatabaseMigrationScreen();
              }
              
              // Mostrar login se não autenticado ou em estado de erro
              if (authState == AuthState.unauthenticated || authState == AuthState.error) {
                return const LoginScreen();
              }
              
              // Se ainda está verificando, mostrar tela de carregamento
              if (authState == AuthState.checking) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              // Autenticado com sucesso
              return HomeScreen(initialTabIndex: widget.initialTabIndex);
            },
          ),
        );
      },
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      textTheme: GoogleFonts.robotoTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shadowColor: Colors.white.withValues(alpha: 0.15),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }
}
