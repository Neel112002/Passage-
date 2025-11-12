import 'dart:convert';

class AddressItem {
  final String id; // uuid-like string
  final String label; // Home, Work, Other
  final String recipientName;
  final String phone;
  final String line1;
  final String line2;
  final String city;
  final String state;
  final String postalCode;
  final String countryCode; // ISO code like US, IN
  final bool isDefault;

  const AddressItem({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.countryCode,
    this.isDefault = false,
  });

  AddressItem copyWith({
    String? id,
    String? label,
    String? recipientName,
    String? phone,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? postalCode,
    String? countryCode,
    bool? isDefault,
  }) {
    return AddressItem(
      id: id ?? this.id,
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      countryCode: countryCode ?? this.countryCode,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'recipientName': recipientName,
      'phone': phone,
      'line1': line1,
      'line2': line2,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'countryCode': countryCode,
      'isDefault': isDefault,
    };
  }

  static AddressItem fromMap(Map<String, dynamic> map) {
    return AddressItem(
      id: map['id'] as String,
      label: (map['label'] ?? '') as String,
      recipientName: (map['recipientName'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      line1: (map['line1'] ?? '') as String,
      line2: (map['line2'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      state: (map['state'] ?? '') as String,
      postalCode: (map['postalCode'] ?? '') as String,
      countryCode: (map['countryCode'] ?? '') as String,
      isDefault: (map['isDefault'] as bool?) ?? false,
    );
  }

  static String encodeList(List<AddressItem> items) => jsonEncode(items.map((e) => e.toMap()).toList());
  static List<AddressItem> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => AddressItem.fromMap(m))
          .toList();
    }
    return [];
  }
}
