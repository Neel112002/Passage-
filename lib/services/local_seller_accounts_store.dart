import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto;

class SellerAccountModel {
  final String email; // lowercased
  final String name;
  final String passwordHash; // sha256 hex
  final int createdAtMs;
  final String? storeName;

  const SellerAccountModel({
    required this.email,
    required this.name,
    required this.passwordHash,
    required this.createdAtMs,
    this.storeName,
  });

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'passwordHash': passwordHash,
        'createdAtMs': createdAtMs,
        'storeName': storeName,
      };

  static SellerAccountModel fromMap(Map<String, dynamic> map) {
    return SellerAccountModel(
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      passwordHash: (map['passwordHash'] ?? '').toString(),
      createdAtMs: (map['createdAtMs'] ?? 0) as int,
      storeName: (map['storeName'] as String?)?.toString(),
    );
  }
}

class LocalSellerAccountsStore {
  static const _key = 'local_seller_accounts_v1';
  static const _sessionKey = 'local_seller_session_email_v1';

  static String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  static Future<List<SellerAccountModel>> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = (jsonDecode(jsonStr) as List).whereType<Map>().toList();
      return list
          .map((e) => SellerAccountModel.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<SellerAccountModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toMap()).toList()),
    );
  }

  // Public API
  static Future<bool> addSeller({
    required String email,
    required String name,
    required String password,
    String? storeName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) return false;
    final accounts = await _loadAll();
    if (accounts.any((a) => a.email == normalized)) return false; // already exists
    final updated = [
      ...accounts,
      SellerAccountModel(
        email: normalized,
        name: name.trim(),
        passwordHash: _sha256Hex(password),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        storeName: storeName?.trim(),
      ),
    ];
    await _saveAll(updated);
    return true;
  }

  static Future<bool> verifyCredentials({required String email, required String password}) async {
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    final hash = _sha256Hex(password);
    return accounts.any((a) => a.email == normalized && a.passwordHash == hash);
  }

  static Future<bool> emailExists(String email) async {
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    return accounts.any((a) => a.email == normalized);
  }

  static Future<bool> updatePassword({required String email, required String newPassword}) async {
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    final idx = accounts.indexWhere((a) => a.email == normalized);
    if (idx == -1) return false;
    final updated = List<SellerAccountModel>.from(accounts);
    final target = accounts[idx];
    updated[idx] = SellerAccountModel(
      email: target.email,
      name: target.name,
      passwordHash: _sha256Hex(newPassword),
      createdAtMs: target.createdAtMs,
      storeName: target.storeName,
    );
    await _saveAll(updated);
    return true;
  }

  static Future<List<SellerAccountModel>> listSellers() => _loadAll();

  // Update name and store name for a seller
  static Future<bool> updateProfile({
    required String email,
    String? name,
    String? storeName,
  }) async {
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    final idx = accounts.indexWhere((a) => a.email == normalized);
    if (idx == -1) return false;
    final target = accounts[idx];
    final updated = List<SellerAccountModel>.from(accounts);
    updated[idx] = SellerAccountModel(
      email: target.email,
      name: (name ?? target.name).trim(),
      passwordHash: target.passwordHash,
      createdAtMs: target.createdAtMs,
      storeName: (storeName ?? target.storeName)?.trim(),
    );
    await _saveAll(updated);
    return true;
  }

  // Remove a seller account entirely
  static Future<bool> removeSeller(String email) async {
    final accounts = await _loadAll();
    final normalized = email.trim().toLowerCase();
    final filtered = accounts.where((a) => a.email != normalized).toList(growable: false);
    if (filtered.length == accounts.length) return false; // nothing removed
    await _saveAll(filtered);
    // If the removed account is the active session, clear it
    final session = await getCurrentSeller();
    if (session != null && session == normalized) {
      await clearSession();
    }
    return true;
  }

  // Session helpers for seller side
  static Future<void> setCurrentSeller(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, email.trim().toLowerCase());
  }

  static Future<String?> getCurrentSeller() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_sessionKey);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
