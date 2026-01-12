import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_tokens.dart';
import '../models/user.dart';

/// Armazenamento seguro para credenciais e tokens usando flutter_secure_storage
class SecureCredentialStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  // Chaves de armazenamento
  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyTokenExpiry = 'auth_token_expiry';
  static const _keyRefreshExpiry = 'auth_refresh_expiry';
  static const _keyUserId = 'auth_user_id';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyUserName = 'auth_user_name';

  /// Salva tokens de autenticação de forma segura
  static Future<void> saveTokens(AuthTokens tokens) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: tokens.accessToken),
      _storage.write(key: _keyRefreshToken, value: tokens.refreshToken),
      _storage.write(key: _keyTokenExpiry, value: tokens.expiresAt.toIso8601String()),
      if (tokens.refreshExpiresAt != null)
        _storage.write(
          key: _keyRefreshExpiry,
          value: tokens.refreshExpiresAt!.toIso8601String(),
        ),
    ]);
  }

  /// Carrega tokens de autenticação
  static Future<AuthTokens?> loadTokens() async {
    try {
      final accessToken = await _storage.read(key: _keyAccessToken);
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      final expiryStr = await _storage.read(key: _keyTokenExpiry);
      final refreshExpiryStr = await _storage.read(key: _keyRefreshExpiry);

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
    await Future.wait([
      if (user.id != null) _storage.write(key: _keyUserId, value: user.id),
      _storage.write(key: _keyUserEmail, value: user.email),
      if (user.name != null) _storage.write(key: _keyUserName, value: user.name),
    ]);
  }

  /// Carrega informações do usuário
  static Future<User?> loadUser() async {
    try {
      final email = await _storage.read(key: _keyUserEmail);
      if (email == null) return null;

      final id = await _storage.read(key: _keyUserId);
      final name = await _storage.read(key: _keyUserName);

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
    await Future.wait([
      _storage.delete(key: _keyAccessToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyTokenExpiry),
      _storage.delete(key: _keyRefreshExpiry),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyUserEmail),
      _storage.delete(key: _keyUserName),
    ]);
  }

  /// Verifica se existem credenciais salvas
  static Future<bool> hasCredentials() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null;
  }

  /// Atualiza apenas o access token (após refresh)
  static Future<void> updateAccessToken(String newToken, DateTime newExpiry) async {
    await Future.wait([
      _storage.write(key: _keyAccessToken, value: newToken),
      _storage.write(key: _keyTokenExpiry, value: newExpiry.toIso8601String()),
    ]);
  }
}
