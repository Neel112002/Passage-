import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus { processing, shipped, delivered, cancelled }

class OrderLineItem {
  final String productId;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final int quantity;

  const OrderLineItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  static OrderLineItem fromMap(Map<String, dynamic> map) => OrderLineItem(
        productId: (map['productId'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        imageUrl: (map['imageUrl'] ?? '') as String,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      );
}

class OrderItemModel {
  final String id; // uuid-like
  final String userId; // Owner of the order
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderStatus status;
  final List<OrderLineItem> items;

  // Pricing snapshot
  final double subtotal;
  final double shippingFee;
  final double tax;
  final double total;

  // Fulfillment / meta
  final String? shippingAddressSummary; // short text snapshot
  final String? paymentSummary; // e.g., Visa •••• 4242, PayPal email, COD
  final String? trackingNumber;
  final DateTime? deliveredAt;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.tax,
    required this.total,
    this.shippingAddressSummary,
    this.paymentSummary,
    this.trackingNumber,
    this.deliveredAt,
    this.notes,
  });

  OrderItemModel copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    OrderStatus? status,
    List<OrderLineItem>? items,
    double? subtotal,
    double? shippingFee,
    double? tax,
    double? total,
    String? shippingAddressSummary,
    String? paymentSummary,
    String? trackingNumber,
    DateTime? deliveredAt,
    String? notes,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      shippingFee: shippingFee ?? this.shippingFee,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      shippingAddressSummary: shippingAddressSummary ?? this.shippingAddressSummary,
      paymentSummary: paymentSummary ?? this.paymentSummary,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'status': describeEnum(status),
        'items': items.map((e) => e.toMap()).toList(),
        'subtotal': subtotal,
        'shippingFee': shippingFee,
        'tax': tax,
        'total': total,
        'shippingAddressSummary': shippingAddressSummary,
        'paymentSummary': paymentSummary,
        'trackingNumber': trackingNumber,
        'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
        'notes': notes,
      };

  static OrderItemModel fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : DateTime.tryParse((map['createdAt'] ?? '') as String) ?? DateTime.now();
    final updatedAt = map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : DateTime.tryParse((map['updatedAt'] ?? '') as String) ?? DateTime.now();
    final deliveredAt = map['deliveredAt'] is Timestamp
        ? (map['deliveredAt'] as Timestamp).toDate()
        : (map['deliveredAt'] != null
            ? DateTime.tryParse(map['deliveredAt'] as String)
            : null);
    return OrderItemModel(
      id: (map['id'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      createdAt: createdAt,
      updatedAt: updatedAt,
      status: _statusFromString((map['status'] ?? 'processing') as String),
      items: ((map['items'] ?? []) as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => OrderLineItem.fromMap(m))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      shippingFee: (map['shippingFee'] as num?)?.toDouble() ?? 0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      shippingAddressSummary: map['shippingAddressSummary'] as String?,
      paymentSummary: map['paymentSummary'] as String?,
      trackingNumber: map['trackingNumber'] as String?,
      deliveredAt: deliveredAt,
      notes: map['notes'] as String?,
    );
  }

  static String encodeList(List<OrderItemModel> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());

  static List<OrderItemModel> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => OrderItemModel.fromMap(m))
          .toList();
    }
    return [];
  }
}

OrderStatus _statusFromString(String s) {
  switch (s) {
    case 'shipped':
      return OrderStatus.shipped;
    case 'delivered':
      return OrderStatus.delivered;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'processing':
    default:
      return OrderStatus.processing;
  }
}
