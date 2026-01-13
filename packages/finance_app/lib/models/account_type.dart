class AccountType {
  final int? id;
  final String name;
  final String? logo;

  AccountType({
    this.id,
    required this.name,
    this.logo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logo': logo,
    };
  }

  factory AccountType.fromMap(Map<String, dynamic> map) {
    return AccountType(
      id: map['id'] as int?,
      name: map['name'] as String,
      logo: map['logo'] as String?,
    );
  }

  AccountType copyWith({
    int? id,
    String? name,
    String? logo,
  }) {
    return AccountType(
      id: id ?? this.id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
    );
  }

  @override
  String toString() => 'AccountType(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
