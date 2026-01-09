class AccountCategory {
  final int? id;
  final int accountId;
  final String categoria;

  AccountCategory({
    this.id,
    required this.accountId,
    required this.categoria,
  });

  // Converter objeto para Map (para salvar no banco)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'accountId': accountId,
      'description': categoria,
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
    );
  }

  // Criar cópia com campos modificados
  AccountCategory copyWith({
    int? id,
    int? accountId,
    String? categoria,
  }) {
    return AccountCategory(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      categoria: categoria ?? this.categoria,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountCategory &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          accountId == other.accountId &&
          categoria == other.categoria;

  @override
  int get hashCode => id.hashCode ^ accountId.hashCode ^ categoria.hashCode;

  @override
  String toString() =>
      'AccountCategory(id: $id, accountId: $accountId, categoria: $categoria)';
}
