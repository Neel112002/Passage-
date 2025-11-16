import 'package:shared_preferences/shared_preferences.dart';
import 'package:passage/models/product.dart';

class LocalProductsStore {
  static const String _key = 'products_v1';

  static Future<List<AdminProductModel>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null || s.isEmpty) return <AdminProductModel>[];
    try {
      return AdminProductModel.decodeList(s);
    } catch (_) {
      return <AdminProductModel>[];
    }
  }

  static Future<void> saveAll(List<AdminProductModel> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, AdminProductModel.encodeList(items));
  }

  static Future<void> upsert(AdminProductModel item) async {
    final items = await loadAll();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item); // newest first
    }
    await saveAll(items);
  }

  static Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((e) => e.id == id);
    await saveAll(items);
  }

  static Future<void> ensureSeeded() async {
    final existing = await loadAll();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final samples = <AdminProductModel>[
      AdminProductModel(
        id: 'ap1',
        sellerId: '',
        name: 'AirFlex Sneakers',
        description:
            'Comfort meets performance. Breathable mesh, cushioned sole, and urban style.',
        price: 89.99,
        imageUrl:
            'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=800&h=800&fit=crop',
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
        id: 'ap2',
        sellerId: '',
        name: 'Sonic Pro Headphones',
        description:
            'Immersive sound with active noise cancelling. Long battery life.',
        price: 129.00,
        imageUrl:
            'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800&h=800&fit=crop',
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
        id: 'ap3',
        sellerId: '',
        name: 'Urban Leather Backpack',
        description:
            'Premium leather, padded laptop sleeve, and everyday durability.',
        price: 69.90,
        imageUrl:
            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=800&h=800&fit=crop',
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

    await saveAll(samples);
  }
}
