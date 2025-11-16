import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
// Use URLs as stored in Firestore; do not normalize at model layer

class AdminProductModel {
  final String id; // unique id
  final String sellerId; // owner (Firebase uid)
  final String name;
  final String description;
  final double price;
  final String imageUrl; // primary image
  final List<String> imageUrls; // gallery
  // Optional Storage object paths aligned with imageUrls
  final List<String> storagePaths;
  final double rating; // seed/demo only
  final String tag; // e.g., Trending, New
  final String category; // e.g., Electronics
  final int stock; // inventory count
  final bool isActive; // toggle visibility in catalog
  final DateTime createdAt;
  final DateTime updatedAt;
  // Optional product video (stored as URL or small base64 data URL)
  final String videoUrl;

  // Marketplace additions (student second-hand)
  // Item condition: New, Like New, Good, Fair, For Parts
  final String condition;
  // Campus / community scope (e.g., domain or campus name)
  final String campus;
  // Local pickup only (no shipping)
  final bool pickupOnly;
  // Preferred pickup spot (e.g., Library, Dorm lobby)
  final String pickupLocation;
  // Is price negotiable
  final bool negotiable;

  const AdminProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.imageUrls,
    this.storagePaths = const <String>[],
    required this.rating,
    required this.tag,
    required this.category,
    required this.stock,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.condition = '',
    this.campus = '',
    this.pickupOnly = true,
    this.pickupLocation = '',
    this.negotiable = false,
    this.videoUrl = '',
  });

  AdminProductModel copyWith({
    String? id,
    String? sellerId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? imageUrls,
    List<String>? storagePaths,
    double? rating,
    String? tag,
    String? category,
    int? stock,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? condition,
    String? campus,
    bool? pickupOnly,
    String? pickupLocation,
    bool? negotiable,
    String? videoUrl,
  }) {
    return AdminProductModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      storagePaths: storagePaths ?? this.storagePaths,
      rating: rating ?? this.rating,
      tag: tag ?? this.tag,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      condition: condition ?? this.condition,
      campus: campus ?? this.campus,
      pickupOnly: pickupOnly ?? this.pickupOnly,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      negotiable: negotiable ?? this.negotiable,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'sellerId': sellerId,
        'name': name,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'imageUrls': imageUrls,
        if (storagePaths.isNotEmpty) 'storagePaths': storagePaths,
        'rating': rating,
        'tag': tag,
        'category': category,
        'stock': stock,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'videoUrl': videoUrl,
        // Marketplace fields (optional for back-compat)
        'condition': condition,
        'campus': campus,
        'pickupOnly': pickupOnly,
        'pickupLocation': pickupLocation,
        'negotiable': negotiable,
      };

  static AdminProductModel fromMap(Map<String, dynamic> map) {
    // Use gallery URLs as-is and filter out empty entries
    final rawImgs = (map['imageUrls'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final imgs = rawImgs
        .map((u) => (u).trim())
        .where((u) => u.isNotEmpty)
        .toList();
    final rawPaths = (map['storagePaths'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final createdAt = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : (map['createdAt'] is String
            ? DateTime.tryParse(map['createdAt'] as String)
            : null) ?? DateTime.now();
    final updatedAt = map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : (map['updatedAt'] is String
            ? DateTime.tryParse(map['updatedAt'] as String)
            : null) ?? DateTime.now();
    // Primary image URL; if absent, fall back to first gallery image
    String primary = ((map['imageUrl'] ?? '') as String).trim();
    if (primary.trim().isEmpty && imgs.isNotEmpty) {
      primary = imgs.first;
    }

    return AdminProductModel(
      id: (map['id'] ?? '') as String,
      sellerId: (map['sellerId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      imageUrl: primary,
      imageUrls: imgs,
      storagePaths: rawPaths,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      tag: (map['tag'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isActive: (map['isActive'] as bool?) ?? true,
      createdAt: createdAt,
      updatedAt: updatedAt,
      condition: (map['condition'] ?? '') as String,
      campus: (map['campus'] ?? '') as String,
      pickupOnly: (map['pickupOnly'] as bool?) ?? true,
      pickupLocation: (map['pickupLocation'] ?? '') as String,
      negotiable: (map['negotiable'] as bool?) ?? false,
      videoUrl: (map['videoUrl'] ?? '') as String,
    );
  }

  static String encodeList(List<AdminProductModel> items) =>
      jsonEncode(items.map((e) => e.toMap()).toList());

  static List<AdminProductModel> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((m) => AdminProductModel.fromMap(m))
          .toList();
    }
    return <AdminProductModel>[];
  }
}
