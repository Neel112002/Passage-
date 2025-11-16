import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores per-user, per-chat hidden message IDs for "Delete for me" behavior.
/// Key format: hidden_msgs_v1:<uid>:<chatId>
class LocalHiddenMessagesStore {
  static String _key(String uid, String chatId) => 'hidden_msgs_v1:$uid:$chatId';

  /// Load hidden message IDs for a chat. Returns an immutable Set.
  static Future<Set<String>> loadHidden(String uid, String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid, chatId));
    if (raw == null || raw.isEmpty) return const <String>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        final list = decoded.whereType<String>().toSet();
        // Auto-sanitize if there were non-strings
        if (list.length != decoded.length) {
          await prefs.setString(_key(uid, chatId), json.encode(list.toList()));
        }
        return list;
      }
      // Unexpected shape; reset to empty
      await prefs.setString(_key(uid, chatId), json.encode([]));
      return const <String>{};
    } catch (_) {
      // Corrupted JSON; reset to empty
      await prefs.setString(_key(uid, chatId), json.encode([]));
      return const <String>{};
    }
  }

  /// Hide a message ID for the current user in a chat.
  static Future<void> hide(String uid, String chatId, String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadHidden(uid, chatId);
    final updated = <String>{...current, messageId}.toList();
    await prefs.setString(_key(uid, chatId), json.encode(updated));
  }
}
