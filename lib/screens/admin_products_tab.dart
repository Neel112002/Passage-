import 'package:flutter/material.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/local_products_store.dart';
import 'package:passage/services/firebase_auth_service.dart';

class AdminProductsTab extends StatefulWidget {
  const AdminProductsTab({super.key});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  late Future<List<AdminProductModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminProductModel>> _load() async {
    await LocalProductsStore.ensureSeeded();
    return LocalProductsStore.loadAll();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _editProduct([AdminProductModel? initial]) async {
    final res = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => _ProductEditorSheet(initial: initial),
    );
    if (res == null) return;

    final now = DateTime.now();
    final model = AdminProductModel(
      id: initial?.id ?? 'ap_${DateTime.now().millisecondsSinceEpoch}',
      sellerId: FirebaseAuthService.currentUserId ?? '',
      name: res.name,
      description: res.description,
      price: res.price,
      imageUrl: res.imageUrl,
      imageUrls: res.gallery,
      rating: res.rating,
      tag: res.tag,
      category: res.category,
      stock: res.stock,
      isActive: res.isActive,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
    await LocalProductsStore.upsert(model);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(initial == null ? 'Product created' : 'Product updated')),
      );
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await LocalProductsStore.remove(id);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<AdminProductModel>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = List<AdminProductModel>.from(snap.data!);
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 48),
                Icon(Icons.inventory_2_outlined, size: 72, color: Colors.teal.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Center(child: Text('No products yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                const SizedBox(height: 6),
                Center(child: Text('Tap the + button to add your first product', style: theme.textTheme.bodySmall)),
              ],
            );
          }

          return Stack(
            children: [
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                itemBuilder: (context, index) {
                  final p = items[index];
                  return Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: (48 * MediaQuery.of(context).devicePixelRatio).round(),
                          cacheHeight: (48 * MediaQuery.of(context).devicePixelRatio).round(),
                          filterQuality: FilterQuality.low,
                          errorBuilder: (_, __, ___) => Image.asset('assets/icons/dreamflow_icon.jpg', width: 48, height: 48, fit: BoxFit.cover),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          _ActivePill(active: p.isActive),
                        ],
                      ),
                      subtitle: Text('${p.category} · Stock: ${p.stock} · ${p.tag}'),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (v) async {
                          switch (v) {
                            case 'edit':
                              _editProduct(p);
                              break;
                            case 'delete':
                              _delete(p.id);
                              break;
                            case 'toggle':
                              await LocalProductsStore.upsert(p.copyWith(isActive: !p.isActive));
                              _reload();
                              break;
                            case 'stock+':
                              await LocalProductsStore.upsert(p.copyWith(stock: p.stock + 1));
                              _reload();
                              break;
                            case 'stock-':
                              await LocalProductsStore.upsert(p.copyWith(stock: (p.stock - 1).clamp(0, 9999)));
                              _reload();
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
                          PopupMenuItem(value: 'toggle', child: ListTile(leading: Icon(Icons.visibility), title: Text('Toggle active'))),
                          PopupMenuItem(value: 'stock+', child: ListTile(leading: Icon(Icons.add), title: Text('Increase stock'))),
                          PopupMenuItem(value: 'stock-', child: ListTile(leading: Icon(Icons.remove), title: Text('Decrease stock'))),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete'))),
                        ],
                      ),
                      onTap: () => _editProduct(p),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: items.length,
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _editProduct(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

class _ActivePill extends StatelessWidget {
  final bool active;
  const _ActivePill({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.teal : Colors.grey;
    final label = active ? 'ACTIVE' : 'HIDDEN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ProductEditorSheet extends StatefulWidget {
  final AdminProductModel? initial;
  const _ProductEditorSheet({required this.initial});

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  late final TextEditingController _imageUrl;
  late final TextEditingController _gallery;
  late final TextEditingController _category;
  late final TextEditingController _tag;
  late int _stock;
  late double _rating;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _name = TextEditingController(text: i?.name ?? '');
    _desc = TextEditingController(text: i?.description ?? '');
    _price = TextEditingController(text: i != null ? i.price.toStringAsFixed(2) : '');
    _imageUrl = TextEditingController(text: i?.imageUrl ?? '');
    _gallery = TextEditingController(text: i != null ? i.imageUrls.join(', ') : '');
    _category = TextEditingController(text: i?.category ?? '');
    _tag = TextEditingController(text: i?.tag ?? '');
    _stock = i?.stock ?? 0;
    _rating = i?.rating ?? 0;
    _isActive = i?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _imageUrl.dispose();
    _gallery.dispose();
    _category.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.initial == null ? 'Add product' : 'Edit product',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.red),
                  )
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (USD)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tag,
                      decoration: const InputDecoration(labelText: 'Tag (e.g., Trending)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _imageUrl,
                      decoration: const InputDecoration(labelText: 'Primary image URL', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _gallery,
                decoration: const InputDecoration(
                  labelText: 'Gallery image URLs (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Stock', border: OutlineInputBorder()),
                      child: Row(
                        children: [
                          IconButton(onPressed: () => setState(() => _stock = (_stock - 1).clamp(0, 9999)), icon: const Icon(Icons.remove, color: Colors.red)),
                          Expanded(
                            child: Center(child: Text('$_stock', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                          ),
                          IconButton(onPressed: () => setState(() => _stock = _stock + 1), icon: const Icon(Icons.add, color: Colors.green)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Rating', border: OutlineInputBorder()),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _rating,
                              onChanged: (v) => setState(() => _rating = v),
                              divisions: 10,
                              min: 0,
                              max: 5,
                              label: _rating.toStringAsFixed(1),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(_rating.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                title: const Text('Active (visible in catalog)'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final desc = _desc.text.trim();
    final priceStr = _price.text.trim();
    final img = _imageUrl.text.trim();
    if (name.isEmpty || desc.isEmpty || priceStr.isEmpty || img.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, description, price and image URL')),
      );
      return;
    }
    final price = double.tryParse(priceStr) ?? -1;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }
    final gallery = _gallery.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    Navigator.pop(
      context,
      _EditResult(
        name: name,
        description: desc,
        price: price,
        imageUrl: img,
        gallery: gallery,
        rating: _rating,
        tag: _tag.text.trim(),
        category: _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
        stock: _stock,
        isActive: _isActive,
      ),
    );
  }
}

class _EditResult {
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final List<String> gallery;
  final double rating;
  final String tag;
  final String category;
  final int stock;
  final bool isActive;
  const _EditResult({
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.gallery,
    required this.rating,
    required this.tag,
    required this.category,
    required this.stock,
    required this.isActive,
  });
}
