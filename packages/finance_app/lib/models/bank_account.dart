class BankAccount {
  final int? id;
  final int code;
  final String name;
  final String description;
  final String agency;
  final String account;
  final int color;

  BankAccount({
    this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.agency,
    required this.account,
    this.color = 0xFF1565C0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'description': description,
        'agency': agency,
        'account': account,
        'color': color,
      };

  factory BankAccount.fromMap(Map<String, dynamic> map) => BankAccount(
        id: map['id'] as int?,
        code: map['code'] as int,
        name: map['name'] as String,
        description: (map['description'] ?? '') as String,
        agency: map['agency'] as String,
        account: map['account'] as String,
        color: (map['color'] as int?) ?? 0xFF1565C0,
      );
}
