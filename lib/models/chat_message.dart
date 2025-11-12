import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  // Stored as conversationId in existing data; corresponds to chatId in the new schema.
  final String conversationId;
  final String senderId;
  final String text;
  final String? imageUrl;
  // 'sent' | 'delivered' | 'read'
  final String status;
  final DateTime createdAt;
  // Deletion semantics
  // deleted = true means removed for everyone; UI shows a placeholder
  final bool deleted;
  // deletedFor is a map of userId -> true when the message is hidden only for that user
  final Map<String, dynamic> deletedFor;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.status = 'sent',
    required this.createdAt,
    this.deleted = false,
    this.deletedFor = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        if (deleted) 'deleted': true,
        if (deletedFor.isNotEmpty) 'deletedFor': deletedFor,
      };

  static ChatMessage fromMap(Map<String, dynamic> map) {
    final ts = map['createdAt'];
    final createdAt = ts is Timestamp
        ? ts.toDate()
        : (ts is String ? DateTime.tryParse(ts) : null) ?? DateTime.now();
    // Support either conversationId or chatId fields
    final convId = (map['conversationId'] ?? map['chatId'] ?? '') as String;
    return ChatMessage(
      id: (map['id'] ?? '') as String,
      conversationId: convId,
      senderId: (map['senderId'] ?? '') as String,
      text: (map['text'] ?? '') as String,
      imageUrl: map['imageUrl'] as String?,
      status: (map['status'] ?? 'sent') as String,
      createdAt: createdAt,
      deleted: (map['deleted'] ?? false) == true,
      deletedFor: (map['deletedFor'] is Map<String, dynamic>)
          ? (map['deletedFor'] as Map<String, dynamic>)
          : (map['deletedFor'] is Map)
              ? Map<String, dynamic>.from(map['deletedFor'] as Map)
              : const {},
    );
  }

  bool isDeletedForEveryone() => deleted || status == 'deleted';

  bool isHiddenForUser(String? uid) {
    if (uid == null) return false;
    final v = deletedFor[uid];
    if (v is bool) return v;
    return false;
  }
}
