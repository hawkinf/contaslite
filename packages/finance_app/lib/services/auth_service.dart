import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_tokens.dart';
import '../models/user.dart';
import 'secure_credential_storage.dart';
import 'prefs_service.dart';
import '../database/sync_helpers.dart';
import 'sync_service.dart';

/// Estados de autenticação
enum AuthState {
  /// Não autenticado
  unauthenticated,

  /// Verificando sessão salva
  checking,

  /// Autenticando (login/registro em progresso)
  authenticating,

  /// Autenticado com sucesso
  authenticated,

  /// Erro de autenticação
  error,
}

/// Serviço de autenticação para gerenciamento de usuários
class AuthService {
  static final AuthService instance = AuthService._();

  AuthService._();

  /// Notificador do usuário atual
  final ValueNotifier<User?> currentUserNotifier = ValueNotifier(null);

  /// Notificador do estado de autenticação
  final ValueNotifier<AuthState> authStateNotifier =
      ValueNotifier(AuthState.unauthenticated);

  /// Notificador de erro (para exibir mensagens na UI)
  final ValueNotifier<String?> errorNotifier = ValueNotifier(null);

  AuthTokens? _tokens;
  Timer? _refreshTimer;
  http.Client? _httpClient;

  /// Verifica se está autenticado
  bool get isAuthenticated =>
      _tokens != null && !_tokens!.isExpired && currentUserNotifier.value != null;

  /// Obtém o token de acesso atual
  String? get accessToken => _tokens?.accessToken;

  /// Obtém o usuário atual
  User? get currentUser => currentUserNotifier.value;

  /// URL base da API (carregada das configurações)
  String? _apiBaseUrl;

