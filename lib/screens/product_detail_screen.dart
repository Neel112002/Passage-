import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:passage/models/cart_item.dart';
import 'package:passage/models/review.dart';
import 'package:passage/services/local_cart_store.dart';
import 'package:passage/services/local_reviews_store.dart';
import 'package:passage/services/local_user_profile_store.dart';
import 'package:passage/services/local_auth_store.dart';
import 'cart_screen.dart';
// Use stored download URLs; soft-normalize legacy bad-bucket URLs for display only
import 'package:passage/utils/url_fixes.dart';
import 'package:passage/screens/chat_thread_screen.dart';
import 'package:passage/widgets/cart_icon_button.dart';

class ProductDetailData {
  final String id;
  final String name;
  final double price;
  final String imageUrl; // primary (back-compat for cards/carts)
  final List<String> imageUrls; // gallery (first should match imageUrl)
  final double rating;
  final String tag;
  final String description;
  final int stock;
  // Marketplace additions
  final String condition;
  final String campus;
  final bool pickupOnly;
  final String pickupLocation;
  final bool negotiable;
  final String sellerId;
  final DateTime updatedAt;

  const ProductDetailData({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.imageUrls,
    required this.rating,
    required this.tag,
    required this.description,
    required this.stock,
    this.condition = '',
    this.campus = '',
    this.pickupOnly = true,
    this.pickupLocation = '',
    this.negotiable = false,
    this.sellerId = '',
    required this.updatedAt,
  });
}

class ProductDetailScreen extends StatefulWidget {
  final ProductDetailData product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with TickerProviderStateMixin {
  // Anchor for fly-to-cart animation
  final GlobalKey _imageGlobalKey = GlobalKey(debugLabel: 'detailImage');
  int _quantity = 1;

  // Gallery state
  int _galleryIndex = 0;
  late final PageController _galleryController;

  // Reviews state
  List<ProductReview> _reviews = const [];
  double _avgRating = 0;
  bool _loadingReviews = true;

  // New review form state
  double _newRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
    _loadReviews();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    final list = await LocalReviewsStore.forProduct(widget.product.id);
    final double avg = list.isEmpty
        ? 0.0
        : list.fold<double>(0.0, (sum, e) => sum + e.rating) / list.length;
    setState(() {
      _reviews = list;
      _avgRating = avg;
      _loadingReviews = false;
    });
  }

