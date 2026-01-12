/// Modelo de usuário para autenticação multi-usuário
class User {
  final String? id; // UUID do servidor
  final String email;
  final String? name;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  User({
    this.id,
    required this.email,
    this.name,
    this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  /// Obtém as iniciais do nome para exibição em avatar
  String get initials {
    if (name == null || name!.isEmpty) {
      return email.substring(0, 1).toUpperCase();
    }
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.substring(0, 1).toUpperCase();
  }

  /// Nome de exibição (nome ou email se nome não disponível)
  String get displayName => name?.isNotEmpty == true ? name! : email;

  /// Cria uma cópia com campos atualizados
  User copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Converte para Map para armazenamento local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
    };
  }

  /// Cria instância a partir de Map do banco local
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String?,
      email: map['email'] as String,
      name: map['name'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'] as String)
          : null,
      isActive: map['isActive'] == null || (map['isActive'] as int) == 1,
    );
  }

  /// Converte para JSON para envio à API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  /// Cria instância a partir de JSON da API
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String?,
      email: json['email'] as String,
      name: json['name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ name.hashCode;
}
