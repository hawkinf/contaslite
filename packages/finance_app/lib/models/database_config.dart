/// Configuração de banco de dados PostgreSQL
class DatabaseConfig {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final bool enabled; // Se PostgreSQL está habilitado

  DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    this.enabled = false,
  });

  /// Converte para JSON para armazenar em SharedPreferences
  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'database': database,
    'username': username,
    'password': password,
    'enabled': enabled,
  };

  /// Cria a partir de JSON
  factory DatabaseConfig.fromJson(Map<String, dynamic> json) => DatabaseConfig(
    host: json['host'] as String? ?? '',
    port: json['port'] as int? ?? 5432,
    database: json['database'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? false,
  );

  /// Cria uma cópia com campos alterados
  DatabaseConfig copyWith({
    String? host,
    int? port,
    String? database,
    String? username,
    String? password,
    bool? enabled,
  }) => DatabaseConfig(
    host: host ?? this.host,
    port: port ?? this.port,
    database: database ?? this.database,
    username: username ?? this.username,
    password: password ?? this.password,
    enabled: enabled ?? this.enabled,
  );

  /// Verifica se as configurações estão preenchidas
  bool get isComplete =>
    host.isNotEmpty &&
    database.isNotEmpty &&
    username.isNotEmpty &&
    password.isNotEmpty &&
    port > 0;

  /// String para exibição
  String get displayString => '$username@$host:$port/$database';

  @override
  String toString() => 'DatabaseConfig($displayString)';

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is DatabaseConfig &&
    runtimeType == other.runtimeType &&
    host == other.host &&
    port == other.port &&
    database == other.database &&
    username == other.username &&
    password == other.password &&
    enabled == other.enabled;

  @override
  int get hashCode =>
    host.hashCode ^
    port.hashCode ^
    database.hashCode ^
    username.hashCode ^
    password.hashCode ^
    enabled.hashCode;
}