  /// Inicializa o serviço e restaura sessão se existir
  Future<void> initialize() async {
    authStateNotifier.value = AuthState.checking;
    _httpClient = http.Client();

    try {
      // Carregar URL da API das configurações
      final config = await PrefsService.loadDatabaseConfig();
      
      // Priorizar apiUrl se estiver configurada
      if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
        _apiBaseUrl = config.apiUrl;
      } else if (config.enabled && config.host.isNotEmpty) {
        _apiBaseUrl = 'http://${config.host}:3000';
      } else {
        // URL padrão se nada estiver configurado
        _apiBaseUrl = 'http://contaslite.hawk.com.br:3000';
        debugPrint('⚠️  Nenhuma URL configurada, usando padrão: $_apiBaseUrl');
      }

      debugPrint('🔧 AuthService inicializado com URL: $_apiBaseUrl');

      // Tentar restaurar sessão
      await restoreSession();
    } catch (e) {
      debugPrint('❌ Erro ao inicializar AuthService: $e');
      authStateNotifier.value = AuthState.unauthenticated;
    }
  }

  /// Configura a URL da API manualmente
  void setApiUrl(String url) {
    _apiBaseUrl = url;
  }

  /// Restaura sessão salva anteriormente
  Future<void> restoreSession() async {
    try {
      final tokens = await SecureCredentialStorage.loadTokens();
      final user = await SecureCredentialStorage.loadUser();

      if (tokens == null || user == null) {
        debugPrint('🔐 Nenhuma sessão salva encontrada');
        final savedCredentials = await SecureCredentialStorage.loadSavedCredentials();
        if (savedCredentials != null) {
          debugPrint('🔐 Credenciais salvas encontradas, tentando auto-login...');
          final result = await login(savedCredentials.email, savedCredentials.password);
          if (result.success) {
            debugPrint('✅ Auto-login concluído com sucesso');
            return;
          }
          debugPrint('❌ Falha no auto-login com credenciais salvas');
        }

        authStateNotifier.value = AuthState.unauthenticated;
        return;
      }

      debugPrint('🔐 Sessão encontrada para: ${user.email}');
      debugPrint('🔐 Token expira em: ${tokens.expiresAt}');
      debugPrint('🔐 Agora: ${DateTime.now()}');
      debugPrint('🔐 Token expirado: ${tokens.isExpired}');

      // Verificar se token expirou
      if (tokens.isExpired) {
        debugPrint('🔐 Token expirado, tentando refresh...');
        // Tentar refresh
        if (!tokens.isRefreshExpired) {
          debugPrint('🔐 Refresh token ainda válido');
          
          // Garantir que temos a URL da API
          if (_apiBaseUrl == null || _apiBaseUrl!.isEmpty) {
            debugPrint('⚠️  URL da API não configurada, não é possível fazer refresh');
            debugPrint('⚠️  Usuário precisará fazer login novamente');
            await logout();
            return;
          }
          
          final refreshed = await _refreshTokenInternal(tokens.refreshToken);
          if (refreshed) {
            currentUserNotifier.value = user;
            authStateNotifier.value = AuthState.authenticated;
            _startRefreshTimer();
            debugPrint('✅ Sessão restaurada via refresh token');
            return;
          } else {
            debugPrint('❌ Falha ao fazer refresh do token');
          }
        } else {
          debugPrint('🔐 Refresh token também expirado');
        }
        // Refresh falhou ou expirou
        await logout();
        return;
      }

      // Token válido
      _tokens = tokens;
      currentUserNotifier.value = user;
      authStateNotifier.value = AuthState.authenticated;
      _startRefreshTimer();
      debugPrint('✅ Sessão restaurada com sucesso para: ${user.email}');
    } catch (e, st) {
      debugPrint('❌ Erro ao restaurar sessão: $e');
      debugPrint('Stack trace: $st');
      authStateNotifier.value = AuthState.unauthenticated;
    }
  }

  /// Registra um novo usuário
  Future<AuthResult> register(String email, String password, {String? name}) async {
    // Tentar recarregar a URL da API se não estiver configurada
    if (_apiBaseUrl == null || _apiBaseUrl!.isEmpty) {
      try {
        final config = await PrefsService.loadDatabaseConfig();
        if (config.apiUrl != null && config.apiUrl!.isNotEmpty) {
          _apiBaseUrl = config.apiUrl;
        }
      } catch (e) {
        // Ignora erro de carregamento
      }
    }

    if (_apiBaseUrl == null || _apiBaseUrl!.isEmpty) {
      return AuthResult.failed(
        'Servidor não configurado.\n\n'
        'Vá em Configurações → Banco de Dados e preencha:\n'
        'URL da API: http://contaslite.hawk.com.br:3000',
        errorCode: 'NO_SERVER',
      );
    }

    authStateNotifier.value = AuthState.authenticating;
    errorNotifier.value = null;

    try {
      // Garantir que httpClient existe
      _httpClient ??= http.Client();
      
      final response = await _httpClient!
          .post(
            Uri.parse('$_apiBaseUrl/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
              'name': name?.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _handleAuthSuccess(data);
        await SecureCredentialStorage.saveCredentials(email, password);
        return AuthResult.successful();
      } else if (response.statusCode == 409) {
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = 'Este email já está cadastrado';
        return AuthResult.failed('Este email já está cadastrado', errorCode: 'EMAIL_EXISTS');
      } else if (response.statusCode == 400) {
        final error = _parseError(response.body);
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = error;
        return AuthResult.failed(error, errorCode: 'VALIDATION_ERROR');
      } else {
        final error = 'Erro no servidor: ${response.statusCode}';
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = error;
        return AuthResult.failed(error, errorCode: 'SERVER_ERROR');
      }
    } on TimeoutException {
      authStateNotifier.value = AuthState.error;
      errorNotifier.value = 'Servidor não respondeu. Verifique sua conexão.';
      return AuthResult.failed(
        'Servidor não respondeu. Verifique sua conexão.',
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ Erro ao registrar: $e');
      authStateNotifier.value = AuthState.error;
      errorNotifier.value = 'Erro de conexão: $e';
      return AuthResult.failed('Erro de conexão: $e', errorCode: 'CONNECTION_ERROR');
    }
  }

  /// Faz login com email e senha
  Future<AuthResult> login(String email, String password) async {
    debugPrint('🔐 Tentando login para: $email');
    debugPrint('🔐 URL da API: $_apiBaseUrl');
    
    // NÃO usar credenciais salvas automaticamente. Se não vier email/senha, falha.
    if (email.isEmpty || password.isEmpty) {
      return AuthResult.failed('Email e senha são obrigatórios', errorCode: 'MISSING_CREDENTIALS');
    }

    if (_apiBaseUrl == null) {
      debugPrint('❌ URL da API não configurada!');
      return AuthResult.failed(
        'Servidor não configurado. Configure nas configurações do banco de dados.',
        errorCode: 'NO_SERVER',
      );
    }

    authStateNotifier.value = AuthState.authenticating;
    errorNotifier.value = null;

    try {
      // Garantir que httpClient existe
      _httpClient ??= http.Client();
      
      debugPrint('🔐 Enviando requisição para: $_apiBaseUrl/api/auth/login');
      
      final response = await _httpClient!
          .post(
            Uri.parse('$_apiBaseUrl/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('🔐 Resposta recebida: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Login bem-sucedido, processando resposta...');
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _handleAuthSuccess(data);
        await SecureCredentialStorage.saveCredentials(email, password);
        return AuthResult.successful();
      } else if (response.statusCode == 401) {
        debugPrint('❌ Credenciais inválidas');
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = 'Email ou senha incorretos';
        return AuthResult.failed('Email ou senha incorretos', errorCode: 'INVALID_CREDENTIALS');
      } else if (response.statusCode == 404) {
        debugPrint('❌ Usuário não encontrado');
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = 'Usuário não encontrado';
        return AuthResult.failed('Usuário não encontrado', errorCode: 'USER_NOT_FOUND');
      } else {
        debugPrint('❌ Erro do servidor: ${response.statusCode}');
        final error = 'Erro no servidor: ${response.statusCode}';
        authStateNotifier.value = AuthState.error;
        errorNotifier.value = error;
        return AuthResult.failed(error, errorCode: 'SERVER_ERROR');
      }
    } on TimeoutException {
      authStateNotifier.value = AuthState.error;
      errorNotifier.value = 'Servidor não respondeu. Verifique sua conexão.';
      return AuthResult.failed(
        'Servidor não respondeu. Verifique sua conexão.',
        errorCode: 'TIMEOUT',
      );
    } catch (e) {
      debugPrint('❌ Erro ao fazer login: $e');
      authStateNotifier.value = AuthState.error;
      errorNotifier.value = 'Erro de conexão: $e';
      return AuthResult.failed('Erro de conexão: $e', errorCode: 'CONNECTION_ERROR');
    }
  }

  /// Faz logout e limpa todos os dados
  Future<void> logout() async {
    _stopRefreshTimer();

    // Tentar notificar servidor (opcional, não bloqueia logout local)
    if (_tokens != null && _apiBaseUrl != null) {
      try {
        // Garantir que httpClient existe
        _httpClient ??= http.Client();
        
        await _httpClient!
            .post(
              Uri.parse('$_apiBaseUrl/api/auth/logout'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${_tokens!.accessToken}',
              },
            )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('⚠️ Erro ao notificar servidor sobre logout: $e');
      }
    }

    // Limpar tokens, mas manter email/senha salvos para auto-login
    await SecureCredentialStorage.clearTokensOnly();
    _tokens = null;
    currentUserNotifier.value = null;
    authStateNotifier.value = AuthState.unauthenticated;
    errorNotifier.value = null;
    // Garantir que a UI reflita modo offline imediatamente
    SyncService.instance.syncStateNotifier.value = SyncState.offline;

    debugPrint('✅ Logout realizado com sucesso');
  }

  /// Renova o token de acesso
  Future<bool> refreshToken() async {
    if (_tokens == null) return false;
    return _refreshTokenInternal(_tokens!.refreshToken);
  }

  /// Obtém headers de autorização para requisições
  Map<String, String> getAuthHeaders() {
    if (_tokens == null) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_tokens!.accessToken}',
    };
  }

  /// Processa resposta de sucesso de login/registro
  Future<void> _handleAuthSuccess(Map<String, dynamic> data) async {
    try {
      debugPrint('🔍 [AuthService] Resposta do servidor: $data');
      
      // Extrair tokens
      final tokens = AuthTokens.fromJson(data);
      _tokens = tokens;
      debugPrint('🔍 [AuthService] Tokens extraídos - Expira em: ${tokens.expiresAt}');

      // Extrair usuário - pode vir em data['user'] ou direto em data
      final userData = data['user'] as Map<String, dynamic>?;
      final User user;
      
      if (userData != null) {
        user = User.fromJson(userData);
      } else if (data.containsKey('email')) {
        // Email pode estar diretamente na raiz
        final dynamic rawId = data['id'];
        user = User(
          id: rawId?.toString(),
          email: data['email'] as String,
          name: data['name'] as String?,
        );
      } else {
        throw Exception('Dados de usuário não encontrados na resposta');
      }

      debugPrint('🔍 [AuthService] Usuário extraído: ${user.email} (ID: ${user.id})');

      // Salvar de forma segura
      debugPrint('💾 Salvando tokens no storage...');
      await SecureCredentialStorage.saveTokens(tokens);
      debugPrint('💾 Salvando usuário no storage...');
      await SecureCredentialStorage.saveUser(user);
      debugPrint('✅ Credenciais salvas com sucesso');

      // Verificar se foram salvos corretamente
      final savedTokens = await SecureCredentialStorage.loadTokens();
      final savedUser = await SecureCredentialStorage.loadUser();
      debugPrint('🔍 Verificação - Tokens salvos: ${savedTokens != null}');
      debugPrint('🔍 Verificação - Usuário salvo: ${savedUser?.email}');

      // Atualizar estado
      debugPrint('🔐 Atualizando currentUserNotifier...');
      currentUserNotifier.value = user;
      
      debugPrint('🔐 Atualizando authStateNotifier para: AuthState.authenticated');
      authStateNotifier.value = AuthState.authenticated;
      debugPrint('🔐 authStateNotifier atualizado com sucesso');
      
      errorNotifier.value = null;

      // Iniciar timer de refresh
      debugPrint('🔐 Iniciando timer de refresh...');
      _startRefreshTimer();
      debugPrint('🔐 Timer de refresh iniciado');

      debugPrint('✅ Autenticação bem sucedida: ${user.email}');
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao processar resposta de auth: $e');
      debugPrint('Stack trace: $stackTrace');
      authStateNotifier.value = AuthState.error;
      errorNotifier.value = 'Erro ao processar resposta do servidor';
      rethrow;
    }
  }

  /// Renova token internamente
  Future<bool> _refreshTokenInternal(String refreshToken) async {
    if (_apiBaseUrl == null) return false;

    try {
      // Garantir que httpClient existe
      _httpClient ??= http.Client();
      
      final response = await _httpClient!
          .post(
            Uri.parse('$_apiBaseUrl/api/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newTokens = AuthTokens.fromJson(data);
        _tokens = newTokens;
        await SecureCredentialStorage.saveTokens(newTokens);
        _startRefreshTimer();
        debugPrint('✅ Token renovado com sucesso');
        return true;
      } else {
        debugPrint('❌ Falha ao renovar token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro ao renovar token: $e');
      return false;
    }
  }

  /// Inicia timer para refresh automático
  void _startRefreshTimer() {
    _stopRefreshTimer();

    if (_tokens == null) return;

    // Renovar 5 minutos antes de expirar
    final timeUntilRefresh = _tokens!.expiresAt
        .subtract(const Duration(minutes: 5))
        .difference(DateTime.now());

    if (timeUntilRefresh.isNegative) {
      // Já precisa renovar
      refreshToken();
    } else {
      _refreshTimer = Timer(timeUntilRefresh, () {
        refreshToken();
      });
      debugPrint('⏰ Refresh token agendado para: ${timeUntilRefresh.inMinutes} minutos');
    }
  }

  /// Para timer de refresh
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Extrai mensagem de erro do corpo da resposta
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

  /// Exclui todos os dados do usuário no servidor
  Future<bool> deleteAllUserData() async {
    if (_apiBaseUrl == null) {
      throw Exception('Servidor não configurado');
    }

    if (_tokens == null) {
      throw Exception('Usuário não autenticado');
    }

    try {
      _httpClient ??= http.Client();

      final response = await _httpClient!
          .delete(
            Uri.parse('$_apiBaseUrl/api/user/data'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_tokens!.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        debugPrint('✅ Dados do servidor excluídos com sucesso');
        return true;
      } else {
        final error = _parseError(response.body);
        debugPrint('❌ Erro ao excluir dados: $error');
        throw Exception(error);
      }
    } catch (e) {
      debugPrint('❌ Erro ao excluir dados do servidor: $e');
      rethrow;
    }
  }

  /// Libera recursos
  void dispose() {
    _stopRefreshTimer();
    _httpClient?.close();
  }
}
