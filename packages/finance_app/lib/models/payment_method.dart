import 'package:flutter/material.dart';

class PaymentMethod {
  final int? id;
  final String name;
  final String type;
  final int iconCode;
  final bool requiresBank;
  final bool isActive;

  PaymentMethod({
    this.id,
    required this.name,
    required this.type,
    required this.iconCode,
    required this.requiresBank,
    this.isActive = true,
  });

  // Getter para ícone a partir do código armazenado
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  // Serialização para banco de dados
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon_code': iconCode,
      'requires_bank': requiresBank ? 1 : 0,
      'is_active': isActive ? 1 : 0,
    };
  }

  // Desserialização do banco de dados
  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      iconCode: map['icon_code'] as int,
      requiresBank: (map['requires_bank'] as int?) == 1,
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  // Cópia com alterações
  PaymentMethod copyWith({
    int? id,
    String? name,
    String? type,
    int? iconCode,
    bool? requiresBank,
    bool? isActive,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconCode: iconCode ?? this.iconCode,
      requiresBank: requiresBank ?? this.requiresBank,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'PaymentMethod(id: $id, name: $name, type: $type, requiresBank: $requiresBank)';
}
