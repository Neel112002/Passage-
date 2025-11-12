import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductReview {
  final String id; // unique review id
  final String productId;
  final String userId; // Owner of the review
  final String authorName;
  final String? authorEmail;
  final double rating; // 1.0 - 5.0
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.authorName,
    this.authorEmail,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  ProductReview copyWith({
    String? id,
    String? productId,
    String? userId,
    String? authorName,
    String? authorEmail,
    double? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductReview(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'userId': userId,
        'authorName': authorName,
        'authorEmail': authorEmail,
        'rating': rating,
        'comment': comment,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static ProductReview fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'] is Timestamp
        ? (map['createdAt'] as Timestamp).toDate()
        : (map['createdAtMs'] != null
            ? DateTime.fromMillisecondsSinceEpoch((map['createdAtMs'] as num).toInt())
            : DateTime.now());
    final updatedAt = map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : DateTime.now();
    return ProductReview(
      id: (map['id'] ?? '') as String,
      productId: (map['productId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
      authorName: (map['authorName'] ?? 'Anonymous') as String,
      authorEmail: map['authorEmail'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: (map['comment'] ?? '') as String,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String encodeList(List<ProductReview> items) => jsonEncode(items.map((e) => e.toMap()).toList());

  static List<ProductReview> decodeList(String jsonStr) {
    final raw = jsonDecode(jsonStr);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => ProductReview.fromMap(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }
}
