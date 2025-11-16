import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/services/firestore_products_service.dart';
import 'seller_product_form_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  StreamSubscription<List<AdminProductModel>>? _sub;
  List<AdminProductModel> _items = <AdminProductModel>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuthService.currentUserId;
    if (uid == null || uid.isEmpty) {
      setState(() {
        _items = <AdminProductModel>[];
        _loading = false;
      });
      return;
    }
    _sub = FirestoreProductsService.watchBySeller(uid).listen((list) {
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    }, onError: (e, st) {
      debugPrint('SellerDashboard watch error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SellerProductFormScreen()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product added')));
    }
  }

  Future<void> _openEdit(AdminProductModel p) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SellerProductFormScreen(existing: p)),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product updated')));
    }
  }

  Future<void> _delete(AdminProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('This will remove “${p.name}”.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await FirestoreProductsService.remove(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Deleted')));
        }
      } catch (e) {
        debugPrint('Delete failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
            tooltip: 'Add product',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add product'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? _emptyState(theme)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemBuilder: (context, index) {
                      final p = _items[index];
                      return _ProductRow(
                        product: p,
                        onEdit: () => _openEdit(p),
                        onDelete: () => _delete(p),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: _items.length,
                  ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text('No products yet', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Tap “Add product” to publish your first item.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add product'),
            )
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final AdminProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ProductRow({required this.product, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _AnyImage(url: product.imageUrls.isNotEmpty ? product.imageUrls.first : product.imageUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(product.category, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('\$${product.price.toStringAsFixed(2)}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 12),
                      Icon(
                        product.isActive ? Icons.visibility : Icons.visibility_off,
                        size: 16,
                        color: product.isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 6),
                      Text(product.isActive ? 'Active' : 'Hidden', style: theme.textTheme.labelSmall),
                      if ((product.videoUrl).isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.videocam, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('Video', style: theme.textTheme.labelSmall),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  tooltip: 'Delete',
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _AnyImage extends StatelessWidget {
  final String url;
  const _AnyImage({required this.url});
  @override
  Widget build(BuildContext context) {
    final src = url.trim();
    if (src.startsWith('data:image')) {
      try {
        final base64Part = src.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return Image.asset('assets/icons/dreamflow_icon.jpg', fit: BoxFit.cover);
      }
    }
    return Image.network(src, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
      return Image.asset('assets/icons/dreamflow_icon.jpg', fit: BoxFit.cover);
    });
  }
}
