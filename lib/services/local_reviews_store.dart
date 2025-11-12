import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/review.dart';

class LocalReviewsStore {
  static const String _key = 'product_reviews_v1';

  static Future<List<ProductReview>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return [];
    try {
      return ProductReview.decodeList(s);
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<ProductReview> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, ProductReview.encodeList(items));
  }

  static Future<List<ProductReview>> forProduct(String productId) async {
    final all = await _loadAll();
    return all.where((e) => e.productId == productId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> add(ProductReview review) async {
    final all = await _loadAll();
    all.add(review);
    await _saveAll(all);
  }

  static Future<void> remove(String reviewId) async {
    final all = await _loadAll();
    all.removeWhere((e) => e.id == reviewId);
    await _saveAll(all);
  }

  static Future<double> averageForProduct(String productId) async {
    final list = await forProduct(productId);
    if (list.isEmpty) return 0;
    final sum = list.fold<double>(0.0, (acc, e) => acc + e.rating);
    return sum / list.length;
  }

  static Future<int> countForProduct(String productId) async {
    final list = await forProduct(productId);
    return list.length;
  }
}
