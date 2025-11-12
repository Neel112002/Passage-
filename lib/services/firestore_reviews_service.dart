import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:passage/models/review.dart';

class FirestoreReviewsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _reviewsRef = _firestore.collection('reviews');

  // Get reviews for a product
  static Future<List<ProductReview>> loadByProduct(String productId) async {
    try {
      final snapshot = await _reviewsRef
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => ProductReview.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      return <ProductReview>[];
    }
  }

  // Get reviews by user
  static Future<List<ProductReview>> loadByUser(String userId) async {
    try {
      final snapshot = await _reviewsRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snapshot.docs
          .map((doc) => ProductReview.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      return <ProductReview>[];
    }
  }

  // Add review
  static Future<void> add(ProductReview review) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated to add a review');

      final now = DateTime.now();
      final data = review.copyWith(
        userId: user.uid,
        createdAt: now,
        updatedAt: now,
      ).toMap();

      if (review.id.isEmpty) {
        final docRef = _reviewsRef.doc();
        data['id'] = docRef.id;
        await docRef.set(data);
      } else {
        await _reviewsRef.doc(review.id).set(data, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update review
  static Future<void> update(ProductReview review) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != review.userId) {
        throw Exception('Not authorized to update this review');
      }

      final data = review.copyWith(updatedAt: DateTime.now()).toMap();
      await _reviewsRef.doc(review.id).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // Delete review
  static Future<void> remove(String reviewId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final doc = await _reviewsRef.doc(reviewId).get();
      if (!doc.exists) return;

      final review = ProductReview.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      if (review.userId != user.uid) {
        throw Exception('Not authorized to delete this review');
      }

      await _reviewsRef.doc(reviewId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Listen to reviews for a product (real-time)
  static Stream<List<ProductReview>> watchByProduct(String productId) {
    return _reviewsRef
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductReview.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
            .toList());
  }

  // Calculate average rating for a product
  static Future<double> getAverageRating(String productId) async {
    try {
      final snapshot = await _reviewsRef
          .where('productId', isEqualTo: productId)
          .get();
      
      if (snapshot.docs.isEmpty) return 0.0;

      final ratings = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['rating'] as num?)
          .whereType<num>()
          .map((e) => e.toDouble())
          .toList();

      if (ratings.isEmpty) return 0.0;
      return ratings.reduce((a, b) => a + b) / ratings.length;
    } catch (e) {
      return 0.0;
    }
  }
}
