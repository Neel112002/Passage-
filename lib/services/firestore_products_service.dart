import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/firebase_storage_service.dart';
import 'package:passage/utils/url_fixes.dart';

class FirestoreProductsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _productsRef = _firestore.collection('products');

  // Get all active products
  static Future<List<AdminProductModel>> loadAll() async {
    try {
      // Avoid composite index by removing orderBy and sorting client-side
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .limit(100)
          .get();
      final items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return <AdminProductModel>[];
    }
  }

  // Get products by category
  static Future<List<AdminProductModel>> loadByCategory(String category) async {
    try {
      // Use single where and filter/sort client-side to avoid composite index
      final snapshot = await _productsRef
          .where('category', isEqualTo: category)
          .limit(100)
          .get();
      final items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .where((p) => p.isActive)
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return <AdminProductModel>[];
    }
  }

  // Get products by tag
  static Future<List<AdminProductModel>> loadByTag(String tag) async {
    try {
      // Use single where and filter/sort client-side to avoid composite index
      final snapshot = await _productsRef
          .where('tag', isEqualTo: tag)
          .limit(100)
          .get();
      final items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .where((p) => p.isActive)
          .toList();
      items.sort((a, b) => b.rating.compareTo(a.rating));
      return items;
    } catch (e) {
      return <AdminProductModel>[];
    }
  }

  // Get single product by ID
  static Future<AdminProductModel?> getById(String id) async {
    try {
      final doc = await _productsRef.doc(id).get();
      if (!doc.exists) return null;
      return AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
    } catch (e) {
      return null;
    }
  }

  // Create or update product. Returns the product id.
  // Optionally pass [storagePaths] aligned with product.imageUrls indices.
  static Future<String> upsert(AdminProductModel product, {List<String>? storagePaths}) async {
    try {
      final now = DateTime.now();
      // If product photos are disabled or empty, skip image validations entirely
      final bool hasImages = (product.imageUrls.isNotEmpty || product.imageUrl.trim().isNotEmpty);
      String primary = product.imageUrl;
      List<String> urls = List<String>.from(product.imageUrls);
      if (hasImages) {
        // Validate image URLs against expected bucket; if mismatch and storagePaths
        // are provided, re-fetch canonical download URLs from SDK.
        final expectedBucket = expectedStorageBucket();
        if (urls.isNotEmpty) {
          for (int i = 0; i < urls.length; i++) {
            final u = urls[i];
            if (!isValidFirebaseDownloadUrlForBucket(u, expectedBucket)) {
              if (storagePaths != null && i < storagePaths.length) {
                try {
                  urls[i] = await FirebaseStorageService.getDownloadUrlForPath(storagePaths[i]);
                } catch (_) {
                  // leave as is; mark for repair below
                }
              }
            }
          }
        }
        // Primary image aligns with first element
        primary = urls.isNotEmpty ? urls.first : product.imageUrl;
        if (!isValidFirebaseDownloadUrlForBucket(primary, expectedBucket) && storagePaths != null && storagePaths.isNotEmpty) {
          try {
            primary = await FirebaseStorageService.getDownloadUrlForPath(storagePaths.first);
          } catch (_) {}
        }
      }

      final data = product
          .copyWith(updatedAt: now, imageUrl: primary, imageUrls: urls)
          .toMap();
      if (storagePaths != null && storagePaths.isNotEmpty) {
        data['storagePaths'] = storagePaths;
      }
      if (hasImages) {
        // If any URL still invalid, set needsImageFix flag to true
        final expectedBucket = expectedStorageBucket();
        bool anyInvalid = false;
        for (final u in urls) {
          if (!isValidFirebaseDownloadUrlForBucket(u, expectedBucket)) { anyInvalid = true; break; }
        }
        if (!isValidFirebaseDownloadUrlForBucket(primary, expectedBucket)) anyInvalid = true;
        if (anyInvalid) data['needsImageFix'] = true;
      }
      if (product.id.isEmpty) {
        // Create new with auto-generated ID
        final docRef = _productsRef.doc();
        data['id'] = docRef.id;
        data['createdAt'] = Timestamp.fromDate(now);
        await docRef.set(data);
        return docRef.id;
      } else {
        // Update existing (ensure createdAt exists if this is a first write)
        final ref = _productsRef.doc(product.id);
        final snap = await ref.get();
        if (!snap.exists) {
          data['id'] = product.id;
          data['createdAt'] = Timestamp.fromDate(product.createdAt == DateTime(1970) ? now : product.createdAt);
        }
        await ref.set(data, SetOptions(merge: true));
        return product.id;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Return a new Firestore document id for products collection without writing.
  static String newDocId() {
    return _productsRef.doc().id;
  }

  /// One-time repair: For any product where imageUrls contain invalid entries or
  /// URLs that embed the wrong bucket (e.g., ".../v0/b/<...firebasestorage.app>/o/..."),
  /// re-fetch the canonical getDownloadURL using the expected storageBucket and
  /// overwrite. If unrecoverable, mark needsImageFix = true on the document.
  static Future<int> repairProductImageUrls({int limit = 500}) async {
    int updated = 0;
    try {
      final query = await _productsRef.limit(limit).get();
      final bucket = expectedStorageBucket();
      for (final doc in query.docs) {
        final map = doc.data() as Map<String, dynamic>;
        final dynamic arr = map['imageUrls'];
        if (arr is! List) continue;
        final List<dynamic> raw = List<dynamic>.from(arr);
        bool changed = false;
        final List<String> fixed = <String>[];
        for (final item in raw) {
          final s = (item ?? '').toString();
          if (s.isEmpty) continue;
          if (s.startsWith('products/')) {
            // Attempt to recover via Storage path
            try {
              final url = await FirebaseStorageService.getDownloadUrlForPath(s);
              fixed.add(url);
              changed = true;
            } catch (_) {
              // Can't recover this path
              changed = true;
            }
          } else if (isWrongFirebasestorageAppBucketUrl(s)) {
            // Parse object path from bad URL and re-fetch using expected bucket
            try {
              final obj = parseStorageObjectPathFromDownloadUrl(s);
              if (obj != null && obj.isNotEmpty) {
                final url = await FirebaseStorageService.getDownloadUrlForPath(obj);
                fixed.add(url);
                changed = true;
              } else {
                fixed.add(s);
              }
            } catch (_) {
              fixed.add(s);
            }
          } else {
            fixed.add(s);
          }
        }
        // Also check primary imageUrl field if present
        String? primary = (map['imageUrl'] as String?)?.trim();
        if ((primary ?? '').startsWith('products/')) {
          try {
            final url = await FirebaseStorageService.getDownloadUrlForPath(primary!);
            primary = url;
            changed = true;
          } catch (_) {
            changed = true;
          }
        } else if (primary != null && isWrongFirebasestorageAppBucketUrl(primary)) {
          try {
            final obj = parseStorageObjectPathFromDownloadUrl(primary);
            if (obj != null && obj.isNotEmpty) {
              primary = await FirebaseStorageService.getDownloadUrlForPath(obj);
              changed = true;
            }
          } catch (_) {}
        }
        // Validate URLs pattern; mark needsImageFix if any invalid remain
        bool anyInvalid = false;
        for (final u in fixed) {
          if (!isValidFirebaseDownloadUrlForBucket(u, bucket)) {
            anyInvalid = true; break;
          }
        }
        if (primary != null && primary.isNotEmpty && !isValidFirebaseDownloadUrlForBucket(primary, bucket)) {
          anyInvalid = true;
        }
        // Ensure primary equals first
        if (fixed.isNotEmpty) {
          primary = fixed.first;
        }
        if (changed || anyInvalid) {
          final update = <String, dynamic>{
            'imageUrls': fixed,
          };
          if (primary != null && primary.isNotEmpty) {
            update['imageUrl'] = primary;
          }
          if (anyInvalid) update['needsImageFix'] = true;
          await doc.reference.set(update, SetOptions(merge: true));
          updated++;
        }
      }
    } catch (_) {
      // swallow errors per admin action semantics; return best-effort count
    }
    return updated;
  }

  // Delete product
  static Future<void> remove(String id) async {
    try {
      await _productsRef.doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Search products by name
  static Future<List<AdminProductModel>> search(String query) async {
    try {
      // Fallback search: fetch a page and filter client-side to avoid composite index
      final snapshot = await _productsRef
          .where('isActive', isEqualTo: true)
          .limit(200)
          .get();
      final q = query.trim().toLowerCase();
      final items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q) || p.tag.toLowerCase().contains(q))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return <AdminProductModel>[];
    }
  }

  // Listen to product changes (real-time)
  static Stream<List<AdminProductModel>> watchAll() {
    return _productsRef
        .where('isActive', isEqualTo: true)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  // Live products for a seller (optionally include inactive)
  static Stream<List<AdminProductModel>> watchBySeller(String sellerId, {bool includeInactive = true}) {
    Query query = _productsRef.where('sellerId', isEqualTo: sellerId).limit(400);
    return query.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      if (!includeInactive) {
        items = items.where((p) => p.isActive).toList();
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  // More tolerant stream: loads a page of products and then filters by sellerId in
  // memory. This also surfaces products that are missing sellerId (legacy docs),
  // so sellers can still see their items after we migrate data.
  static Stream<List<AdminProductModel>> watchBySellerRelaxed(String sellerId, {bool includeInactive = true}) {
    return _productsRef.limit(400).snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => AdminProductModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .where((p) => p.sellerId == sellerId || p.sellerId.isEmpty)
          .toList();
      if (!includeInactive) {
        items = items.where((p) => p.isActive).toList();
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  // Seed sample data (for initial setup)
  static Future<void> seedSampleData() async {
    try {
      final existing = await loadAll();
      if (existing.isNotEmpty) return;

      final now = DateTime.now();
      final samples = [
        AdminProductModel(
          id: '',
          sellerId: '',
          name: 'AirFlex Sneakers',
          description: 'Comfort meets performance. Breathable mesh, cushioned sole, and urban style.',
          price: 89.99,
          imageUrl: 'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800&h=800&fit=crop',
          imageUrls: const [
            'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1519741497674-611481863552?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=800&h=800&fit=crop',
          ],
          rating: 4.6,
          tag: 'Trending',
          category: 'Fashion',
          stock: 24,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        AdminProductModel(
          id: '',
          sellerId: '',
          name: 'Sonic Pro Headphones',
          description: 'Immersive sound with active noise cancelling. Long battery life.',
          price: 129.00,
          imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&h=800&fit=crop',
          imageUrls: const [
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&h=800&fit=crop',
            'https://images.unsplash.com/photo-1518444083365-5c708ae3d41c?w=800&h=800&fit=crop',
          ],
          rating: 4.8,
          tag: 'Best Seller',
          category: 'Electronics',
          stock: 12,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        AdminProductModel(
          id: '',
          sellerId: '',
          name: 'Urban Leather Backpack',
          description: 'Premium leather, padded laptop sleeve, and everyday durability.',
          price: 69.90,
          imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&h=800&fit=crop',
          imageUrls: const [
            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&h=800&fit=crop',
          ],
          rating: 4.3,
          tag: 'Limited',
          category: 'Fashion',
          stock: 40,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      for (final product in samples) {
        await upsert(product);
      }
    } catch (e) {
      // Ignore errors during seeding
    }
  }
}
