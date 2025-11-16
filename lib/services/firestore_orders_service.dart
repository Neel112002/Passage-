import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:passage/models/order.dart';
import 'package:passage/services/firestore_products_service.dart';

class FirestoreOrdersService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final CollectionReference _ordersRef = _firestore.collection('orders');

  // Get all orders for current user
  static Future<List<OrderItemModel>> loadAll() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return <OrderItemModel>[];

      final snapshot = await _ordersRef
          .where('userId', isEqualTo: user.uid)
          .limit(200)
          .get();
      final items = snapshot.docs
          .map((doc) => OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return <OrderItemModel>[];
    }
  }

  // Get orders by status
  static Future<List<OrderItemModel>> loadByStatus(OrderStatus status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return <OrderItemModel>[];

      final snapshot = await _ordersRef
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: _statusToString(status))
          .limit(200)
          .get();
      final items = snapshot.docs
          .map((doc) => OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      return <OrderItemModel>[];
    }
  }

  // Get single order by ID
  static Future<OrderItemModel?> getById(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _ordersRef.doc(id).get();
      if (!doc.exists) return null;

      final order = OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      if (order.userId != user.uid) return null; // Not authorized

      return order;
    } catch (e) {
      return null;
    }
  }

  // Create new order
  static Future<String?> create(OrderItemModel order) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated to create an order');

      final now = DateTime.now();
      final docRef = _ordersRef.doc();
      final data = order.copyWith(
        id: docRef.id,
        userId: user.uid,
        createdAt: now,
        updatedAt: now,
      ).toMap();

      // Derive sellerIds from line items' products
      final sellerIds = <String>{};
      for (final li in order.items) {
        final p = await FirestoreProductsService.getById(li.productId);
        if (p != null && p.sellerId.isNotEmpty) sellerIds.add(p.sellerId);
      }
      data['sellerIds'] = sellerIds.toList();

      await docRef.set(data);
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // Update order status
  static Future<void> updateStatus(String orderId, OrderStatus newStatus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final doc = await _ordersRef.doc(orderId).get();
      if (!doc.exists) throw Exception('Order not found');

      final order = OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      if (order.userId != user.uid) throw Exception('Not authorized');

      await _ordersRef.doc(orderId).update({
        'status': _statusToString(newStatus),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete order
  static Future<void> remove(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User must be authenticated');

      final doc = await _ordersRef.doc(id).get();
      if (!doc.exists) return;

      final order = OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id});
      if (order.userId != user.uid) throw Exception('Not authorized');

      await _ordersRef.doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Listen to user's orders (real-time)
  static Stream<List<OrderItemModel>> watchAll() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(<OrderItemModel>[]);

    return _ordersRef
        .where('userId', isEqualTo: user.uid)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  // Seller-facing: Live orders where this seller is involved
  static Stream<List<OrderItemModel>> watchBySeller(String sellerId) {
    if (sellerId.isEmpty) return Stream.value(<OrderItemModel>[]);
    return _ordersRef
        .where('sellerIds', arrayContains: sellerId)
        .limit(200)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => OrderItemModel.fromMap({...doc.data() as Map<String, dynamic>, 'id': doc.id}))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  // Seller-facing: update order status (no user ownership check)
  static Future<void> updateStatusBySeller(String orderId, OrderStatus newStatus) async {
    try {
      await _ordersRef.doc(orderId).update({
        'status': _statusToString(newStatus),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Seller-facing: update tracking number
  static Future<void> updateTrackingBySeller(String orderId, String tracking) async {
    try {
      await _ordersRef.doc(orderId).update({
        'trackingNumber': tracking,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      rethrow;
    }
  }

  static String _statusToString(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.shipped:
        return 'shipped';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }
}
