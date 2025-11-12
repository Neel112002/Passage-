import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:passage/models/user_profile.dart';

class FirestoreUserProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _usersRef = _firestore.collection('users');

  // Get current user's profile
  static Future<UserProfile?> load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _usersRef.doc(user.uid).get();
      if (!doc.exists) return null;

      return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Get profile by user ID
  static Future<UserProfile?> getById(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get();
      if (!doc.exists) return null;

      return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  // Save current user's profile
  static Future<void> save(UserProfile profile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final now = DateTime.now();
      final doc = await _usersRef.doc(user.uid).get();
      
      final data = profile.copyWith(
        updatedAt: now,
        createdAt: doc.exists ? null : now,
      ).toMap();

      await _usersRef.doc(user.uid).set(data, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // Update specific fields
  static Future<void> updateFields(Map<String, dynamic> fields) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      fields['updatedAt'] = Timestamp.fromDate(DateTime.now());
      await _usersRef.doc(user.uid).update(fields);
    } catch (e) {
      rethrow;
    }
  }

  // Delete current user's profile
  static Future<void> delete() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      await _usersRef.doc(user.uid).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Listen to current user's profile (real-time)
  static Stream<UserProfile?> watch() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return _usersRef.doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  // Create initial profile for new user
  static Future<void> createInitialProfile({
    required String email,
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final doc = await _usersRef.doc(user.uid).get();
      if (doc.exists) return; // Profile already exists

      final now = DateTime.now();
      final profile = UserProfile(
        fullName: displayName ?? '',
        username: email.split('@').first,
        email: email,
        phone: '',
        bio: '',
        gender: '',
        dob: null,
        avatarUrl: avatarUrl ?? '',
        createdAt: now,
        updatedAt: now,
      );

      await _usersRef.doc(user.uid).set(profile.toMap());
    } catch (e) {
      rethrow;
    }
  }
}
