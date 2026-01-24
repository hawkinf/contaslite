/// Modelo para tokens JWT de autenticação
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final DateTime? refreshExpiresAt;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.refreshExpiresAt,
  });

  /// Verifica se o token de acesso expirou
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Verifica se o token precisa ser renovado (5 minutos antes de expirar)
  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  /// Verifica se o refresh token expirou
  bool get isRefreshExpired {
    if (refreshExpiresAt == null) return false;
    return DateTime.now().isAfter(refreshExpiresAt!);
  }

  /// Tempo restante até expiração
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  /// Cria uma cópia com campos atualizados
  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? refreshExpiresAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      refreshExpiresAt: refreshExpiresAt ?? this.refreshExpiresAt,
    );
  }

  /// Converte para Map para armazenamento
  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
      'refreshExpiresAt': refreshExpiresAt?.toIso8601String(),
    };
  }

  /// Cria instância a partir de Map
  factory AuthTokens.fromMap(Map<String, dynamic> map) {
    return AuthTokens(
      accessToken: map['accessToken'] as String,
      refreshToken: map['refreshToken'] as String,
      expiresAt: DateTime.parse(map['expiresAt'] as String),
      refreshExpiresAt: map['refreshExpiresAt'] != null
          ? DateTime.parse(map['refreshExpiresAt'] as String)
          : null,
    );
  }

  /// Cria instância a partir de resposta JSON da API
  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    // Suporta diferentes formatos de expiração
    DateTime parseExpiry(dynamic value) {
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        // Se for timestamp em segundos ou duração em segundos
        if (value > 1000000000) {
          // Timestamp (maior que 1 bilhão = depois de 2001)
          return DateTime.fromMillisecondsSinceEpoch(value * 1000);
        } else {
          // Duração em segundos (expiresIn)
          return DateTime.now().add(Duration(seconds: value));
        }
      }
      // Fallback: 1 hora a partir de agora
      return DateTime.now().add(const Duration(hours: 1));
    }

    // Aceitar tanto camelCase (accessToken) quanto snake_case (access_token)
    final accessToken = (json['accessToken'] ?? json['access_token']) as String?;
    final refreshToken = (json['refreshToken'] ?? json['refresh_token']) as String?;
    
    if (accessToken == null || refreshToken == null) {
      throw Exception('Tokens não encontrados na resposta: $json');
    }

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: parseExpiry(json['expires_at'] ?? json['expiresIn'] ?? json['expires_in']),
      refreshExpiresAt: json['refresh_expires_at'] != null || json['refreshExpiresAt'] != null
          ? parseExpiry(json['refresh_expires_at'] ?? json['refreshExpiresAt'])
          : null,
    );
  }

  @override
  String toString() {
    return 'AuthTokens(expiresAt: $expiresAt, isExpired: $isExpired, needsRefresh: $needsRefresh)';
  }
}

/// Resultado de operações de autenticação
class AuthResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final String? message;

  AuthResult({
    required this.success,
    this.error,
    this.errorCode,
    this.message,
  });

  factory AuthResult.successful({String? message}) => AuthResult(success: true, message: message);

  factory AuthResult.failed(String error, {String? errorCode}) => AuthResult(
        success: false,
        error: error,
        errorCode: errorCode,
      );

  @override
  String toString() => 'AuthResult(success: $success, error: $error, message: $message)';
}
