import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:passage/models/product.dart';
import 'package:passage/models/reel_item.dart';
import 'package:passage/services/firestore_products_service.dart';
import 'package:passage/services/firebase_storage_service.dart';
import 'package:passage/services/local_reels_store.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'package:passage/utils/url_fixes.dart';

class SellerAddProductScreen extends StatefulWidget {
  final AdminProductModel? existing;
  const SellerAddProductScreen({super.key, this.existing});

  @override
  State<SellerAddProductScreen> createState() => _SellerAddProductScreenState();
}

class _SellerAddProductScreenState extends State<SellerAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _uploading = false;

  // Base options for student second-hand marketplace
  static const List<String> _baseCategories = <String>[
    'Books', 'Electronics', 'Furniture', 'Dorm & Essentials', 'Bikes', 'Fashion', 'Others'
  ];
  static const List<String> _baseTags = <String>[
    'Trending', 'Best Seller', 'New', 'Limited', 'Hot', 'Featured', 'Pro', 'Seasonal', 'Popular', 'Artisan', 'Official'
  ];

  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _price = TextEditingController(text: widget.existing != null ? widget.existing!.price.toStringAsFixed(2) : '');
  late final TextEditingController _stock = TextEditingController(text: widget.existing != null ? widget.existing!.stock.toString() : '');

  // Dropdown selections
  String? _selectedCategory;
  String? _selectedTag; // allow null/empty for optional tag

  // Marketplace fields
  static const List<String> _conditions = <String>['New', 'Like New', 'Good', 'Fair', 'For Parts'];
  String? _selectedCondition;
  late final TextEditingController _pickupLocation = TextEditingController(text: '');
  bool _negotiable = false;
  bool _pickupOnly = true; // campus local pickup by default

  double _rating = 0;
  bool _isActive = true;

  // Picked product photos (support existing URLs and newly picked bytes)
  final List<_Photo> _photos = <_Photo>[];
  // Collected validated Firebase download URLs for publishing
  final List<String> _downloadUrls = <String>[];
  // Optional Storage object paths for each uploaded image
  final List<String> _storagePaths = <String>[];
  // Picked reel videos (bytes only)
  final List<_Video> _videos = <_Video>[];

  // Pre-allocated listing id so we can place uploads under a stable folder
  late final String _listingId;

  @override
  void initState() {
    super.initState();
    _isActive = widget.existing?.isActive ?? true;
    _rating = widget.existing?.rating ?? 0;

    _selectedCategory = (widget.existing?.category ?? '').trim().isEmpty ? null : widget.existing!.category;
    _selectedTag = (widget.existing?.tag ?? '').trim().isEmpty ? null : widget.existing!.tag;

    // Preload listing id
    _listingId = (widget.existing?.id ?? '').isNotEmpty
        ? widget.existing!.id
        : FirestoreProductsService.newDocId();

    // Preload existing images as remote photos and seed download URLs if valid
    final existing = widget.existing;
    if (existing != null) {
      final urls = existing.imageUrls.isNotEmpty ? existing.imageUrls : [existing.imageUrl].where((e) => e.isNotEmpty).toList();
      for (final u in urls) {
        _photos.add(_Photo.remote(u));
        final fixed = fixFirebaseDownloadUrl(u);
        if (isValidFirebaseDownloadUrl(fixed)) {
          _downloadUrls.add(fixed);
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _stock.dispose();
    _pickupLocation.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    try {
      final List<XFile> files = await picker.pickMultiImage(
        imageQuality: 90,
        maxWidth: 2048,
      );
      if (files.isEmpty) return;
      setState(() => _uploading = true);
      final sellerId = FirebaseAuthService.currentUserId;
      if (sellerId == null || sellerId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to continue')));
        }
        setState(() => _uploading = false);
        return;
      }
      // Upload all selected files in parallel and append as remote photos
      final futures = <Future<void>>[];
      for (int i = 0; i < files.length; i++) {
        final x = files[i];
        futures.add((() async {
          // ignore: avoid_print
          print('PickImages: start index='+i.toString()+' name='+x.name);
          final bytes = await x.readAsBytes();
          if (bytes.isEmpty) return;
          final name = x.name;
          final ext = name.contains('.') ? name.split('.').last : 'jpg';
          try {
            final uploaded = await FirebaseStorageService.uploadProductImage(
              bytes,
              sellerId: sellerId,
              listingId: _listingId,
              index: _photos.length + i,
              extension: ext,
            );
            if (!mounted) return;
            setState(() {
              // Use fixed URL for preview if needed, store canonical in _downloadUrls
              _photos.add(_Photo.remote(fixFirebaseDownloadUrl(uploaded.downloadUrl)));
              _downloadUrls.add(uploaded.downloadUrl);
              _storagePaths.add(uploaded.path);
            });
            // ignore: avoid_print
            print('PickImages: success index='+i.toString()+' url='+uploaded.downloadUrl);
          } catch (e) {
            if (!mounted) return;
            // ignore: avoid_print
            print('PickImages: failed index='+i.toString()+' error='+e.toString());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload an image: $e')),
            );
          }
        })());
      }
      try {
        // Add a watchdog so UI never stays stuck if an upload stalls unexpectedly.
        await Future.wait(futures).timeout(const Duration(seconds: 75), onTimeout: () async {
          // ignore: avoid_print
          print('PickImages: overall timeout waiting for uploads');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image upload is taking too long. Some uploads may have failed.')),
            );
          }
          // Allow the UI to recover; continue to finally{} which clears _uploading
          // and keep any images that did complete.
          return const <void>[]; // satisfy Future<List<void>> expectation
        });
      } finally {
        if (!mounted) return;
        setState(() => _uploading = false);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    }
  }

  Future<void> _pickVideos() async {
    final picker = ImagePicker();
    try {
      if (kIsWeb) {
        // ImagePicker for web does not reliably support video selection in all environments
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video upload not supported on web in this build.')));
        return;
      }
      // Try multiple selection where supported
      List<XFile> files = const [];
      try {
        files = await picker.pickMultipleMedia();
        // Keep only videos
        files = files.where((x) {
          final n = x.name.toLowerCase();
          return n.endsWith('.mp4') || n.endsWith('.mov') || n.endsWith('.webm') || n.endsWith('.mkv');
        }).toList();
      } catch (_) {
        // Fallback to single video
        final single = await picker.pickVideo(source: ImageSource.gallery);
        if (single != null) files = [single];
      }
      if (files.isEmpty) return;
      final additions = <_Video>[];
      for (final x in files) {
        final bytes = await x.readAsBytes();
        final name = x.name.toLowerCase();
        final ext = name.contains('.') ? name.split('.').last : 'mp4';
        final mime = _guessVideoMime(ext);
        if (bytes.isNotEmpty) additions.add(_Video(bytes: bytes, extension: ext, mimeType: mime));
      }
      if (!mounted) return;
      setState(() => _videos.addAll(additions));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick videos')));
    }
  }

  String _guessImageMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      default:
        return 'image/jpeg';
    }
  }

  String _guessVideoMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp4':
      default:
        return 'video/mp4';
    }
  }

  List<String> get _categories {
    final list = <String>{..._baseCategories};
    final c = widget.existing?.category ?? '';
    if (c.trim().isNotEmpty) list.add(c);
    return list.toList()..sort();
  }

  List<String> get _tags {
    final list = <String>{..._baseTags};
    final t = widget.existing?.tag ?? '';
    if (t.trim().isNotEmpty) list.add(t);
    return list.toList()..sort();
  }

  bool get _canPublish => !_saving && !_uploading && _downloadUrls.isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final price = double.tryParse(_price.text.trim()) ?? 0;
    final stock = int.tryParse(_stock.text.trim()) ?? 0;

    // Require at least one uploaded image download URL
    if (_downloadUrls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add and upload at least one product photo')));
      }
      return;
    }

    // Ensure all URLs are valid and match the exact storage bucket
    final expectedBucket = expectedStorageBucket();
    final List<String> urls = List<String>.from(_downloadUrls);
    for (int i = 0; i < urls.length; i++) {
      final u = urls[i];
      if (!isValidFirebaseDownloadUrlForBucket(u, expectedBucket)) {
        if (i < _storagePaths.length) {
          try {
            final refreshed = await FirebaseStorageService.getDownloadUrlForPath(_storagePaths[i]);
            urls[i] = refreshed;
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL invalid. Please retry upload.')));
            }
            return;
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image URL invalid. Please retry upload.')));
          }
          return;
        }
      }
    }

    setState(() => _saving = true);
    final String primaryImage = urls.first;

    final now = DateTime.now();
    // Best-effort campus from auth email domain
    String campus = '';
    try {
      final email = FirebaseAuthService.currentUser?.email ?? '';
      if (email.contains('@')) campus = email.split('@').last.trim().toLowerCase();
    } catch (_) {}
    final model = AdminProductModel(
      // Use preallocated id so uploads live under a stable folder
      id: widget.existing?.id ?? _listingId,
      sellerId: widget.existing?.sellerId ?? (FirebaseAuthService.currentUserId ?? ''),
      name: _name.text.trim(),
      description: _desc.text.trim(),
      price: price,
      imageUrl: primaryImage,
      imageUrls: urls,
      rating: _rating,
      tag: (_selectedTag ?? '').trim(),
      category: (_selectedCategory ?? '').trim(),
      stock: stock,
      isActive: _isActive,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
      condition: (_selectedCondition ?? '').trim(),
      campus: campus,
      pickupOnly: _pickupOnly,
      pickupLocation: _pickupLocation.text.trim(),
      negotiable: _negotiable,
    );

    String savedId;
    try {
      savedId = await FirestoreProductsService.upsert(
        model.copyWith(),
        storagePaths: List<String>.from(_storagePaths),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('exceeds the maximum allowed size')
            ? 'This product could not be saved because attached images are too large for Firestore. Please try smaller photos.'
            : 'Failed to save product: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      setState(() => _saving = false);
      return;
    }

    // For each picked video, create a ReelItem linked to this product
    if (_videos.isNotEmpty) {
      final coverBytes = _photos.first.bytes;
      String coverBase64;
      if (coverBytes != null) {
        coverBase64 = base64Encode(coverBytes);
      } else {
        // If first photo is remote, skip embedding cover; keep empty cover
        coverBase64 = '';
      }
      for (final v in _videos) {
        final b64 = base64Encode(v.bytes);
        final reel = ReelItem(
          id: 'reel_${DateTime.now().millisecondsSinceEpoch}_${v.bytes.hashCode}',
          productId: savedId,
          videoBase64: b64,
          coverImageBase64: coverBase64,
          caption: _name.text.trim().isNotEmpty ? _name.text.trim() : 'New product',
        );
        await LocalReelsStore.add(reel);
      }
    }

    // Re-fetch the saved product to ensure we have the latest updatedAt and URLs
    AdminProductModel? refreshed;
    try {
      refreshed = await FirestoreProductsService.getById(savedId);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _saving = false);
    // Optionally update local UI state (photos/urls) before navigating back
    if (refreshed != null) {
      // Replace local download URLs with the canonical ones from Firestore
      _downloadUrls
        ..clear()
        ..addAll(refreshed.imageUrls);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;

    final categories = _categories; // dynamic list including existing value if needed
    final tags = _tags; // dynamic list including existing value if needed
    _selectedCondition ??= (widget.existing?.condition.isNotEmpty ?? false) ? widget.existing!.condition : null;
    _negotiable = widget.existing?.negotiable ?? _negotiable;
    _pickupOnly = widget.existing?.pickupOnly ?? _pickupOnly;
    if ((widget.existing?.pickupLocation ?? '').isNotEmpty && _pickupLocation.text.isEmpty) {
      _pickupLocation.text = widget.existing!.pickupLocation;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Product name', prefixIcon: Icon(Icons.label_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined)),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a description' : null,
            ),
            const SizedBox(height: 12),
            _TwoUp(
              left: TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'Price', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final d = double.tryParse(v?.trim() ?? '');
                  if (d == null || d <= 0) return 'Enter price > 0';
                  return null;
                },
              ),
              right: TextFormField(
                controller: _stock,
                decoration: const InputDecoration(labelText: 'Stock', prefixIcon: Icon(Icons.inventory_2_outlined)),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final i = int.tryParse(v?.trim() ?? '');
                  if (i == null || i < 0) return 'Enter 0 or more';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            _TwoUp(
              left: DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: [
                  for (final c in categories)
                    DropdownMenuItem<String>(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _selectedCategory = v),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Select a category' : null,
              ),
              right: DropdownButtonFormField<String>(
                value: _selectedTag ?? '',
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('None')),
                  for (final t in tags)
                    DropdownMenuItem<String>(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _selectedTag = (v?.isEmpty ?? true) ? null : v),
                decoration: const InputDecoration(
                  labelText: 'Tag (optional)',
                  prefixIcon: Icon(Icons.bookmark_outline),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _TwoUp(
              left: DropdownButtonFormField<String>(
                value: _selectedCondition,
                items: [
                  for (final c in _conditions)
                    DropdownMenuItem<String>(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _selectedCondition = v),
                decoration: const InputDecoration(
                  labelText: 'Condition',
                  prefixIcon: Icon(Icons.check_circle_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Select condition' : null,
              ),
              right: TextFormField(
                controller: _pickupLocation,
                decoration: const InputDecoration(
                  labelText: 'Pickup location (on campus)',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter pickup location' : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('Product photos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _photoPickerGrid(theme),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined, color: Colors.indigo),
                  label: const Text('Add photos'),
                ),
                Tooltip(
                  message: kIsWeb ? 'Camera capture works on device builds' : 'Open camera',
                  child: OutlinedButton.icon(
                    onPressed: _pickImages, // fallback to gallery/file picker in web
                    icon: const Icon(Icons.photo_camera_outlined, color: Colors.teal),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Reel videos (optional)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _videoChips(theme),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickVideos,
              icon: const Icon(Icons.video_library_outlined, color: Colors.deepOrange),
              label: const Text('Add videos'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Rating (shown to users as seed rating)',
                prefixIcon: Icon(Icons.star_rounded, color: Colors.amber),
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _rating,
                      onChanged: (v) => setState(() => _rating = v),
                      min: 0,
                      max: 5,
                      divisions: 10,
                      label: _rating.toStringAsFixed(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_rating.toStringAsFixed(1)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _negotiable,
              onChanged: (v) => setState(() => _negotiable = v),
              title: const Text('Price negotiable'),
              secondary: const Icon(Icons.handshake_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: _pickupOnly,
              onChanged: (v) => setState(() => _pickupOnly = v),
              title: const Text('Local pickup only (no shipping)'),
              secondary: const Icon(Icons.hail_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active (visible in store)'),
              secondary: const Icon(Icons.visibility_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canPublish ? _save : null,
                icon: const Icon(Icons.save),
                label: Text(_saving
                    ? (isEdit ? 'Saving…' : 'Adding…')
                    : (_uploading
                        ? 'Uploading images…'
                        : (isEdit ? 'Save changes' : 'Publish listing'))),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tip: You can add multiple photos. If you also attach videos, they will appear in the user Reels tab and link back to this product.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPickerGrid(ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _photos.length + 1,
      itemBuilder: (context, index) {
        if (index == _photos.length) {
          return InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.indigo)),
            ),
          );
        }
        final p = _photos[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: p.remoteUrl != null
                  ? Builder(builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final size = (MediaQuery.of(context).size.width / 3).clamp(64.0, 256.0);
                      return Image.network(
                        fixFirebaseDownloadUrl(p.remoteUrl!),
                        fit: BoxFit.cover,
                        cacheWidth: (size * dpr).round(),
                        cacheHeight: (size * dpr).round(),
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                      );
                    })
                  : Builder(builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final size = (MediaQuery.of(context).size.width / 3).clamp(64.0, 256.0);
                      return Image.memory(
                        p.bytes!,
                        fit: BoxFit.cover,
                        cacheWidth: (size * dpr).round(),
                        cacheHeight: (size * dpr).round(),
                        filterQuality: FilterQuality.low,
                      );
                    }),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() {
                    final removed = _photos.removeAt(index);
                    final url = removed.remoteUrl;
                    if (url != null) {
                      final idx = _downloadUrls.indexWhere((e) => fixFirebaseDownloadUrl(e) == fixFirebaseDownloadUrl(url));
                      if (idx != -1) {
                        _downloadUrls.removeAt(idx);
                        if (idx < _storagePaths.length) {
                          _storagePaths.removeAt(idx);
                        }
                      }
                    }
                  }),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _videoChips(ThemeData theme) {
    if (_videos.isEmpty) {
      return Text('No videos added', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < _videos.length; i++)
          Chip(
            avatar: const Icon(Icons.movie, color: Colors.deepOrange),
            label: Text('Video ${i + 1}'),
            deleteIcon: const Icon(Icons.close),
            onDeleted: () => setState(() => _videos.removeAt(i)),
          ),
      ],
    );
  }
}

/// Responsive two-up field row that stacks on small widths to avoid overflow.
class _TwoUp extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;
  final double stackBreakpoint;

  const _TwoUp({
    required this.left,
    required this.right,
    this.gap = 12,
    this.stackBreakpoint = 520, // stack vertically when narrower than this
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < stackBreakpoint;
        if (narrow) {
          return Column(
            children: [
              left,
              SizedBox(height: gap),
              right,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: left),
            SizedBox(width: gap),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _Photo {
  final Uint8List? bytes;
  final String? remoteUrl;
  final String? extension;
  _Photo.local(Uint8List this.bytes, this.extension) : remoteUrl = null;
  _Photo.remote(String this.remoteUrl)
      : bytes = null,
        extension = null;
}

class _Video {
  final Uint8List bytes;
  final String extension;
  final String mimeType;
  _Video({required this.bytes, required this.extension, required this.mimeType});
}
