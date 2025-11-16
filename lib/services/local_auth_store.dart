import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart' as crypto;

class LocalAuthSession {
  final String id; // random id or device hint
  final String deviceName; // e.g., "This device"
  final String platform; // e.g., Android/iOS/Web
  final int lastActiveMs; // epoch ms
  final bool isCurrent;

  const LocalAuthSession({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.lastActiveMs,
    required this.isCurrent,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'deviceName': deviceName,
        'platform': platform,
        'lastActiveMs': lastActiveMs,
        'isCurrent': isCurrent,
      };

  static LocalAuthSession fromMap(Map<String, dynamic> map) {
    return LocalAuthSession(
      id: (map['id'] ?? '') as String,
      deviceName: (map['deviceName'] ?? 'Unknown') as String,
      platform: (map['platform'] ?? 'Unknown') as String,
      lastActiveMs: (map['lastActiveMs'] ?? DateTime.now().millisecondsSinceEpoch) as int,
      isCurrent: (map['isCurrent'] ?? false) as bool,
    );
  }
}

class LocalAuthState {
  final String loginEmail; // primary login email (lowercased)
  final String passwordHash; // sha256 hex
  final bool twoFactorEnabled;
  final bool biometricEnabled;
  final bool appLockEnabled;
  final String? appLockPinHash; // sha256 of 4-6 digit pin
  final int? lastPasswordChangeMs;
  final List<LocalAuthSession> sessions;
  final String role; // 'user' | 'admin'

  const LocalAuthState({
    required this.loginEmail,
    required this.passwordHash,
    required this.twoFactorEnabled,
    required this.biometricEnabled,
    required this.appLockEnabled,
    required this.appLockPinHash,
    required this.lastPasswordChangeMs,
    required this.sessions,
    required this.role,
  });

  LocalAuthState copyWith({
    String? loginEmail,
    String? passwordHash,
    bool? twoFactorEnabled,
    bool? biometricEnabled,
    bool? appLockEnabled,
    String? appLockPinHash,
    int? lastPasswordChangeMs,
    List<LocalAuthSession>? sessions,
    String? role,
  }) {
    return LocalAuthState(
      loginEmail: loginEmail ?? this.loginEmail,
      passwordHash: passwordHash ?? this.passwordHash,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockPinHash: appLockPinHash ?? this.appLockPinHash,
      lastPasswordChangeMs: lastPasswordChangeMs ?? this.lastPasswordChangeMs,
      sessions: sessions ?? this.sessions,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() => {
        'loginEmail': loginEmail,
        'passwordHash': passwordHash,
        'twoFactorEnabled': twoFactorEnabled,
        'biometricEnabled': biometricEnabled,
        'appLockEnabled': appLockEnabled,
        'appLockPinHash': appLockPinHash,
        'lastPasswordChangeMs': lastPasswordChangeMs,
        'sessions': sessions.map((e) => e.toMap()).toList(),
        'role': role,
      };

  static LocalAuthState fromMap(Map<String, dynamic> map) {
    final rawSessions = (map['sessions'] as List?) ?? <dynamic>[];
    return LocalAuthState(
      loginEmail: (map['loginEmail'] ?? '') as String,
      passwordHash: (map['passwordHash'] ?? '') as String,
      twoFactorEnabled: (map['twoFactorEnabled'] ?? false) as bool,
      biometricEnabled: (map['biometricEnabled'] ?? false) as bool,
      appLockEnabled: (map['appLockEnabled'] ?? false) as bool,
      appLockPinHash: map['appLockPinHash'] as String?,
      lastPasswordChangeMs: map['lastPasswordChangeMs'] as int?,
      sessions: rawSessions
          .whereType<Map>()
          .map((e) => LocalAuthSession.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      role: (map['role'] ?? 'user') as String,
    );
  }
}

class LocalAuthStore {
  static const _key = 'local_auth_state_v1';

  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';

  static String _sha256Hex(String input) {
    try {
      final bytes = utf8.encode(input);
      final digest = crypto.sha256.convert(bytes);
      return digest.toString();
    } catch (_) {
      // Fallback to base64 when crypto not available (shouldn't happen)
      return base64Encode(utf8.encode(input));
    }
  }

  static Future<LocalAuthState> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr == null || jsonStr.isEmpty) {
        return _defaultState();
      }
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final state = LocalAuthState.fromMap(map);
      // Ensure at least one current session
      if (state.sessions.isEmpty || !state.sessions.any((s) => s.isCurrent)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return state.copyWith(sessions: [
          LocalAuthSession(
            id: 'this',
            deviceName: 'This device',
            platform: _platformLabel(),
            lastActiveMs: now,
            isCurrent: true,
          )
        ]);
      }
      return state;
    } catch (_) {
      return _defaultState();
    }
  }

