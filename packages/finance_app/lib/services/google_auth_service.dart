import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/google_auth_config.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'secure_credential_storage.dart';
import 'prefs_service.dart';
import 'sync_service.dart';

// Importar google_sign_in apenas se não for Windows
import 'package:google_sign_in/google_sign_in.dart'
    if (dart.library.io) 'package:google_sign_in/google_sign_in.dart';

/// Serviço para autenticação com Google
/// Suporta Android, iOS, Web e Windows (via OAuth browser flow)
class GoogleAuthService {
  static final GoogleAuthService instance = GoogleAuthService._();

  GoogleAuthService._();

  /// Instância do GoogleSignIn (para mobile/web)
  GoogleSignIn? _googleSignIn;

  bool _isInitialized = false;

  /// Servidor HTTP local para callback OAuth (Windows)
  HttpServer? _localServer;

  /// Notificador para status de carregamento do Google Sign-In
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(false);

  /// Notificador para erros do Google Sign-In
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  /// Verifica se está rodando em Windows
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  /// Verifica se está rodando em plataforma que suporta google_sign_in nativo
  bool get _supportsNativeGoogleSignIn => !_isWindows;

  /// Inicializa o serviço Google Sign-In
  Future<void> initialize({String? webClientId}) async {
    if (_isInitialized) return;

    try {
      final clientId = webClientId ??
          (GoogleAuthConfig.isConfigured ? GoogleAuthConfig.webClientId : null);

      if (clientId == null ||
          !clientId.contains('.apps.googleusercontent.com')) {
        debugPrint('⚠️ Google Client ID não configurado!');
        debugPrint('   Configure em: lib/config/google_auth_config.dart');
      }

      // Só inicializa GoogleSignIn se a plataforma suportar
      if (_supportsNativeGoogleSignIn) {
        _googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
          clientId: clientId,
          serverClientId: clientId,
        );
        debugPrint('✅ GoogleAuthService inicializado (nativo)');
      } else {
        debugPrint('✅ GoogleAuthService inicializado (OAuth browser flow)');
      }

      debugPrint(
          '   Client ID: ${clientId != null ? '${clientId.substring(0, 20)}...' : 'não configurado'}');
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Erro ao inicializar GoogleAuthService: $e');
      rethrow;
    }
  }

  /// Realiza login com Google
  Future<AuthResult> signInWithGoogle() async {
    if (!_isInitialized) {
      await initialize();
    }

    isLoadingNotifier.value = true;
    errorNotifier.value = null;

    try {
      if (_isWindows) {
        return await _signInWithBrowser();
      } else {
        return await _signInWithNative();
      }
    } catch (e) {
      debugPrint('❌ Erro no Google Sign-In: $e');
      isLoadingNotifier.value = false;
      errorNotifier.value = 'Erro ao fazer login com Google: $e';
      return AuthResult.failed(
        'Erro ao fazer login com Google: $e',
        errorCode: 'GOOGLE_ERROR',
      );
    }
  }

  /// Login nativo (Android, iOS, Web)
  Future<AuthResult> _signInWithNative() async {
    debugPrint('🔐 Iniciando Google Sign-In nativo...');

    if (_googleSignIn == null) {
      return AuthResult.failed(
        'Google Sign-In não inicializado',
        errorCode: 'NOT_INITIALIZED',
      );
    }

    try {
      await _googleSignIn!.signOut();
      final googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        debugPrint('⚠️ Usuário cancelou o login do Google');
        isLoadingNotifier.value = false;
        return AuthResult.failed('Login cancelado', errorCode: 'CANCELLED');
      }

      debugPrint('✅ Google Sign-In bem-sucedido: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        isLoadingNotifier.value = false;
        return AuthResult.failed(
          'Não foi possível obter o token de autenticação',
          errorCode: 'NO_TOKEN',
        );
      }

      final result = await _authenticateWithBackend(
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
        email: googleUser.email,
        name: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
      );

      isLoadingNotifier.value = false;
      return result;
    } catch (e) {
      isLoadingNotifier.value = false;
      rethrow;
    }
  }

  /// Login via navegador (Windows)
  Future<AuthResult> _signInWithBrowser() async {
    debugPrint('🔐 Iniciando Google Sign-In via navegador...');

    final clientId = GoogleAuthConfig.webClientId;
    const redirectPort = 8085;
    final redirectUri = 'http://localhost:$redirectPort/callback';

    // Gerar state para segurança
    final state = _generateRandomString(32);

    // Construir URL de autorização
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'email profile openid',
      'state': state,
      'access_type': 'offline',
      'prompt': 'select_account',
    });

    try {
      // Iniciar servidor local para receber o callback
      _localServer = await HttpServer.bind(InternetAddress.loopbackIPv4, redirectPort);
      debugPrint('🌐 Servidor local iniciado em $redirectUri');

      // Abrir navegador usando url_launcher
      debugPrint('🌐 Abrindo navegador: $authUrl');

      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _closeLocalServer();
        isLoadingNotifier.value = false;
        return AuthResult.failed(
          'Não foi possível abrir o navegador',
          errorCode: 'BROWSER_ERROR',
        );
      }

      // Aguardar callback com timeout
      final completer = Completer<AuthResult>();

      // Timeout de 5 minutos
      final timeout = Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          completer.complete(AuthResult.failed(
            'Tempo limite excedido. Tente novamente.',
            errorCode: 'TIMEOUT',
          ));
        }
        _closeLocalServer();
      });

      _localServer!.listen((request) async {
        if (request.uri.path == '/callback') {
          final code = request.uri.queryParameters['code'];
          final returnedState = request.uri.queryParameters['state'];
          final error = request.uri.queryParameters['error'];

          // Responder ao navegador
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write(_getCallbackHtml(error == null && code != null));
          await request.response.close();

          if (error != null) {
            timeout.cancel();
            if (!completer.isCompleted) {
              completer.complete(AuthResult.failed(
                'Login cancelado ou erro: $error',
                errorCode: 'OAUTH_ERROR',
              ));
            }
            _closeLocalServer();
            return;
          }

          if (returnedState != state) {
            timeout.cancel();
            if (!completer.isCompleted) {
              completer.complete(AuthResult.failed(
                'Erro de segurança: state inválido',
                errorCode: 'INVALID_STATE',
              ));
            }
            _closeLocalServer();
            return;
          }

          if (code != null) {
            timeout.cancel();
            // Trocar código por tokens
            final result = await _exchangeCodeForTokens(code, redirectUri);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
            _closeLocalServer();
          }
        }
      });

      final result = await completer.future;
      isLoadingNotifier.value = false;
      return result;
    } catch (e) {
      _closeLocalServer();
      isLoadingNotifier.value = false;
      return AuthResult.failed(
        'Erro ao iniciar login: $e',
        errorCode: 'BROWSER_ERROR',
      );
    }
  }

  /// Troca o código de autorização por tokens
  Future<AuthResult> _exchangeCodeForTokens(
      String code, String redirectUri) async {
    try {
      debugPrint('🔐 Trocando código por tokens...');

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': GoogleAuthConfig.webClientId,
          'client_secret': GoogleAuthConfig.webClientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Erro ao trocar código: ${response.body}');
        return AuthResult.failed(
          'Erro ao obter tokens do Google',
          errorCode: 'TOKEN_EXCHANGE_ERROR',
        );
      }

      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;

      if (idToken == null) {
        return AuthResult.failed(
          'Token de ID não recebido',
          errorCode: 'NO_ID_TOKEN',
        );
      }

      // Obter informações do usuário
      final userInfo = await _getUserInfo(accessToken!);

      // Autenticar com backend
      return await _authenticateWithBackend(
        idToken: idToken,
        accessToken: accessToken,
        email: userInfo['email'] as String,
        name: userInfo['name'] as String?,
        photoUrl: userInfo['picture'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Erro ao trocar código: $e');
      return AuthResult.failed(
        'Erro ao processar autenticação: $e',
        errorCode: 'TOKEN_ERROR',
      );
    }
  }

  /// Obtém informações do usuário do Google
  Future<Map<String, dynamic>> _getUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    return {};
  }

  /// Fecha o servidor local
  void _closeLocalServer() {
    _localServer?.close(force: true);
    _localServer = null;
    debugPrint('🌐 Servidor local fechado');
  }

  /// Gera string aleatória para state
  String _generateRandomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// HTML para página de callback
  String _getCallbackHtml(bool success) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>ContasLite - Login</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    .container {
      background: white;
      padding: 40px;
      border-radius: 16px;
      text-align: center;
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
    }
    .icon { font-size: 64px; margin-bottom: 20px; }
    h1 { color: #333; margin: 0 0 10px 0; }
    p { color: #666; }
  </style>
</head>
<body>
  <div class="container">
    <div class="icon">${success ? '✅' : '❌'}</div>
    <h1>${success ? 'Login realizado!' : 'Erro no login'}</h1>
    <p>${success ? 'Você pode fechar esta janela e voltar ao aplicativo.' : 'Tente novamente no aplicativo.'}</p>
  </div>
  <script>setTimeout(() => window.close(), 3000);</script>
</body>
</html>
''';
  }

  /// Autentica com o backend usando o token do Google
  Future<AuthResult> _authenticateWithBackend({
    required String idToken,
    String? accessToken,
    required String email,
    String? name,
    String? photoUrl,
  }) async {
    try {
      final config = await PrefsService.loadDatabaseConfig();
      String apiBaseUrl;

      if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
        apiBaseUrl = config.apiUrl!;
      } else if (config.enabled && config.host.isNotEmpty) {
        apiBaseUrl = 'http://${config.host}:3000';
      } else {
        apiBaseUrl = 'http://192.227.184.162:3000';
      }

      // Normalizar URL: preferir HTTPS se não for localhost
      apiBaseUrl = _normalizeApiUrl(apiBaseUrl);

      final endpoint = '$apiBaseUrl/api/auth/google';
      debugPrint('🔐 Enviando token Google para: $endpoint');

      // Usar cliente que segue redirects
      final client = http.Client();
      try {
        final request = http.Request('POST', Uri.parse(endpoint));
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({
          'idToken': idToken,
          'accessToken': accessToken,
          'email': email,
          'name': name,
          'photoUrl': photoUrl,
        });
        request.followRedirects = true;
        request.maxRedirects = 5;

        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        debugPrint('🔐 Resposta do backend: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          await _handleAuthSuccess(data, apiBaseUrl);
          return AuthResult.successful();
        } else if (response.statusCode == 401) {
          return AuthResult.failed(
            'Token do Google inválido',
            errorCode: 'INVALID_GOOGLE_TOKEN',
          );
        } else {
          final error = _parseError(response.body);
          return AuthResult.failed(error, errorCode: 'SERVER_ERROR');
        }
      } finally {
        client.close();
      }
    } on TimeoutException {
      return AuthResult.failed(
        'Servidor não respondeu. Verifique sua conexão.',
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ Erro ao autenticar com backend: $e');
      return AuthResult.failed(
        'Erro de conexão: $e',
        errorCode: 'CONNECTION_ERROR',
      );
    }
  }

  /// Processa resposta de sucesso da autenticação
  Future<void> _handleAuthSuccess(
      Map<String, dynamic> data, String apiBaseUrl) async {
    try {
      debugPrint('🔍 [GoogleAuthService] Resposta do servidor: $data');

      final tokens = AuthTokens.fromJson(data);
      debugPrint(
          '🔍 [GoogleAuthService] Tokens extraídos - Expira em: ${tokens.expiresAt}');

      final userData = data['user'] as Map<String, dynamic>?;
      final User user;

      if (userData != null) {
        user = User.fromJson(userData);
      } else if (data.containsKey('email')) {
        final dynamic rawId = data['id'];
        user = User(
          id: rawId?.toString(),
          email: data['email'] as String,
          name: data['name'] as String?,
        );
      } else {
        throw Exception('Dados de usuário não encontrados na resposta');
      }

      debugPrint(
          '🔍 [GoogleAuthService] Usuário extraído: ${user.email} (ID: ${user.id})');

      await SecureCredentialStorage.saveTokens(tokens);
      await SecureCredentialStorage.saveUser(user);
      debugPrint('✅ Credenciais salvas com sucesso');

      // Configurar tokens internos no AuthService para persistência de sessão
      AuthService.instance.setTokens(tokens);
      AuthService.instance.setApiUrl(apiBaseUrl);
      AuthService.instance.currentUserNotifier.value = user;
      AuthService.instance.authStateNotifier.value = AuthState.authenticated;
      AuthService.instance.errorNotifier.value = null;

      debugPrint('🔄 Inicializando SyncService...');
      await SyncService.instance.initialize();
      SyncService.instance.startBackgroundSync();
      debugPrint('🔄 SyncService inicializado e background sync iniciado');

      debugPrint('✅ Autenticação Google bem sucedida: ${user.email}');
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao processar resposta de auth Google: $e');
      debugPrint('Stack trace: $stackTrace');
      AuthService.instance.authStateNotifier.value = AuthState.error;
      AuthService.instance.errorNotifier.value =
          'Erro ao processar resposta do servidor';
      rethrow;
    }
  }

  String _parseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['message'] as String? ??
          data['error'] as String? ??
          'Erro desconhecido';
    } catch (e) {
      return 'Erro desconhecido';
    }
  }

  /// Normaliza a URL da API, preferindo HTTPS para URLs não-localhost
  String _normalizeApiUrl(String url) {
    // Remover trailing slash
    url = url.endsWith('/') ? url.substring(0, url.length - 1) : url;

    // Se não tem protocolo, adicionar https para produção
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Para URLs de produção (não localhost), preferir HTTPS
    final uri = Uri.parse(url);
    final isLocalhost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host.startsWith('192.168.') ||
        uri.host.startsWith('10.');

    if (!isLocalhost && uri.scheme == 'http') {
      // Tentar HTTPS para URLs de produção
      debugPrint('⚠️ Convertendo HTTP para HTTPS: $url');
      url = url.replaceFirst('http://', 'https://');
    }

    return url;
  }

  /// Faz logout do Google
  Future<void> signOut() async {
    if (!_isInitialized) return;

    try {
      if (_supportsNativeGoogleSignIn && _googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      debugPrint('✅ Google Sign-Out realizado');
    } catch (e) {
      debugPrint('⚠️ Erro no Google Sign-Out: $e');
    }
  }

  /// Desconecta completamente a conta Google
  Future<void> disconnect() async {
    if (!_isInitialized) return;

    try {
      if (_supportsNativeGoogleSignIn && _googleSignIn != null) {
        await _googleSignIn!.disconnect();
      }
      debugPrint('✅ Google Disconnect realizado');
    } catch (e) {
      debugPrint('⚠️ Erro no Google Disconnect: $e');
    }
  }

  bool get isSignedIn =>
      _isInitialized &&
      _supportsNativeGoogleSignIn &&
      _googleSignIn?.currentUser != null;

  GoogleSignInAccount? get currentUser =>
      (_isInitialized && _supportsNativeGoogleSignIn)
          ? _googleSignIn?.currentUser
          : null;

  void dispose() {
    _closeLocalServer();
    isLoadingNotifier.dispose();
    errorNotifier.dispose();
  }
}
