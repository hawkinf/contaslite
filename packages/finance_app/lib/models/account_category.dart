class AccountCategory {
  final int? id;
  final int accountId;
  final String categoria;
  final String? logo;

  AccountCategory({
    this.id,
    required this.accountId,
    required this.categoria,
    this.logo,
  });

  // Converter objeto para Map (para salvar no banco)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'accountId': accountId,
      'description': categoria,
      'logo': logo,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Criar objeto a partir de Map (do banco)
  factory AccountCategory.fromMap(Map<String, dynamic> map) {
    return AccountCategory(
      id: map['id'] as int?,
      accountId: map['accountId'] as int,
      categoria: map['description'] as String,
      logo: map['logo'] as String?,
    );
  }

  // Criar cópia com campos modificados
  AccountCategory copyWith({
    int? id,
    int? accountId,
    String? categoria,
    String? logo,
  }) {
    return AccountCategory(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoria: categoria ?? this.categoria,
      logo: logo ?? this.logo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AccountCategory(id: $id, accountId: $accountId, categoria: $categoria)';
}
