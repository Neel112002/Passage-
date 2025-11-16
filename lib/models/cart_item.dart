import 'dart:convert';

class CartItem {
  final String productId;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final int quantity;

  const CartItem({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.quantity,
  });

  CartItem copyWith({
    String? productId,
    String? name,
    String? imageUrl,
    double? unitPrice,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'imageUrl': imageUrl,
        'unitPrice': unitPrice,
        'quantity': quantity,
      };

  static CartItem fromMap(Map<String, dynamic> map) => CartItem(
        productId: (map['productId'] ?? '') as String,
        name: (map['name'] ?? '') as String,
        imageUrl: (map['imageUrl'] ?? '') as String,
        unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      );

  static String encodeList(List<CartItem> items) => jsonEncode(items.map((e) => e.toMap()).toList());
  static List<CartItem> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => CartItem.fromMap(m))
          .toList();
    }
    return [];
  }
}
