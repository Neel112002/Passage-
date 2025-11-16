import 'dart:convert';
import 'package:flutter/foundation.dart';

enum PaymentMethodType { cod, card, paypal, gpay }

class PaymentMethodItem {
  final String id; // unique id (uuid-like)
  final PaymentMethodType type;
  final String label; // e.g., "Visa", "PayPal", "Google Pay", "Cash on Delivery"
  final String details; // e.g., "•••• 4242", email for PayPal, device/account label for GPay
  final bool isDefault;

  // Card specifics (only if type == card)
  final String? cardBrand; // Visa, MasterCard, etc.
  final String? last4;
  final int? expMonth; // 1-12
  final int? expYear; // yyyy
  final String? holderName;

  const PaymentMethodItem({
    required this.id,
    required this.type,
    required this.label,
    required this.details,
    this.isDefault = false,
    this.cardBrand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.holderName,
  });

  PaymentMethodItem copyWith({
    String? id,
    PaymentMethodType? type,
    String? label,
    String? details,
    bool? isDefault,
    String? cardBrand,
    String? last4,
    int? expMonth,
    int? expYear,
    String? holderName,
  }) {
    return PaymentMethodItem(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      details: details ?? this.details,
      isDefault: isDefault ?? this.isDefault,
      cardBrand: cardBrand ?? this.cardBrand,
      last4: last4 ?? this.last4,
      expMonth: expMonth ?? this.expMonth,
      expYear: expYear ?? this.expYear,
      holderName: holderName ?? this.holderName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': describeEnum(type),
      'label': label,
      'details': details,
      'isDefault': isDefault,
      'cardBrand': cardBrand,
      'last4': last4,
      'expMonth': expMonth,
      'expYear': expYear,
      'holderName': holderName,
    };
  }

  static PaymentMethodItem fromMap(Map<String, dynamic> map) {
    return PaymentMethodItem(
      id: (map['id'] ?? '') as String,
      type: _typeFromString((map['type'] ?? 'cod') as String),
      label: (map['label'] ?? '') as String,
      details: (map['details'] ?? '') as String,
      isDefault: (map['isDefault'] as bool?) ?? false,
      cardBrand: map['cardBrand'] as String?,
      last4: map['last4'] as String?,
      expMonth: map['expMonth'] is int ? map['expMonth'] as int : int.tryParse('${map['expMonth']}'),
      expYear: map['expYear'] is int ? map['expYear'] as int : int.tryParse('${map['expYear']}'),
      holderName: map['holderName'] as String?,
    );
  }

  static PaymentMethodType _typeFromString(String s) {
    switch (s) {
      case 'card':
        return PaymentMethodType.card;
      case 'paypal':
        return PaymentMethodType.paypal;
      case 'gpay':
        return PaymentMethodType.gpay;
      case 'cod':
      default:
        return PaymentMethodType.cod;
    }
  }

  static String encodeList(List<PaymentMethodItem> items) => jsonEncode(items.map((e) => e.toMap()).toList());
  static List<PaymentMethodItem> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => PaymentMethodItem.fromMap(m))
          .toList();
    }
    return [];
  }
}