  Future<void> _submitReview() async {
    final rating = _newRating;
    final comment = _commentController.text.trim();
    if (rating <= 0) {
      _showSnack('Please select a star rating');
      return;
    }
    if (comment.isEmpty) {
      _showSnack('Please write a short review');
      return;
    }
    // Resolve author
    String authorName = 'Anonymous';
    String? authorEmail;
    try {
      final profile = await LocalUserProfileStore.load();
      if (profile != null && profile.fullName.trim().isNotEmpty) {
        authorName = profile.fullName.trim();
      }
    } catch (_) {}
    try {
      final email = await LocalAuthStore.getLoginEmail();
      if (email.trim().isNotEmpty) {
        authorEmail = email.trim();
        if (authorName == 'Anonymous') {
          authorName = email.split('@').first;
        }
      }
    } catch (_) {}

    final now = DateTime.now();
    final review = ProductReview(
      id: '${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}',
      productId: widget.product.id,
      userId: 'demo-user',
      authorName: authorName,
      authorEmail: authorEmail,
      rating: rating,
      comment: comment,
      createdAt: now,
      updatedAt: now,
    );

    await LocalReviewsStore.add(review);
    _commentController.clear();
    setState(() => _newRating = 0);
    await _loadReviews();
    if (mounted) _showSnack('Thanks! Your review was added');
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  void _increment() {
    setState(() => _quantity++);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }


  Widget _imageSection(ProductDetailData p) {
    final images = p.imageUrls.isNotEmpty ? p.imageUrls : [p.imageUrl];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          key: _imageGlobalKey,
          aspectRatio: 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => _FullScreenGallery(
                        images: images,
                        initialIndex: _galleryIndex,
                        heroTag: 'product-image-${p.id}',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'product-image-${p.id}',
                  child: PageView.builder(
                    controller: _galleryController,
                    onPageChanged: (i) => setState(() => _galleryIndex = i),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final width = MediaQuery.of(context).size.width;
                      return _AnyImage(
                        key: ValueKey('img-${p.id}-${p.updatedAt.millisecondsSinceEpoch}-${images[index]}'),
                        url: images[index],
                        fit: BoxFit.cover,
                        cacheWidth: (width * dpr).round(),
                        cacheHeight: (width * dpr).round(),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p.tag,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // Dots indicator
              if (images.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(images.length, (i) {
                      final active = i == _galleryIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 68,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final selected = index == _galleryIndex;
                return GestureDetector(
                  onTap: () => _galleryController.animateToPage(index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? Colors.teal
                              : Colors.white.withValues(alpha: 0.8),
                          width: selected ? 2 : 1),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Builder(builder: (context) {
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      return _AnyImage(
                        key: ValueKey('thumb-${p.id}-${p.updatedAt.millisecondsSinceEpoch}-${images[index]}'),
                        url: images[index],
                        fit: BoxFit.cover,
                        cacheWidth: (68 * dpr).round(),
                        cacheHeight: (68 * dpr).round(),
                      );
                    }),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: images.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _detailsSection(BuildContext context, ProductDetailData p) {
    final theme = Theme.of(context);
    final double totalPrice = p.price * _quantity;
    final double displayRating = _reviews.isNotEmpty ? _avgRating : p.rating;
    final int reviewsCount = _reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(displayRating.toStringAsFixed(1),
                          style: theme.textTheme.bodyMedium),
                      if (reviewsCount > 0) ...[
                        const SizedBox(width: 6),
                        Text('(${reviewsCount})',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6))),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '\$${totalPrice.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '(\$${p.price.toStringAsFixed(2)} each)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        // Campus / pickup info
        Row(
          children: [
            const Icon(Icons.school_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.campus.isNotEmpty
                    ? 'Campus-only • ${p.campus}'
                    : 'Campus-only marketplace',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
                p.pickupOnly
                    ? Icons.handshake_outlined
                    : Icons.local_shipping_outlined,
                color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.pickupOnly
                    ? (p.pickupLocation.isNotEmpty
                        ? 'Local pickup: ${p.pickupLocation}'
                        : 'Local pickup on campus')
                    : 'Pickup or shipping available',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Stock indicator
        Row(
          children: [
            Icon(
              p.stock > 0
                  ? Icons.inventory_2_outlined
                  : Icons.remove_shopping_cart_outlined,
              color: p.stock > 0 ? Colors.teal : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              p.stock > 0 ? 'In stock: ${p.stock}' : 'Out of stock',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: p.stock > 0 ? Colors.teal : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (p.condition.isNotEmpty || p.negotiable) ...[
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (p.condition.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Text('Condition: ${p.condition}',
                            style: theme.textTheme.labelMedium),
                      ),
                    if (p.negotiable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Text('Price negotiable',
                            style: theme.textTheme.labelMedium),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          p.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _decrement,
                    icon: const Icon(Icons.remove, color: Colors.red),
                    tooltip: 'Decrease',
                  ),
                  Text(
                    '$_quantity',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: _increment,
                    icon: const Icon(Icons.add, color: Colors.green),
                    tooltip: 'Increase',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await LocalCartStore.addOrIncrement(CartItem(
                    productId: p.id,
                    name: p.name,
                    imageUrl: p.imageUrl,
                    unitPrice: p.price,
                    quantity: _quantity,
                  ));
                  final total = p.price * _quantity;
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Added $_quantity x ${p.name} to cart (\$${total.toStringAsFixed(2)})'),
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: 'View',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()),
                          );
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.handshake_rounded),
                label: const Text('Reserve for Pickup'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: p.sellerId.isEmpty
                ? null
                : () {
                    final initial = "Hi! I'm interested in ${p.name}. Is it still available?";
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChatThreadScreen(
                          productId: p.id,
                          sellerId: p.sellerId,
                           productName: p.name,
                           productImageUrl: p.imageUrl,
                          initialMessage: initial,
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Chat with Seller'),
          ),
        ),
      ],
    );
  }

  Widget _reviewsSection(BuildContext context) {
    final theme = Theme.of(context);
    final displayRating =
        _reviews.isNotEmpty ? _avgRating : widget.product.rating;
    final reviewCount = _reviews.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.reviews_rounded, color: Colors.indigo),
            const SizedBox(width: 8),
            Text('Ratings & Reviews',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StarRow(rating: displayRating, size: 18),
                      const SizedBox(width: 8),
                      Text(displayRating.toStringAsFixed(1),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reviewCount > 0
                        ? '$reviewCount review${reviewCount == 1 ? '' : 's'}'
                        : 'No reviews yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // New review form
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Write a review',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _RatingInput(
                    value: _newRating,
                    onChanged: (v) => setState(() => _newRating = v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      _newRating > 0
                          ? _newRating.toStringAsFixed(1)
                          : 'Select rating',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your experience (min 3 words)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _submitReview,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingReviews)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator()))
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text('Be the first to review this product',
                    style: theme.textTheme.bodyMedium),
              ],
            ),
          )
        else
          Column(
            children: [
              for (final r in _reviews.take(6)) _ReviewTile(review: r),
              if (_reviews.length > 6)
                Text('Showing 6 of ${_reviews.length} reviews',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [
          CartIconButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 900;

            if (isWide) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _imageSection(p),
                        const SizedBox(height: 16),
                        _detailsSection(context, p),
                        _reviewsSection(context),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Mobile: stacked layout
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                        _imageSection(p),
                        const SizedBox(height: 16),
                        _detailsSection(context, p),
                        _reviewsSection(context),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating; // 0..5
  final double size;
  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && half
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            size: size,
            color: Colors.amber,
          ),
      ],
    );
  }
}

class _RatingInput extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _RatingInput({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final idx = i + 1;
        final active = value >= idx - 0.25; // small hysteresis
        return IconButton(
          onPressed: () => onChanged(idx.toDouble()),
          icon: Icon(active ? Icons.star_rounded : Icons.star_outline_rounded,
              color: Colors.amber),
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ProductReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: review.rating, size: 16),
              const SizedBox(width: 8),
              Text(review.rating.toStringAsFixed(1),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(_formatDate(review.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                child: const Icon(Icons.person, size: 14, color: Colors.indigo),
              ),
              const SizedBox(width: 6),
              Text(review.authorName,
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// Lightweight image widget that supports both network URLs and data:image URIs
class _AnyImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  const _AnyImage(
      {super.key,
      required this.url,
      this.fit = BoxFit.cover,
      this.cacheWidth,
      this.cacheHeight});

  @override
  Widget build(BuildContext context) {
    // Trim and soft-normalize legacy bucket host for reliability
    String src = fixFirebaseDownloadUrl((url).trim());
    const kPrefix = 'https://firebasestorage.googleapis.com/';

    if (src.startsWith('data:image')) {
      try {
        final base64Part = src.split(',').last;
        final bytes = base64Decode(base64Part);
        return Image.memory(
          bytes,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.low,
        );
      } catch (_) {
        return const ColoredBox(color: Colors.black12);
      }
    }
    if (!src.startsWith(kPrefix)) {
      return const ColoredBox(color: Colors.black12);
    }
    return Image.network(
      src,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.low,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: Theme.of(context).colorScheme.surfaceVariant);
      },
      errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
    );
  }
}

// Full-screen gallery viewer with swipe and pinch-to-zoom
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroTag;
  const _FullScreenGallery({
    required this.images,
    this.initialIndex = 0,
    required this.heroTag,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: widget.images.length,
              itemBuilder: (context, i) {
                final url = widget.images[i];
                return Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: _AnyImage(
                        url: url,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Close button
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ),
            // Counter
            if (widget.images.length > 1)
              Positioned(
                top: 14,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
