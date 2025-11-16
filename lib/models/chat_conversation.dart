import 'package:cloud_firestore/cloud_firestore.dart';

class ChatConversation {
  final String id;
  final String productId;
  final String sellerId;
  final String buyerId;
  // Stored as 'participants' historically; new schema uses 'members'.
  final List<String> participants; // [buyerId, sellerId]
  final String lastMessage;
  // Stored as 'lastAt' historically; new schema uses 'updatedAt'.
  final DateTime lastAt;
  final String productName;
  final String productImageUrl;

  const ChatConversation({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.buyerId,
    required this.participants,
    required this.lastMessage,
    required this.lastAt,
    required this.productName,
    required this.productImageUrl,
  });

  ChatConversation copyWith({
    String? lastMessage,
    DateTime? lastAt,
  }) => ChatConversation(
        id: id,
        productId: productId,
        sellerId: sellerId,
        buyerId: buyerId,
        participants: participants,
        lastMessage: lastMessage ?? this.lastMessage,
        lastAt: lastAt ?? this.lastAt,
        productName: productName,
        productImageUrl: productImageUrl,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'sellerId': sellerId,
        'buyerId': buyerId,
        // Write under the new schema while keeping backward compatibility in reads.
        'members': participants,
        'lastMessage': lastMessage,
        'updatedAt': Timestamp.fromDate(lastAt),
        'productName': productName,
        'productImageUrl': productImageUrl,
      };

  static ChatConversation fromMap(Map<String, dynamic> map) {
    final ts = map['updatedAt'] ?? map['lastAt'];
    final lastAt = ts is Timestamp
        ? ts.toDate()
        : (ts is String ? DateTime.tryParse(ts) : null) ?? DateTime.now();
    final partsRaw = (map['members'] ?? map['participants']) as List?;
    final parts = partsRaw?.whereType<String>().toList() ?? const <String>[];
    return ChatConversation(
      id: (map['id'] ?? '') as String,
      productId: (map['productId'] ?? '') as String,
      sellerId: (map['sellerId'] ?? '') as String,
      buyerId: (map['buyerId'] ?? '') as String,
      participants: parts,
      lastMessage: (map['lastMessage'] ?? '') as String,
      lastAt: lastAt,
      productName: (map['productName'] ?? '') as String,
      productImageUrl: (map['productImageUrl'] ?? '') as String,
    );
  }
}