  static Future<void> save(LocalAuthState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(state.toMap());
      await prefs.setString(_key, jsonStr);
    } catch (_) {
      // ignore
    }
  }

  // Role helpers
  static Future<void> setRole(String role) async {
    final s = await load();
    await save(s.copyWith(role: role));
  }

  static Future<String> getRole() async {
    final s = await load();
    return s.role;
  }

  static Future<bool> isAdmin() async {
    final s = await load();
    return s.role == roleAdmin;
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  static Future<bool> hasPassword() async {
    final s = await load();
    return s.passwordHash.isNotEmpty;
  }

  static Future<bool> verifyPassword(String password) async {
    final s = await load();
    if (s.passwordHash.isEmpty) return true; // no password set => allow
    return s.passwordHash == _sha256Hex(password);
  }

  static Future<void> setPassword(String newPassword) async {
    final s = await load();
    final updated = s.copyWith(
      passwordHash: _sha256Hex(newPassword),
      lastPasswordChangeMs: DateTime.now().millisecondsSinceEpoch,
    );
    await save(updated);
  }

  static Future<void> setLoginEmail(String email) async {
    final s = await load();
    await save(s.copyWith(loginEmail: email.trim().toLowerCase()));
  }

  static Future<String> getLoginEmail() async {
    final s = await load();
    return s.loginEmail;
  }

  static Future<bool> verifyEmailAndPassword({required String email, required String password}) async {
    final s = await load();
    final normalized = email.trim().toLowerCase();
    final emailMatches = s.loginEmail.isEmpty ? true : (s.loginEmail == normalized);
    final pwMatches = s.passwordHash.isEmpty ? true : (s.passwordHash == _sha256Hex(password));
    return emailMatches && pwMatches;
  }

  static Future<void> setTwoFactorEnabled(bool enabled) async {
    final s = await load();
    await save(s.copyWith(twoFactorEnabled: enabled));
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final s = await load();
    await save(s.copyWith(biometricEnabled: enabled));
  }

  static Future<void> setAppLock({required bool enabled, String? pin}) async {
    final s = await load();
    String? pinHash = s.appLockPinHash;
    if (pin != null && pin.isNotEmpty) {
      pinHash = _sha256Hex(pin);
    }
    await save(s.copyWith(appLockEnabled: enabled, appLockPinHash: pinHash));
  }

  static Future<void> updateSessions({bool signOutOthers = false, bool signOutAll = false}) async {
    final s = await load();
    List<LocalAuthSession> sessions = List<LocalAuthSession>.from(s.sessions);
    if (signOutAll) {
      // Keep current only
      final current = _ensureCurrentSession();
      sessions = [current];
    } else if (signOutOthers) {
      sessions = sessions.where((e) => e.isCurrent).toList(growable: false);
      if (sessions.isEmpty) {
        sessions = [_ensureCurrentSession()];
      }
    } else {
      // Ensure we have current
      if (sessions.isEmpty || !sessions.any((e) => e.isCurrent)) {
        sessions.add(_ensureCurrentSession());
      } else {
        // Tick lastActive on current
        final now = DateTime.now().millisecondsSinceEpoch;
        sessions = sessions
            .map((e) => e.isCurrent
                ? LocalAuthSession(
                    id: e.id,
                    deviceName: e.deviceName,
                    platform: e.platform,
                    lastActiveMs: now,
                    isCurrent: e.isCurrent,
                  )
                : e)
            .toList(growable: false);
      }
    }
    await save(s.copyWith(sessions: sessions));
  }

  static LocalAuthSession _ensureCurrentSession() {
    return LocalAuthSession(
      id: 'this',
      deviceName: 'This device',
      platform: _platformLabel(),
      lastActiveMs: DateTime.now().millisecondsSinceEpoch,
      isCurrent: true,
    );
  }

  static String _platformLabel() {
    // Keep a simple tag; detailed device info needs extra packages which we avoid for now
    return 'App';
  }

  static LocalAuthState _defaultState() {
    return LocalAuthState(
      loginEmail: '',
      passwordHash: '',
      twoFactorEnabled: false,
      biometricEnabled: false,
      appLockEnabled: false,
      appLockPinHash: null,
      lastPasswordChangeMs: null,
      sessions: [
        LocalAuthSession(
          id: 'this',
          deviceName: 'This device',
          platform: _platformLabel(),
          lastActiveMs: DateTime.now().millisecondsSinceEpoch,
          isCurrent: true,
        ),
      ],
      role: roleUser,
    );
  }
}
