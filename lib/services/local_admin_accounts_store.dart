import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto;

class AdminAccountModel {
  final String email; // lowercased
  final String name;
  final String passwordHash; // sha256 hex
  final int createdAtMs;

  const AdminAccountModel({
    required this.email,
    required this.name,
    required this.passwordHash,
    required this.createdAtMs,
  });

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'passwordHash': passwordHash,
        'createdAtMs': createdAtMs,
      };

  static AdminAccountModel fromMap(Map<String, dynamic> map) {
    return AdminAccountModel(
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      passwordHash: (map['passwordHash'] ?? '').toString(),
      createdAtMs: (map['createdAtMs'] ?? 0) as int,
    );
  }
}

class LocalAdminAccountsStore {
  static const _key = 'local_admin_accounts_v1';

  static String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  // Seeds a single default admin for local testing if none exist.
  // Email: admin@passage.app
  // Password: Admin@123
  static Future<void> ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null && jsonStr.isNotEmpty) return;
    final seed = [
      AdminAccountModel(
        email: 'admin@passage.app',
        name: 'Passage Admin',
        passwordHash: _sha256Hex('Admin@123'),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ).toMap(),
    ];
    await prefs.setString(_key, jsonEncode(seed));
  }

  static Future<List<AdminAccountModel>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = (jsonDecode(jsonStr) as List).whereType<Map>().toList();
      return list
          .map((e) => AdminAccountModel.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<AdminAccountModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }

  static Future<bool> verifyCredentials({required String email, required String password}) async {
    await ensureSeeded();
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    final hash = _sha256Hex(password);
    return accounts.any((a) => a.email == normalized && a.passwordHash == hash);
  }

  static Future<bool> addAdmin({required String email, required String name, required String password}) async {
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) return false;
    final accounts = await _loadAll();
    if (accounts.any((a) => a.email == normalized)) return false; // already exists
    final updated = [
      ...accounts,
      AdminAccountModel(
        email: normalized,
        name: name.trim(),
        passwordHash: _sha256Hex(password),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    await _saveAll(updated);
    return true;
  }

  static Future<List<AdminAccountModel>> listAdmins() => _loadAll();
}
