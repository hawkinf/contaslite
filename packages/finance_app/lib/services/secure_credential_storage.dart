import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';

/// Armazenamento seguro para credenciais e tokens
/// No Windows/Web usa SharedPreferences (não requer flutter_secure_storage)
class SecureCredentialStorage {
  // Chaves de armazenamento
  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyTokenExpiry = 'auth_token_expiry';
  static const _keyRefreshExpiry = 'auth_refresh_expiry';
  static const _keyUserId = 'auth_user_id';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserName = 'auth_user_name';
  static const _keySavedEmail = 'auth_saved_email';
  static const _keySavedPassword = 'auth_saved_password';

  /// Salva tokens de autenticação de forma segura
  static Future<void> saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyAccessToken, tokens.accessToken),
      prefs.setString(_keyRefreshToken, tokens.refreshToken),
      prefs.setString(_keyTokenExpiry, tokens.expiresAt.toIso8601String()),
      if (tokens.refreshExpiresAt != null)
        prefs.setString(
          _keyRefreshExpiry,
          tokens.refreshExpiresAt!.toIso8601String(),
        ),
    ]);
  }

  /// Carrega tokens de autenticação
  static Future<AuthTokens?> loadTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_keyAccessToken);
      final refreshToken = prefs.getString(_keyRefreshToken);
      final expiryStr = prefs.getString(_keyTokenExpiry);
      final refreshExpiryStr = prefs.getString(_keyRefreshExpiry);

      if (accessToken == null || refreshToken == null || expiryStr == null) {
        return null;
      }

      return AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.parse(expiryStr),
        refreshExpiresAt:
            refreshExpiryStr != null ? DateTime.parse(refreshExpiryStr) : null,
      );
    } catch (e) {
      // Em caso de erro de leitura, limpar dados corrompidos
      await clearAll();
      return null;
    }
  }

  /// Salva informações do usuário de forma segura
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      if (user.id != null) prefs.setString(_keyUserId, user.id!),
      prefs.setString(_keyUserEmail, user.email),
      if (user.name != null) prefs.setString(_keyUserName, user.name!),
    ]);
  }

  /// Carrega informações do usuário
  static Future<User?> loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyUserEmail);
      if (email == null) return null;

      final id = prefs.getString(_keyUserId);
      final name = prefs.getString(_keyUserName);

      return User(
        id: id,
        email: email,
        name: name,
      );
    } catch (e) {
      return null;
    }
  }

  /// Limpa todos os dados de autenticação
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyAccessToken),
      prefs.remove(_keyRefreshToken),
      prefs.remove(_keyTokenExpiry),
      prefs.remove(_keyRefreshExpiry),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyUserName),
      prefs.remove(_keySavedEmail),
      prefs.remove(_keySavedPassword),
    ]);
  }

  /// Limpa apenas os tokens, preservando credenciais salvas
  static Future<void> clearTokensOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyAccessToken),
      prefs.remove(_keyRefreshToken),
      prefs.remove(_keyTokenExpiry),
      prefs.remove(_keyRefreshExpiry),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyUserName),
    ]);
  }

  /// Salva email/senha para auto-login
  static Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keySavedEmail, email.trim()),
      prefs.setString(_keySavedPassword, password),
    ]);
  }

  /// Carrega credenciais salvas
  static Future<({String email, String password})?> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keySavedEmail);
    final password = prefs.getString(_keySavedPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  /// Limpa credenciais salvas (email/senha)
  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keySavedEmail),
      prefs.remove(_keySavedPassword),
    ]);
  }

  /// Verifica se existem credenciais salvas
  static Future<bool> hasCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyAccessToken);
    return token != null;
  }

  /// Atualiza apenas o access token (após refresh)
  static Future<void> updateAccessToken(String newToken, DateTime newExpiry) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyAccessToken, newToken),
      prefs.setString(_keyTokenExpiry, newExpiry.toIso8601String()),
    ]);
  }
}
