import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:passage/models/chat_conversation.dart';
import 'package:passage/models/chat_message.dart';

class FirestoreChatsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static CollectionReference get _chats => _db.collection('chats');

  /// Compute deterministic chatId per spec
  /// if listingId present: sha1([listingId, ...sortedUids].join(':'))
  /// else: sorted uids joined by "__"
  static String chatIdFor({required String meUid, required String otherUid, String? listingId}) {
    final a = meUid.trim();
    final b = otherUid.trim();
    final sorted = (a.compareTo(b) <= 0) ? <String>[a, b] : <String>[b, a];
    if (listingId != null && listingId.isNotEmpty) {
      final base = [listingId, ...sorted].join(':');
      final digest = sha1.convert(utf8.encode(base)).toString();
      return digest;
    }
    return '${sorted.first}__${sorted.last}';
  }

  /// ensureChat(otherUid, listingId?)
  /// NOTE: With strict Firestore rules that gate reads on membership, a pre-read
  /// of chats/{chatId} (e.g., in a transaction) can fail with permission-denied
  /// when the document does not yet exist. To make this idempotent and rules-
  /// compatible, we avoid any pre-read and instead upsert the chat document
  /// with only allowed fields. We also only create the current user's members
  /// sub-doc; writing the other member's sub-doc may be disallowed by rules.
  static Future<String> ensureChat({
    required String meUid,
    required String otherUid,
    String? listingId,
    String? productName,
    String? productImageUrl,
  }) async {
    final chatId = chatIdFor(meUid: meUid, otherUid: otherUid, listingId: listingId);
    final chatRef = _chats.doc(chatId);

    // Stable sorted members
    final sortedMembers = (meUid.compareTo(otherUid) <= 0)
        ? <String>[meUid, otherUid]
        : <String>[otherUid, meUid];

    // Upsert chat with allowed fields only. Do NOT write nulls; some strict
    // rulesets reject explicit null values. Only include listingId when present.
    final payload = <String, dynamic>{
      'members': sortedMembers,
      'lastMessage': '',
      'lastSender': '',
      'productName': productName ?? '',
      'productImageUrl': productImageUrl ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (listingId != null && listingId.isNotEmpty) {
      payload['listingId'] = listingId;
    }

    // Use SetOptions(merge: true) to avoid requiring a pre-read.
    await chatRef.set(payload, SetOptions(merge: true));

    // Create/merge ONLY current user's members sub-doc. Other member will
    // create theirs when they open the chat from their side.
    await chatRef.collection('members').doc(meUid).set({
      'unread': 0,
      'lastReadAt': FieldValue.serverTimestamp(),
      'typing': false,
    }, SetOptions(merge: true));

    return chatId;
  }

  static Stream<List<ChatConversation>> watchConversationsForUser(String userId) {
    return _chats
        .where('members', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatConversation.fromMap({...d.data() as Map<String, dynamic>, 'id': d.id})).toList());
  }

  static Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(500)
        .snapshots()
        .map((snap) {
          final list = <ChatMessage>[];
          for (final d in snap.docs) {
            try {
              final raw = d.data();
              list.add(ChatMessage.fromMap({
                ...raw,
                'id': d.id,
                // synthesize conversationId/client-side for model compatibility
                'conversationId': chatId,
              }));
            } catch (e, st) {
              // Do not fail the entire stream due to a single bad document
              // This surfaces useful info to the console while keeping UI responsive
              // and resilient to partially migrated data.
              // ignore: avoid_print
              print('watchMessages: failed to parse message ${d.id}: $e\n$st');
            }
          }
          return list;
        });
  }

  /// Send a message with optional image per spec. Only writes allowed keys.
  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    Uint8List? imageBytes,
    String imageExtension = 'jpg',
  }) async {
    final chatRef = _chats.doc(chatId);

    // Build message id exactly as spec: `${Date.now()}_${me}_${rand6}`
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand6 = Random().nextDouble().toString().substring(2, 8);
    final mid = '${ts}_${senderId}_$rand6';
    String imageUrl = '';

    if (imageBytes != null && imageBytes.isNotEmpty) {
      // Upload to Storage: chatImages/<chatId>/<mid>.(ext)
      final ext = imageExtension.toLowerCase().replaceAll('.', '');
      final contentType = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
      final ref = FirebaseStorage.instance.ref().child('chatImages/$chatId/$mid.$ext');
      final meta = SettableMetadata(contentType: contentType);
      final task = await ref.putData(imageBytes, meta);
      imageUrl = await task.ref.getDownloadURL();
    }

    // Use a batch for message create + chat metadata update
    final batch = _db.batch();
    final payload = <String, dynamic>{
      'senderId': senderId,
      'text': (text ?? '').trim(),
      // Always include imageUrl per spec (empty string when not present)
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : '',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'sent',
    };
    batch.set(chatRef.collection('messages').doc(mid), payload);

    // Update chat summary (allowed fields only)
    final normalizedText = (text ?? '').trim();
    final lastMsg = normalizedText.isNotEmpty ? normalizedText : (imageUrl.isNotEmpty ? '📷 Photo' : '');
    batch.set(chatRef, {
      'lastMessage': lastMsg,
      'lastSender': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    // Note: We no longer attempt to write to other users' members/{uid} docs here.
    // The current security rules allow only the owner to update their own member doc.
    // Unread counts can be derived from lastReadAt vs createdAt or
    // updated via a Cloud Function if desired.
  }

  /// Subscribe to messages with pagination support
  static Stream<QuerySnapshot<Map<String, dynamic>>> subscribeMessagesSnapshots(
    String chatId, {
    int pageSize = 30,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> q = _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(pageSize);
    if (startAfter != null) {
      q = (q).startAfterDocument(startAfter);
    }
    return q.snapshots();
  }

  /// Mark current user's messages as read in a chat
  static Future<void> markRead({required String chatId, required String meUid}) async {
    final ref = _chats.doc(chatId).collection('members').doc(meUid);
    await ref.set({
      'unread': 0,
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Update typing indicator for current user. Caller may debounce.
  static Future<void> setTyping({required String chatId, required String meUid, required bool isTyping}) async {
    final ref = _chats.doc(chatId).collection('members').doc(meUid);
    await ref.set({'typing': isTyping}, SetOptions(merge: true));
  }

  /// Soft delete a message only for the current user (hide locally).
  /// Rules should allow a member to update their own `deletedFor.{uid}` flag.
  static Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String meUid,
  }) async {
    final msgRef = _chats.doc(chatId).collection('messages').doc(messageId);
    await msgRef.set({
      'deletedFor.$meUid': true,
    }, SetOptions(merge: true));
  }

  /// Soft delete a message for everyone. Only the sender (or admins by rules)
  /// should be permitted to do this. We mark `deleted=true`, blank out the
  /// content fields, and optionally delete the Storage object if present.
  static Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    String? imageUrl,
  }) async {
    final msgRef = _chats.doc(chatId).collection('messages').doc(messageId);
    // With your current security rules, "delete for everyone" should use a
    // document delete (only allowed for the original sender). Any attempt to
    // perform a soft-delete update is blocked by the keys-only constraint.
    await msgRef.delete();

    // Best-effort: delete image file if we have a direct URL
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        await ref.delete();
      } catch (_) {
        // Ignore storage delete failures; not critical to app flow
      }
    }
  }
}
