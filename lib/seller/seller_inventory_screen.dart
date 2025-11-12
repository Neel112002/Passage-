import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/firestore_products_service.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/seller/seller_add_product_screen.dart';

class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({super.key});

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {

  Future<void> _toggleActive(AdminProductModel item, bool v) async {
    final updated = item.copyWith(isActive: v);
    await FirestoreProductsService.upsert(updated);
  }

  Future<void> _edit(AdminProductModel item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SellerAddProductScreen(existing: item)),
    );
    if (changed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product updated')));
    }
  }

  Future<void> _delete(AdminProductModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FirestoreProductsService.remove(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted')));
    }
  }

  Future<void> _adjustStock(AdminProductModel item) async {
    final controller = TextEditingController(text: item.stock.toString());
    final newVal = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.inventory_2_outlined), labelText: 'Stock quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim())), child: const Text('Save')),
        ],
      ),
    );
    if (newVal != null && newVal >= 0) {
      await FirestoreProductsService.upsert(item.copyWith(stock: newVal));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sellerId = FirebaseAuthService.currentUserId;
    if (sellerId == null || sellerId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Inventory'),
        actions: [
          IconButton(
            onPressed: () async {
              final count = await FirestoreProductsService.repairProductImageUrls(limit: 1000);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(count > 0 ? 'Repaired $count products' : 'No image URL repairs needed')),
              );
            },
            icon: const Icon(Icons.build_circle_outlined),
            tooltip: 'Repair image URLs',
          ),
          IconButton(
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const SellerAddProductScreen()),
              );
              if (created == true) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product added')));
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add product',
          ),
        ],
      ),
      body: StreamBuilder<List<AdminProductModel>>(
        // Use relaxed watcher to include legacy docs that may miss sellerId
        stream: FirestoreProductsService.watchBySellerRelaxed(sellerId, includeInactive: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Unable to load products. Please check your connection.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // Avoid spinner per request; show soft placeholder until first data
          if (!snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Loading products…', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ),
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.teal),
                  const SizedBox(height: 8),
                  Text('No products yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Tap + to add your first product', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _AnyImage.square56(url: item.imageUrl, fallbackColor: theme.colorScheme.surfaceVariant),
                  ),
                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text("${item.category.isNotEmpty ? '${item.category} · ' : ''}Stock: ${item.stock} · ${item.isActive ? 'Active' : 'Hidden'}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: item.isActive,
                        onChanged: (v) => _toggleActive(item, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                        tooltip: 'Edit',
                        onPressed: () => _edit(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
                        tooltip: 'Adjust stock',
                        onPressed: () => _adjustStock(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () => _delete(item),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _AnyImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? fallbackColor;
  const _AnyImage({required this.url, this.fit = BoxFit.cover, this.width, this.height, this.fallbackColor});

  factory _AnyImage.square56({required String url, Color? fallbackColor}) =>
      _AnyImage(url: url, width: 56, height: 56, fit: BoxFit.cover, fallbackColor: fallbackColor);

  bool get _isDataImage => url.startsWith('data:image');

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cw = width != null ? (width! * dpr).round() : null;
    final ch = height != null ? (height! * dpr).round() : null;
    if (_isDataImage) {
      try {
        final base64Part = url.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          cacheWidth: cw,
          cacheHeight: ch,
          filterQuality: FilterQuality.low,
        );
      } catch (_) {
        return Container(width: width, height: height, color: fallbackColor ?? Colors.black12);
      }
    }
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cw,
      cacheHeight: ch,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, __, ___) => Image.asset('assets/icons/dreamflow_icon.jpg', fit: fit, width: width, height: height),
    );
  }
}
