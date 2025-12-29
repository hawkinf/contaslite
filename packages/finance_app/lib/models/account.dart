class Account {
  final int? id;
  final int typeId;
  final String description;
  final double value;
  final int dueDay;
  final bool isRecurrent;
  final bool payInAdvance;
  final int? month;
  final int? year;
  final int? recurrenceId;
  final int? installmentIndex;
  final int? installmentTotal;
  
  // Campos específicos para cartões de crédito
  final int? bestBuyDay;
  final String? cardBrand;
  final String? cardBank;
  final double? cardLimit;
  final int? cardColor;
  
  // Campos para rastreamento
  final int? cardId;
  final String? observation;
  final String? establishment;
  final String? purchaseUuid;
  final String? purchaseDate;
  final String? creationDate;

  Account({
    this.id,
    required this.typeId,
    required this.description,
    required this.value,
    required this.dueDay,
    this.isRecurrent = false,
    this.payInAdvance = false,
    this.month,
    this.year,
    this.recurrenceId,
    this.installmentIndex,
    this.installmentTotal,
    this.bestBuyDay,
    this.cardBrand,
    this.cardBank,
    this.cardLimit,
    this.cardColor,
    this.cardId,
    this.observation,
    this.establishment,
    this.purchaseUuid,
    this.purchaseDate,
    this.creationDate,
  });

  /// Verifica se é um cartão de crédito
  bool get isCreditCard => cardBrand != null;

  /// Verifica se é uma fatura de cartão
  bool get isCardInvoice => description.contains('Fatura:');

  /// Obtém a data de vencimento completa
  DateTime? get dueDate {
    if (month == null || year == null) return null;
    return DateTime(year!, month!, dueDay);
  }

  /// Verifica se a conta está vencida
  bool get isOverdue {
    final due = dueDate;
    if (due == null) return false;
    return due.isBefore(DateTime.now()) && !isRecurrent;
  }

  /// Cria uma cópia com campos atualizados
  Account copyWith({
    int? id,
    int? typeId,
    String? description,
    double? value,
    int? dueDay,
    bool? isRecurrent,
    bool? payInAdvance,
    int? month,
    int? year,
    int? recurrenceId,
    int? installmentIndex,
    int? installmentTotal,
    int? bestBuyDay,
    String? cardBrand,
    String? cardBank,
    double? cardLimit,
    int? cardColor,
    int? cardId,
    String? observation,
    String? establishment,
    String? purchaseUuid,
    String? purchaseDate,
    String? creationDate,
  }) {
    return Account(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      description: description ?? this.description,
      value: value ?? this.value,
      dueDay: dueDay ?? this.dueDay,
      isRecurrent: isRecurrent ?? this.isRecurrent,
      payInAdvance: payInAdvance ?? this.payInAdvance,
      month: month ?? this.month,
      year: year ?? this.year,
      recurrenceId: recurrenceId ?? this.recurrenceId,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentTotal: installmentTotal ?? this.installmentTotal,
      bestBuyDay: bestBuyDay ?? this.bestBuyDay,
      cardBrand: cardBrand ?? this.cardBrand,
      cardBank: cardBank ?? this.cardBank,
      cardLimit: cardLimit ?? this.cardLimit,
      cardColor: cardColor ?? this.cardColor,
      cardId: cardId ?? this.cardId,
      observation: observation ?? this.observation,
      establishment: establishment ?? this.establishment,
      purchaseUuid: purchaseUuid ?? this.purchaseUuid,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      creationDate: creationDate ?? this.creationDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'typeId': typeId,
      'description': description,
      'value': value,
      'dueDay': dueDay,
      'isRecurrent': isRecurrent ? 1 : 0,
      'payInAdvance': payInAdvance ? 1 : 0,
      'month': month,
      'year': year,
      'recurrenceId': recurrenceId,
      'installmentIndex': installmentIndex,
      'installmentTotal': installmentTotal,
      'bestBuyDay': bestBuyDay,
      'cardBrand': cardBrand,
      'cardBank': cardBank,
      'cardLimit': cardLimit,
      'cardColor': cardColor,
      'cardId': cardId,
      'observation': observation,
      'establishment': establishment,
      'purchaseUuid': purchaseUuid,
      'purchaseDate': purchaseDate,
      'creationDate': creationDate,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      typeId: map['typeId'] as int,
      description: map['description'] as String,
      value: (map['value'] as num).toDouble(),
      dueDay: map['dueDay'] as int,
      isRecurrent: (map['isRecurrent'] as int) == 1,
      payInAdvance: (map['payInAdvance'] as int) == 1,
      month: map['month'] as int?,
      year: map['year'] as int?,
      recurrenceId: map['recurrenceId'] as int?,
      installmentIndex: map['installmentIndex'] as int?,
      installmentTotal: map['installmentTotal'] as int?,
      bestBuyDay: map['bestBuyDay'] as int?,
      cardBrand: map['cardBrand'] as String?,
      cardBank: map['cardBank'] as String?,
      cardLimit: map['cardLimit'] != null ? (map['cardLimit'] as num).toDouble() : null,
      cardColor: map['cardColor'] as int?,
      cardId: map['cardId'] as int?,
      observation: map['observation'] as String?,
      establishment: map['establishment'] as String?,
      purchaseUuid: map['purchaseUuid'] as String?,
      purchaseDate: map['purchaseDate'] as String?,
      creationDate: map['creationDate'] as String?,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, description: $description, value: $value, dueDay: $dueDay)';
  }
}
