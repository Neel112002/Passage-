import 'dart:convert';

import 'package:flutter/material.dart';

enum NotificationType { order, promotion, priceDrop, system }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool read;
  final String? imageUrl;
  final String? actionRoute; // optional route or deeplink

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
    this.imageUrl,
    this.actionRoute,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    DateTime? timestamp,
    bool? read,
    String? imageUrl,
    String? actionRoute,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      imageUrl: imageUrl ?? this.imageUrl,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }

  static NotificationType _typeFromString(String s) {
    switch (s) {
      case 'order':
        return NotificationType.order;
      case 'promotion':
        return NotificationType.promotion;
      case 'priceDrop':
        return NotificationType.priceDrop;
      case 'system':
      default:
        return NotificationType.system;
    }
  }

  static String _typeToString(NotificationType t) {
    switch (t) {
      case NotificationType.order:
        return 'order';
      case NotificationType.promotion:
        return 'promotion';
      case NotificationType.priceDrop:
        return 'priceDrop';
      case NotificationType.system:
        return 'system';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': _typeToString(type),
      'title': title,
      'body': body,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'read': read,
      'imageUrl': imageUrl,
      'actionRoute': actionRoute,
    };
  }

  static AppNotification fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: _typeFromString(map['type'] as String? ?? 'system'),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      read: (map['read'] as bool?) ?? false,
      imageUrl: map['imageUrl'] as String?,
      actionRoute: map['actionRoute'] as String?,
    );
  }

  static String encodeList(List<AppNotification> items) {
    return jsonEncode(items.map((e) => e.toMap()).toList());
  }

  static List<AppNotification> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => AppNotification.fromMap(m))
          .toList();
    }
    return [];
  }
}

IconData iconForType(NotificationType t) {
  switch (t) {
    case NotificationType.order:
      return Icons.local_shipping_outlined;
    case NotificationType.promotion:
      return Icons.local_offer_outlined;
    case NotificationType.priceDrop:
      return Icons.trending_down_outlined;
    case NotificationType.system:
    return Icons.notifications_outlined;
  }
}
