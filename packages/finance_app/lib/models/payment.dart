class Payment {
  final int? id;
  final int accountId;
  final int paymentMethodId;
  final int? bankAccountId;
  final int? creditCardId;
  final double value;
  final String paymentDate;
  final String? observation;
  final String createdAt;

  Payment({
    this.id,
    required this.accountId,
    required this.paymentMethodId,
    this.bankAccountId,
    this.creditCardId,
    required this.value,
    required this.paymentDate,
    this.observation,
    required this.createdAt,
  });

  // Serialização para banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'account_id': accountId,
      'payment_method_id': paymentMethodId,
      'bank_account_id': bankAccountId,
      'credit_card_id': creditCardId,
      'value': value,
      'payment_date': paymentDate,
      'observation': observation,
      'created_at': createdAt,
    };
  }

  // Desserialização do banco de dados
  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      accountId: map['account_id'] as int,
      paymentMethodId: map['payment_method_id'] as int,
      bankAccountId: map['bank_account_id'] as int?,
      creditCardId: map['credit_card_id'] as int?,
      value: map['value'] as double,
      paymentDate: map['payment_date'] as String,
      observation: map['observation'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  // Cópia com alterações
  Payment copyWith({
    int? id,
    int? accountId,
    int? paymentMethodId,
    int? bankAccountId,
    int? creditCardId,
    double? value,
    String? paymentDate,
    String? observation,
    String? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      creditCardId: creditCardId ?? this.creditCardId,
      value: value ?? this.value,
      paymentDate: paymentDate ?? this.paymentDate,
      observation: observation ?? this.observation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Payment(id: $id, accountId: $accountId, paymentMethodId: $paymentMethodId, value: $value, paymentDate: $paymentDate)';
}
