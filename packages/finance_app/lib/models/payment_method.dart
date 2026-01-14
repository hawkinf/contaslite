import 'package:flutter/material.dart';

enum PaymentMethodUsage {
  pagamentos,
  recebimentos,
  pagamentosRecebimentos;

  static PaymentMethodUsage fromDb(Object? raw) {
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    switch (value) {
      case 0:
        return PaymentMethodUsage.pagamentos;
      case 1:
        return PaymentMethodUsage.recebimentos;
      case 2:
      default:
        return PaymentMethodUsage.pagamentosRecebimentos;
    }
  }

  int toDb() {
    switch (this) {
      case PaymentMethodUsage.pagamentos:
        return 0;
      case PaymentMethodUsage.recebimentos:
        return 1;
      case PaymentMethodUsage.pagamentosRecebimentos:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case PaymentMethodUsage.pagamentos:
        return 'Pagamentos';
      case PaymentMethodUsage.recebimentos:
        return 'Recebimentos';
      case PaymentMethodUsage.pagamentosRecebimentos:
        return 'Pagamentos/Recebimentos';
    }
  }
}

class PaymentMethod {
  final int? id;
  final String name;
  final String type;
  final int iconCode;
  final bool requiresBank;
  final bool isActive;
  final PaymentMethodUsage usage;
  final String? logo; // Emoji icon

  PaymentMethod({
    this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.requiresBank,
    this.isActive = true,
    this.usage = PaymentMethodUsage.pagamentosRecebimentos,
    this.logo,
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  bool get supportsPagamentos =>
      usage == PaymentMethodUsage.pagamentos ||
      usage == PaymentMethodUsage.pagamentosRecebimentos;

  bool get supportsRecebimentos =>
      usage == PaymentMethodUsage.recebimentos ||
      usage == PaymentMethodUsage.pagamentosRecebimentos;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon_code': iconCode,
      'requires_bank': requiresBank ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'usage': usage.toDb(),
      'logo': logo,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      iconCode: map['icon_code'] as int,
      requiresBank: (map['requires_bank'] as int?) == 1,
      isActive: (map['is_active'] as int?) == 1,
      usage: PaymentMethodUsage.fromDb(map['usage']),
      logo: map['logo'] as String?,
    );
  }

  PaymentMethod copyWith({
    int? id,
    String? name,
    String? type,
    int? iconCode,
    bool? requiresBank,
    bool? isActive,
    PaymentMethodUsage? usage,
    String? logo,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
      requiresBank: requiresBank ?? this.requiresBank,
      isActive: isActive ?? this.isActive,
      usage: usage ?? this.usage,
      logo: logo ?? this.logo,
    );
  }

  @override
  String toString() =>
      'PaymentMethod(id: $id, name: $name, type: $type, requiresBank: $requiresBank, usage: $usage)';
}

