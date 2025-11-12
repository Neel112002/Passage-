import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/user_profile.dart';

class LocalUserProfileStore {
  static const String _key = 'user_profile_v1';

  // Save profile to SharedPreferences as JSON string
  static Future<void> save(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _toMap(profile);
    final jsonStr = jsonEncode(map);
    await prefs.setString(_key, jsonStr);
  }

  // Load profile if present; otherwise return null
  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, dynamic> _toMap(UserProfile p) {
    return {
      'fullName': p.fullName,
      'username': p.username,
      'email': p.email,
      'phone': p.phone,
      'bio': p.bio,
      'gender': p.gender,
      'dob': p.dob?.millisecondsSinceEpoch,
      'avatarUrl': p.avatarUrl,
      // Base64 encode avatar bytes if present; keep it compact
      'avatarBytes': p.avatarBytes != null ? base64Encode(p.avatarBytes!) : null,
      'createdAt': p.createdAt.millisecondsSinceEpoch,
      'updatedAt': p.updatedAt.millisecondsSinceEpoch,
    };
  }

  static UserProfile _fromMap(Map<String, dynamic> map) {
    Uint8List? bytes;
    final avatarStr = map['avatarBytes'];
    if (avatarStr is String && avatarStr.isNotEmpty) {
      try {
        bytes = Uint8List.fromList(base64Decode(avatarStr));
      } catch (_) {
        bytes = null;
      }
    }
    final dobMs = map['dob'];
    DateTime? dob;
    if (dobMs is int) {
      dob = DateTime.fromMillisecondsSinceEpoch(dobMs);
    }
    final createdAtMs = map['createdAt'];
    final updatedAtMs = map['updatedAt'];
    final createdAt = createdAtMs is int
        ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
        : DateTime.now();
    final updatedAt = updatedAtMs is int
        ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
        : DateTime.now();
    return UserProfile(
      fullName: (map['fullName'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      bio: (map['bio'] ?? '') as String,
      gender: (map['gender'] ?? '') as String,
      dob: dob,
      avatarUrl: (map['avatarUrl'] ?? '') as String,
      avatarBytes: bytes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
