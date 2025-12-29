class AccountDescription {
  final int? id;
  final int accountId;
  final String description;

  AccountDescription({
    this.id,
    required this.accountId,
    required this.description,
  });

  // Converter objeto para Map (para salvar no banco)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'accountId': accountId,
      'description': description,
    };
  }

  // Criar objeto a partir de Map (do banco)
  factory AccountDescription.fromMap(Map<String, dynamic> map) {
    return AccountDescription(
      id: map['id'] as int?,
      accountId: map['accountId'] as int,
      description: map['description'] as String,
    );
  }

  // Criar cópia com campos modificados
  AccountDescription copyWith({
    int? id,
    int? accountId,
    String? description,
  }) {
    return AccountDescription(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDescription &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          accountId == other.accountId &&
          description == other.description;

  @override
  int get hashCode => id.hashCode ^ accountId.hashCode ^ description.hashCode;

  @override
  String toString() =>
      'AccountDescription(id: $id, accountId: $accountId, description: $description)';
}
