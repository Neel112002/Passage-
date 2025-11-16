import 'dart:convert';

class NotificationPrefs {
  final bool pushEnabled;
  final bool orderUpdates;
  final bool promotions;
  final bool priceDrops;
  final bool systemAlerts;
  final bool inAppSound;
  final bool inAppVibrate;
  final bool dndEnabled;
  // Minutes from 00:00 (0-1439)
  final int dndStartMinutes;
  final int dndEndMinutes;

  const NotificationPrefs({
    required this.pushEnabled,
    required this.orderUpdates,
    required this.promotions,
    required this.priceDrops,
    required this.systemAlerts,
    required this.inAppSound,
    required this.inAppVibrate,
    required this.dndEnabled,
    required this.dndStartMinutes,
    required this.dndEndMinutes,
  });

  factory NotificationPrefs.defaults() => const NotificationPrefs(
        pushEnabled: true,
        orderUpdates: true,
        promotions: true,
        priceDrops: true,
        systemAlerts: true,
        inAppSound: true,
        inAppVibrate: true,
        dndEnabled: false,
        dndStartMinutes: 22 * 60, // 10:00 PM
        dndEndMinutes: 7 * 60, // 7:00 AM
      );

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? orderUpdates,
    bool? promotions,
    bool? priceDrops,
    bool? systemAlerts,
    bool? inAppSound,
    bool? inAppVibrate,
    bool? dndEnabled,
    int? dndStartMinutes,
    int? dndEndMinutes,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      orderUpdates: orderUpdates ?? this.orderUpdates,
      promotions: promotions ?? this.promotions,
      priceDrops: priceDrops ?? this.priceDrops,
      systemAlerts: systemAlerts ?? this.systemAlerts,
      inAppSound: inAppSound ?? this.inAppSound,
      inAppVibrate: inAppVibrate ?? this.inAppVibrate,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStartMinutes: dndStartMinutes ?? this.dndStartMinutes,
      dndEndMinutes: dndEndMinutes ?? this.dndEndMinutes,
    );
  }

  Map<String, dynamic> toMap() => {
        'pushEnabled': pushEnabled,
        'orderUpdates': orderUpdates,
        'promotions': promotions,
        'priceDrops': priceDrops,
        'systemAlerts': systemAlerts,
        'inAppSound': inAppSound,
        'inAppVibrate': inAppVibrate,
        'dndEnabled': dndEnabled,
        'dndStartMinutes': dndStartMinutes,
        'dndEndMinutes': dndEndMinutes,
      };

  static NotificationPrefs fromMap(Map<String, dynamic> map) {
    return NotificationPrefs(
      pushEnabled: (map['pushEnabled'] as bool?) ?? true,
      orderUpdates: (map['orderUpdates'] as bool?) ?? true,
      promotions: (map['promotions'] as bool?) ?? true,
      priceDrops: (map['priceDrops'] as bool?) ?? true,
      systemAlerts: (map['systemAlerts'] as bool?) ?? true,
      inAppSound: (map['inAppSound'] as bool?) ?? true,
      inAppVibrate: (map['inAppVibrate'] as bool?) ?? true,
      dndEnabled: (map['dndEnabled'] as bool?) ?? false,
      dndStartMinutes: (map['dndStartMinutes'] as int?) ?? 22 * 60,
      dndEndMinutes: (map['dndEndMinutes'] as int?) ?? 7 * 60,
    );
  }

  String toJson() => jsonEncode(toMap());
  static NotificationPrefs fromJson(String s) => fromMap(jsonDecode(s) as Map<String, dynamic>);
}

String minutesToTimeLabel(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return '$hh:$mm';
}
