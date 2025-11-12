import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:passage/services/firebase_auth_service.dart';

/// Global AuthStore (singleton) to stabilize auth across app lifecycle.
/// Supports Firebase now; can be extended to Supabase later.
class AuthStore extends ChangeNotifier {
  AuthStore._internal();
  static final AuthStore instance = AuthStore._internal();

  // Public state
  fb.User? _fbUser;
  String? _role; // e.g., 'user', 'admin', 'seller'
  String? _companyId;
  bool _authReady = false; // flips true after the first auth event
  DateTime? _lastCheckedAt;

  // Event log (last 10)
  final List<AuthEvent> _events = <AuthEvent>[];
  final List<AuthSnapshot> _snapshots = <AuthSnapshot>[]; // for diffing

  // Exposed getters
  fb.User? get user => _fbUser;
  String? get role => _role;
  String? get companyId => _companyId;
  bool get authReady => _authReady;
  DateTime? get lastCheckedAt => _lastCheckedAt;
  UnmodifiableListView<AuthEvent> get events => UnmodifiableListView(_events.reversed); // newest first
  UnmodifiableListView<AuthSnapshot> get snapshots => UnmodifiableListView(_snapshots);

  /// Initialize listeners and web persistence. Safe to call multiple times.
  bool _initialized = false;
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (kIsWeb) {
        // Ensure persistence survives refresh/navigations on web.
        try {
          await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.LOCAL);
          _log('setPersistence(LOCAL) applied');
        } catch (e1) {
          _log('setPersistence(LOCAL) failed: $e1');
          try {
            await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.SESSION);
            _log('setPersistence(SESSION) applied');
          } catch (e2) {
            _log('setPersistence(SESSION) failed: $e2');
            await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.NONE);
            _log('setPersistence(NONE) applied');
          }
        }
        // Helpful diagnostic for cross-device/web-host issues
        try {
          _log('Web host: ' + Uri.base.toString());
        } catch (_) {}

        // If a signInWithRedirect was triggered, finalize it here.
        try {
          final result = await fb.FirebaseAuth.instance.getRedirectResult();
          if (result.user != null) {
            _log('Redirect sign-in completed for '+(result.user!.uid));
            // Firestore profile will be created by the calling flow if needed.
          }
        } catch (e) {
          _log('getRedirectResult error: '+e.toString());
        }
      }
    } catch (e) {
      _log('setPersistence failed: $e');
    }

    // Subscribe to Firebase auth state
    fb.FirebaseAuth.instance.authStateChanges().listen((u) {
      _setUserFromFirebase(u);
    });

    // Also emit initial value explicitly (some platforms wait for first emission)
    _setUserFromFirebase(fb.FirebaseAuth.instance.currentUser);
  }

  void _setUserFromFirebase(fb.User? u) {
    final previous = _snapshot();

    _fbUser = u;
    _lastCheckedAt = DateTime.now();
    if (!_authReady) _authReady = true; // first hydration complete

    // If we don't yet have a role, default to 'user' after sign-in
    if (_fbUser != null && _role == null) {
      _role = 'user';
    }

    _recordSnapshotAndDiff(previous, _snapshot());
    notifyListeners();

    // If there's a pending link (e.g., Google credential after account-exists-with-different-credential),
    // and we now have a signed-in user matching the email, attempt to link silently.
    try {
      final pending = FirebaseAuthService.pendingLinkCredential;
      final pendingEmail = FirebaseAuthService.pendingLinkEmail;
      if (u != null && pending != null) {
        final userEmail = (u.email ?? '').toLowerCase();
        if (pendingEmail == null || pendingEmail == userEmail) {
          _log('Attempting to link pending credential to '+(u.uid)+' ('+userEmail+')');
          u.linkWithCredential(pending).then((_) {
            _log('Link successful');
          }).catchError((err) {
            _log('Link failed: '+err.toString());
          }).whenComplete(() {
            FirebaseAuthService.pendingLinkCredential = null;
            FirebaseAuthService.pendingLinkEmail = null;
          });
        }
      }
    } catch (e) {
      _log('Link attempt errored: '+e.toString());
      FirebaseAuthService.pendingLinkCredential = null;
      FirebaseAuthService.pendingLinkEmail = null;
    }
  }

  /// Call this right after successful sign-in to standardize store fields.
  void setSignedIn({
    required String id,
    required String? email,
    String? role,
    String? companyId,
  }) {
    final previous = _snapshot();
    _fbUser = fb.FirebaseAuth.instance.currentUser;
    _role = role ?? _role ?? 'user';
    _companyId = companyId ?? _companyId;
    _lastCheckedAt = DateTime.now();
    _authReady = true;
    _log('Sign-in recorded for $id');
    _recordSnapshotAndDiff(previous, _snapshot());
    notifyListeners();
  }

  /// Update role or company id later if needed.
  void updateClaims({String? role, String? companyId}) {
    final previous = _snapshot();
    if (role != null) _role = role;
    if (companyId != null) _companyId = companyId;
    _lastCheckedAt = DateTime.now();
    _recordSnapshotAndDiff(previous, _snapshot());
    notifyListeners();
  }

  void clear() {
    final previous = _snapshot();
    _fbUser = null;
    _role = null;
    _companyId = null;
    _lastCheckedAt = DateTime.now();
    _authReady = true; // hydration occurred but no user
    _log('Auth cleared');
    _recordSnapshotAndDiff(previous, _snapshot());
    notifyListeners();
  }

  // --- Debug logging & diff helpers ---
  void _log(String message) {
    final event = AuthEvent(message: message, timestamp: DateTime.now());
    _events.add(event);
    while (_events.length > 10) {
      _events.removeAt(0);
    }
  }

  AuthSnapshot _snapshot() => AuthSnapshot(
        authReady: _authReady,
        userId: _fbUser?.uid,
        email: _fbUser?.email,
        role: _role,
        companyId: _companyId,
        timestamp: DateTime.now(),
      );

  void _recordSnapshotAndDiff(AuthSnapshot prev, AuthSnapshot next) {
    _snapshots.add(next);
    while (_snapshots.length > 20) {
      _snapshots.removeAt(0);
    }
    final diffs = next.diff(prev);
    if (diffs.isNotEmpty) {
      _log('State changed: ${diffs.join(', ')}');
    } else {
      _log('State touched (no change)');
    }
  }
}

class AuthEvent {
  final String message;
  final DateTime timestamp;
  AuthEvent({required this.message, required this.timestamp});
}

class AuthSnapshot {
  final bool authReady;
  final String? userId;
  final String? email;
  final String? role;
  final String? companyId;
  final DateTime timestamp;

  AuthSnapshot({
    required this.authReady,
    required this.userId,
    required this.email,
    required this.role,
    required this.companyId,
    required this.timestamp,
  });

  List<String> diff(AuthSnapshot other) {
    final changes = <String>[];
    if (authReady != other.authReady) changes.add('authReady: ${other.authReady} -> $authReady');
    if (userId != other.userId) changes.add('user: ${other.userId} -> $userId');
    if (email != other.email) changes.add('email: ${other.email} -> $email');
    if (role != other.role) changes.add('role: ${other.role} -> $role');
    if (companyId != other.companyId) changes.add('company_id: ${other.companyId} -> $companyId');
    return changes;
  }
}
