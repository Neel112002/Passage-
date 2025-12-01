import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:passage/services/firestore_user_profile_service.dart';
import 'package:passage/services/local_user_profile_store.dart';
import 'package:passage/models/user_profile.dart';

class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Pending link flow support: when Google sign-in hits
  // account-exists-with-different-credential, we store the
  // credential & email here and attempt linking after the user
  // signs-in using the existing provider.
  static AuthCredential? pendingLinkCredential;
  static String? pendingLinkEmail;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  static Future<User?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null && displayName != null) {
        await credential.user!.updateDisplayName(displayName);
      }

      // Create initial user profile in Firestore
      await FirestoreUserProfileService.createInitialProfile(
        email: email,
        displayName: displayName,
      );

      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Let callers inspect code/message
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  static Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google (web: popup with redirect fallback; mobile: provider)
  static Future<User?> signInWithGoogle() async {
    try {
      UserCredential credential;

      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});

      if (kIsWeb) {
        try {
          // Prefer popup on web
          credential = await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          // Fallback to redirect in environments where popups are blocked/closed/unsupported
          // Common web codes: popup-blocked, popup-closed-by-user, cancelled-popup-request,
          // operation-not-supported-in-this-environment, web-storage-unsupported
          if (e.code == 'popup-blocked' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request' ||
              e.code == 'operation-not-supported-in-this-environment' ||
              e.code == 'web-storage-unsupported') {
            await _auth.signInWithRedirect(provider);
            // The page will navigate away; no result to return
            return null;
          }
          // Re-throw for higher-level handling (including account-exists)
          rethrow;
        }
      } else {
        // On mobile & desktop (non-web), use the provider sign-in
        credential = await _auth.signInWithProvider(provider);
      }

      final user = credential.user;
      if (user != null) {
        // Ensure Firestore profile exists
        await FirestoreUserProfileService.createInitialProfile(
          email: user.email ?? '',
          displayName: user.displayName,
          avatarUrl: user.photoURL,
        );

        // Also hydrate the local profile cache so the Home/Profile UI
        // reflects the Google display name & email immediately.
        try {
          final now = DateTime.now();
          final profile = UserProfile(
            fullName: (user.displayName ?? '').trim().isEmpty
                ? (user.email ?? '').split('@').first
                : user.displayName!.trim(),
            username: (user.email ?? '').split('@').first,
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
            bio: '',
            gender: '',
            dob: null,
            avatarUrl: user.photoURL ?? '',
            createdAt: now,
            updatedAt: now,
          );
          await LocalUserProfileStore.save(profile);
        } catch (_) {
          // Local cache issues shouldn't break login; ignore.
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      // Special handling for different-credential case: capture pending credential & email
      if (e.code == 'account-exists-with-different-credential') {
        final email = e.email;
        final cred = e.credential;
        if (email != null && cred != null) {
          pendingLinkEmail = email.toLowerCase();
          pendingLinkCredential = cred;
        }
        // Attempt to fetch existing methods to help UI; if unavailable, default to password
        final methods = <String>['password'];
        throw AccountExistsWithDifferentCredentialException(
          email: email ?? '',
          providers: methods,
          originalCode: e.code,
          originalMessage: e.message ?? 'Account exists with different credential',
        );
      }

      // Surface original error with code/message so UI can toast exactly
      rethrow;
    }
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Update email (Note: requires recent login)
  static Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Use verifyBeforeUpdateEmail for safer email updates
      await user.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Update password
  static Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Re-authenticate user (required before sensitive operations)
  static Future<void> reauthenticate({
    required String email,
    required String password,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // Delete user profile from Firestore
      await FirestoreUserProfileService.delete();

      // Delete auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw e;
    } catch (e) {
      rethrow;
    }
  }

  // Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      rethrow;
    }
  }

  // Check if email is verified
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  // Reload user data
  static Future<void> reloadUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');
      await user.reload();
    } catch (e) {
      rethrow;
    }
  }
}

// Exception used by the UI to guide sign-in when the account exists with a different credential.
class AccountExistsWithDifferentCredentialException implements Exception {
  final String email;
  final List<String> providers;
  final String originalCode;
  final String originalMessage;
  AccountExistsWithDifferentCredentialException({
    required this.email,
    required this.providers,
    required this.originalCode,
    required this.originalMessage,
  });
  @override
  String toString() =>
      '[${originalCode}] '+originalMessage+' (email: '+email+', providers: '+providers.join(',')+')';
}
