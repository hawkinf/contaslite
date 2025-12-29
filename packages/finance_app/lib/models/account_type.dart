class AccountType {
  final int? id;
  final String name;

  AccountType({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory AccountType.fromMap(Map<String, dynamic> map) {
    return AccountType(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  AccountType copyWith({
    int? id,
    String? name,
  }) {
    return AccountType(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'AccountType(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountType && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
