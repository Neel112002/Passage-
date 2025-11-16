import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/services/firestore_products_service.dart';

class SellerProductFormScreen extends StatefulWidget {
  const SellerProductFormScreen({super.key, this.existing});
  final AdminProductModel? existing;

  @override
  State<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  static const List<String> _categoryOptions = <String>[
    'Electronics',
    'Fashion',
    'Home & Living',
    'Books',
    'Beauty',
    'Sports',
    'Toys',
    'Vehicles',
    'Services',
    'Others',
  ];
  String _category = 'Others';
  final _stockCtrl = TextEditingController(text: '1');
  final _descCtrl = TextEditingController();
  final _campusCtrl = TextEditingController();
  final _pickupLocationCtrl = TextEditingController();

  bool _isActive = true;
  bool _pickupOnly = true;
  bool _negotiable = false;
  String _condition = 'Good';

  final List<String> _images = <String>[]; // data urls
  String? _videoDataUrl; // optional video as data URL
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.price.toStringAsFixed(2);
      _category = (p.category.isNotEmpty ? p.category : 'Others');
      _stockCtrl.text = p.stock.toString();
      _descCtrl.text = p.description;
      _isActive = p.isActive;
      _pickupOnly = p.pickupOnly;
      _negotiable = p.negotiable;
      _condition = p.condition.isNotEmpty ? p.condition : 'Good';
      _campusCtrl.text = p.campus;
      _pickupLocationCtrl.text = p.pickupLocation;
      _images.addAll(p.imageUrls.isNotEmpty ? p.imageUrls : (p.imageUrl.isNotEmpty ? [p.imageUrl] : const []));
      _videoDataUrl = p.videoUrl.isNotEmpty ? p.videoUrl : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    // No controllers for category or tag anymore
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _campusCtrl.dispose();
    _pickupLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1600);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final mime = _inferMime(bytes) ?? 'image/jpeg';
      final dataUrl = 'data:$mime;base64,' + base64Encode(bytes);
      setState(() => _images.add(dataUrl));
    } catch (e) {
      debugPrint('Pick image failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      // Firestore document limit is ~1 MiB; keep well under to allow other fields
      const int maxBytes = 900 * 1024; // 900KB budget
      if (bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video too large for database (max ~900KB).')));
        return;
      }
      // Assume mp4 if extension ends with .mp4, otherwise default to mp4
      final lower = (xfile.path).toLowerCase();
      final mime = lower.endsWith('.webm')
          ? 'video/webm'
          : (lower.endsWith('.mov') ? 'video/quicktime' : 'video/mp4');
      final dataUrl = 'data:$mime;base64,' + base64Encode(bytes);
      setState(() => _videoDataUrl = dataUrl);
    } catch (e) {
      debugPrint('Pick video failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick video')));
    }
  }

  String? _inferMime(Uint8List bytes) {
    if (bytes.length >= 4) {
      // PNG
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'image/png';
      // JPG
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      // GIF
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
      // WEBP (RIFF....WEBP)
      if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'image/webp';
    }
    return null;
  }

  Future<void> _save() async {
    final uid = FirebaseAuthService.currentUserId;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be signed in')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final id = widget.existing?.id ?? '';
      final product = AdminProductModel(
        id: id,
        sellerId: uid,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        imageUrl: _images.isNotEmpty ? _images.first : '',
        imageUrls: List<String>.from(_images),
        rating: widget.existing?.rating ?? 0,
        tag: '',
        category: _category.isEmpty ? 'Others' : _category,
        stock: int.tryParse(_stockCtrl.text.trim()) ?? 0,
        isActive: _isActive,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
        condition: _condition,
        campus: _campusCtrl.text.trim(),
        pickupOnly: _pickupOnly,
        pickupLocation: _pickupLocationCtrl.text.trim(),
        negotiable: _negotiable,
        videoUrl: _videoDataUrl ?? '',
      );

      await FirestoreProductsService.upsert(product);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save product failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primary,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'Basic info',
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Product name',
                                prefixIcon: Icon(Icons.drive_file_rename_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Price',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              validator: (v) {
                                final d = double.tryParse((v ?? '').trim());
                                if (d == null || d < 0) return 'Enter a valid price';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _category.isEmpty ? 'Others' : _category,
                              items: _categoryOptions
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
                              onChanged: (v) => setState(() => _category = v ?? 'Others'),
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                prefixIcon: Icon(Icons.grid_view_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _stockCtrl,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                              validator: (v) {
                                final i = int.tryParse((v ?? '').trim());
                                if (i == null || i < 0) return 'Enter stock';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descCtrl,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                prefixIcon: Icon(Icons.description_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Media',
                          children: [
                            Text('Photos', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (int i = 0; i < _images.length; i++) _imageThumb(i),
                                  _addImageTile(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Video (optional)', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            _videoTile(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: 'Selling preferences',
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _condition,
                                    items: const [
                                      DropdownMenuItem(value: 'New', child: Text('New')),
                                      DropdownMenuItem(value: 'Like New', child: Text('Like New')),
                                      DropdownMenuItem(value: 'Good', child: Text('Good')),
                                      DropdownMenuItem(value: 'Fair', child: Text('Fair')),
                                      DropdownMenuItem(value: 'For Parts', child: Text('For Parts')),
                                    ],
                                    onChanged: (v) => setState(() => _condition = v ?? 'Good'),
                                    decoration: const InputDecoration(
                                      labelText: 'Condition',
                                      prefixIcon: Icon(Icons.fact_check_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _SwitchTile(
                                    title: 'Active',
                                    subtitle: 'Visible in catalog',
                                    value: _isActive,
                                    onChanged: (v) => setState(() => _isActive = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _SwitchTile(
                              title: 'Local pickup only',
                              value: _pickupOnly,
                              onChanged: (v) => setState(() => _pickupOnly = v),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _campusCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Campus / Community',
                                      prefixIcon: Icon(Icons.school_outlined),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _pickupLocationCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Pickup location',
                                      prefixIcon: Icon(Icons.place_outlined),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _SwitchTile(
                              title: 'Price negotiable',
                              value: _negotiable,
                              onChanged: (v) => setState(() => _negotiable = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.inversePrimary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(isEdit ? 'Save changes' : 'Publish product',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addImageTile() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
        ),
        child: Center(
          child: Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  Widget _imageThumb(int index) {
    final src = _images[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 100,
            height: 100,
            child: _AnyImage(url: src),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black.withValues(alpha: 0.4),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _images.removeAt(index)),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoTile() {
    final border = Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2));
    if (_videoDataUrl == null || _videoDataUrl!.isEmpty) {
      return InkWell(
        onTap: _pickVideo,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.video_call_outlined, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Add video'),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      child: Row(
        children: [
          Icon(Icons.play_circle_fill, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Video attached',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _videoDataUrl = null),
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            label: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: SwitchListTile.adaptive(
        dense: true,
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
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
