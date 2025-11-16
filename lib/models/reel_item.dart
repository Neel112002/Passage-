import 'dart:convert';

class ReelItem {
  final String id; // unique reel id
  final String productId; // link to product
  final String videoBase64; // base64-encoded bytes
  final String coverImageBase64; // base64-encoded image as placeholder/cover
  final String caption;

  const ReelItem({
    required this.id,
    required this.productId,
    required this.videoBase64,
    required this.coverImageBase64,
    required this.caption,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'videoBase64': videoBase64,
        'coverImageBase64': coverImageBase64,
        'caption': caption,
      };

  static ReelItem fromMap(Map<String, dynamic> map) => ReelItem(
        id: (map['id'] ?? '') as String,
        productId: (map['productId'] ?? '') as String,
        videoBase64: (map['videoBase64'] ?? '') as String,
        coverImageBase64: (map['coverImageBase64'] ?? '') as String,
        caption: (map['caption'] ?? '') as String,
      );

  static String encodeList(List<ReelItem> items) => jsonEncode(items.map((e) => e.toMap()).toList());
  static List<ReelItem> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().map((m) => ReelItem.fromMap(m)).toList();
    }
    return const <ReelItem>[];
  }
}
