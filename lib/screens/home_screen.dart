import 'dart:async';
import 'dart:convert';
// import 'dart:math' as math; // no longer used
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'product_detail_screen.dart';
import 'notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'orders_screen.dart';
import 'package:passage/models/reel_item.dart';
import 'package:passage/services/local_reels_store.dart';

import 'privacy_security_screen.dart';
import 'addresses_screen.dart';
import 'payment_methods_screen.dart';
import 'cart_screen.dart';
import 'package:passage/models/user_profile.dart';
import 'package:passage/models/product.dart';
import 'package:passage/services/firestore_products_service.dart';
import 'package:passage/services/local_user_profile_store.dart';
import 'package:passage/models/cart_item.dart';
import 'package:passage/services/local_cart_store.dart';
import 'package:passage/widgets/cart_icon_button.dart';
import 'package:passage/widgets/points_icon_button.dart';
import 'package:passage/services/firebase_auth_service.dart';
import 'conversations_list_screen.dart';
import 'package:passage/utils/url_fixes.dart';
import 'seller_dashboard_screen.dart';
// Soft-normalize legacy storage URLs at render time for reliability across devices

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // In-memory favorites store for demo (products)
  final Set<String> _favorites = <String>{};

  // In-memory saved reels
  final Set<String> _savedReels = <String>{};

  // Seller-uploaded local reels (persisted locally)
  List<ReelItem> _localReels = <ReelItem>[];

  // If set, Reels page will open at this index next time it's shown
  int? _reelStartIndex;

  // Profile page segmented section
  _ProfileSection _profileSection = _ProfileSection.settings;

  // Demo user profile (local-only, no backend)
  UserProfile _profile = UserProfile(
    fullName: 'Alex Johnson',
    username: 'alexj',
    email: 'alex@example.com',
    phone: '',
    bio: 'Shopper and gear enthusiast.',
    gender: '',
    dob: null,
    avatarUrl: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // Category filtering
  int _selectedCategoryIndex = 0;

  // Filters
  double _priceMin = 0;
  double _priceMax = 1000;
  RangeValues _priceRange = const RangeValues(0, 1000);
  double _minRatingFilter = 0;
  _SortOption _sort = _SortOption.recommended;
  final Set<String> _selectedTags = <String>{};

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Home scroll controller to enable animated FAB and effects
  late final ScrollController _homeScrollController;
  bool _showToTopFab = false;
  bool _isScrolling = false;
  Timer? _scrollIdleDebounce;

  // Promo carousel controller (no transforms)
  final PageController _promoController = PageController(viewportFraction: 0.9);

  // Seller functionality removed

  @override
  void initState() {
    super.initState();
    // Listen to Firestore products (live)
    _listenProducts();

    // Load saved profile if available
    _loadProfile();

    // Load local reels (seller videos)
    _loadLocalReels();

    // Init scroll controller
    _homeScrollController = ScrollController()
      ..addListener(() {
        final show = _homeScrollController.offset > 320;
        if (show != _showToTopFab) {
          setState(() => _showToTopFab = show);
        }
        // Lightweight scroll state to pause heavy animations while user scrolls
        if (!_isScrolling) {
          setState(() => _isScrolling = true);
        }
        _scrollIdleDebounce?.cancel();
        _scrollIdleDebounce = Timer(const Duration(milliseconds: 140), () {
          if (mounted) setState(() => _isScrolling = false);
        });
      });
  }

  @override
  void dispose() {
    _homeScrollController.dispose();
    _searchController.dispose();
    _promoController.dispose();
    _searchDebounce?.cancel();
    _scrollIdleDebounce?.cancel();
    _productsSub?.cancel();
    super.dispose();
  }

  StreamSubscription<List<AdminProductModel>>? _productsSub;
  void _listenProducts() {
    _productsSub = FirestoreProductsService.watchAll().listen((items) {
      final mapped = items
          .map((p) => _DemoProduct(
                id: p.id,
                name: p.name,
                price: p.price,
                imageUrl:
                    (p.imageUrls.isNotEmpty ? p.imageUrls.first : p.imageUrl),
                images: p.imageUrls,
                rating: p.rating,
                tag: p.tag,
                category: p.category,
                description: p.description,
                stock: p.stock,
                condition: p.condition,
                campus: p.campus,
                pickupOnly: p.pickupOnly,
                pickupLocation: p.pickupLocation,
                negotiable: p.negotiable,
                sellerId: p.sellerId,
                updatedAt: p.updatedAt,
              ))
          .toList();
      double minP = 0, maxP = 1000;
      if (mapped.isNotEmpty) {
        minP = mapped.map((e) => e.price).reduce((a, b) => a < b ? a : b);
        maxP = mapped.map((e) => e.price).reduce((a, b) => a > b ? a : b);
      }
      if (!mounted) return;
      setState(() {
        _products = mapped;
        _priceMin = minP;
        _priceMax = maxP;
        _priceRange = RangeValues(_priceMin, _priceMax);
      });
    });
  }

  Future<void> _loadProfile() async {
    try {
      final p = await LocalUserProfileStore.load();
      if (p != null && mounted) {
        setState(() => _profile = p);
      }
    } catch (_) {
      // ignore loading errors for demo
    }
  }

  Future<void> _loadLocalReels() async {
    try {
      final items = await LocalReelsStore.loadAll();
      if (mounted) setState(() => _localReels = items);
    } catch (_) {
      // ignore
    }
  }

  List<_DemoReel> get _combinedReels {
    // Map local reels to _DemoReel by using data URIs.
    const fallbackCover =
        'https://images.unsplash.com/photo-1530915365347-3f8b6d01b401?w=800&h=800&fit=crop';
    final local = _localReels.map((r) {
      final cover = r.coverImageBase64.isNotEmpty
          ? 'data:image/jpeg;base64,${r.coverImageBase64}'
          : fallbackCover;
      final video = 'data:video/mp4;base64,${r.videoBase64}';
      return _DemoReel(
          id: 'lr_${r.id}',
          productId: r.productId,
          videoUrl: video,
          coverImageUrl: cover,
          caption: r.caption);
    }).toList();
    return [..._reels, ...local];
  }

  List<_DemoProduct> _products = <_DemoProduct>[];

  // Remove demo reels; keep empty until seller uploads local reels
  final List<_DemoReel> _reels = const [];

  final List<_CategoryItem> _categories = const [
    _CategoryItem('All', Icons.grid_view_rounded),
    _CategoryItem('Books', Icons.menu_book_rounded),
    _CategoryItem('Electronics', Icons.devices_rounded),
    _CategoryItem('Furniture', Icons.chair_alt_rounded),
    _CategoryItem('Dorm & Essentials', Icons.home_work_outlined),
    _CategoryItem('Bikes', Icons.directions_bike_rounded),
    _CategoryItem('Fashion', Icons.checkroom_rounded),
    _CategoryItem('Others', Icons.all_inbox_rounded),
  ];

  bool _isFavorite(String id) => _favorites.contains(id);
  void _toggleFavorite(String id) {
    setState(() {
      if (_favorites.contains(id)) {
        _favorites.remove(id);
      } else {
        _favorites.add(id);
      }
    });
  }

  void _toggleSaveReel(String reelId) {
    setState(() {
      if (_savedReels.contains(reelId)) {
        _savedReels.remove(reelId);
      } else {
        _savedReels.add(reelId);
      }
    });
  }

  // Memoized filter results to avoid recomputing on every scroll frame
  String? _lastFilterKey;
  List<_DemoProduct>? _cachedFilteredProducts;
  String _buildFilterKey() {
    final tags = (_selectedTags.toList()..sort()).join(',');
    // Round range to avoid tiny double diffs bloating the key
    final pr =
        '${_priceRange.start.toStringAsFixed(2)}-${_priceRange.end.toStringAsFixed(2)}';
    return [
      _selectedCategoryIndex,
      pr,
      _minRatingFilter.toStringAsFixed(1),
      _sort.index,
      tags,
      _searchQuery.trim().toLowerCase(),
    ].join('|');
  }

  List<_DemoProduct> get _filteredProducts {
    final key = _buildFilterKey();
    if (_lastFilterKey == key && _cachedFilteredProducts != null) {
      return _cachedFilteredProducts!;
    }
    // Start from category selection
    List<_DemoProduct> list;
    if (_selectedCategoryIndex == 0) {
      list = List<_DemoProduct>.from(_products);
    } else {
      final selectedCategory = _categories[_selectedCategoryIndex].label;
      list = _products
          .where((product) => product.category == selectedCategory)
          .toList();
    }

    // Apply price range
    list = list
        .where((p) =>
            p.price >= _priceRange.start - 0.0001 &&
            p.price <= _priceRange.end + 0.0001)
        .toList();

    // Apply minimum rating
    if (_minRatingFilter > 0) {
      list = list.where((p) => p.rating >= _minRatingFilter).toList();
    }

    // Apply tag filter
    if (_selectedTags.isNotEmpty) {
      list = list.where((p) => _selectedTags.contains(p.tag)).toList();
    }

    // Apply search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.tag.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);
      }).toList();
    }

    // Sorting
    switch (_sort) {
      case _SortOption.priceLowHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceHighLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.ratingHighLow:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortOption.recommended:
      // keep natural order
        break;
    }

    // Store memoized result
    _cachedFilteredProducts = list;
    _lastFilterKey = key;
    return list;
  }


  Future<void> _openFilterSheet() async {
    // Local copies to allow cancel without applying
    RangeValues range = _priceRange;
    double minRating = _minRatingFilter;
    _SortOption sortLocal = _sort;
    final Set<String> tagsLocal = Set<String>.from(_selectedTags);

    final tags = _products.map((e) => e.tag).toSet().toList()..sort();

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StatefulBuilder(
                builder: (context, setLocal) {
                  final bottomPad =
                      MediaQuery.of(context).viewInsets.bottom + 20;
                  return SafeArea(
                    top: false,
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.only(top: 12, bottom: bottomPad),
                      children: [
                        Row(
                          children: [
                            Text('Filters',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setLocal(() {
                                  range = RangeValues(_priceMin, _priceMax);
                                  minRating = 0;
                                  sortLocal = _SortOption.recommended;
                                  tagsLocal.clear();
                                });
                              },
                              icon: const Icon(Icons.restart_alt,
                                  color: Colors.red),
                              label: const Text('Reset'),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Divider(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2)),
                        const SizedBox(height: 8),

                        // Sort
                        Text('Sort by',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _SortOption.values.map((opt) {
                            final selected = sortLocal == opt;
                            return ChoiceChip(
                              label: Text(_sortLabel(opt)),
                              selected: selected,
                              onSelected: (_) =>
                                  setLocal(() => sortLocal = opt),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Price
                        Text('Price range',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                    '\$${range.start.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyMedium),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('\$${range.end.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyMedium),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: range,
                          onChanged: (v) => setLocal(() => range = v),
                          min: _priceMin.floorToDouble(),
                          max: _priceMax.ceilToDouble(),
                          divisions: 20,
                          labels: RangeLabels(
                            '\$${range.start.toStringAsFixed(0)}',
                            '\$${range.end.toStringAsFixed(0)}',
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Rating
                        Text('Minimum rating',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: minRating,
                                onChanged: (v) => setLocal(() => minRating = v),
                                min: 0,
                                max: 5,
                                divisions: 10,
                                label: minRating.toStringAsFixed(1),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 6),
                                  Text(minRating.toStringAsFixed(1),
                                      style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Tags
                        Text('Tags',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in tags)
                              FilterChip(
                                label: Text(t),
                                selected: tagsLocal.contains(t),
                                onSelected: (v) {
                                  setLocal(() {
                                    if (v) {
                                      tagsLocal.add(t);
                                    } else {
                                      tagsLocal.remove(t);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context, false),
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                label: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(Icons.check_circle,
                                    color: Colors.green),
                                label: const Text('Apply'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (applied == true) {
      setState(() {
        _priceRange = range;
        _minRatingFilter = minRating;
        _sort = sortLocal;
        _selectedTags
          ..clear()
          ..addAll(tagsLocal);
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useRail = width >= 900; // tablet/desktop
        final extendRail = width >= 1300; // very wide desktop

        final appBar = AppBar(
          titleSpacing: 0,
          title: const _BrandTitle(subtitle: 'Buy & sell on campus'),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ConversationsListScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.teal),
              tooltip: 'Messages',
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded,
                  color: Colors.blue),
              tooltip: 'Notifications',
            ),
            const PointsIconButton(),
            const CartIconButton(),
            const SizedBox(width: 8),
          ],
        );

        // Select content by tab
        Widget pageContent;
        switch (_currentIndex) {
          case 1:
            pageContent = _buildReelsContent(context);
            break;
          case 2:
            pageContent = _buildProfileContent(context);
            break;
          case 0:
          default:
            pageContent = _buildHomeContent(context);
        }

        if (useRail) {
          return Scaffold(
            appBar: appBar,
            floatingActionButton: _currentIndex == 0 && _showToTopFab
                ? FloatingActionButton.small(
                    onPressed: () {
                      if (_homeScrollController.hasClients) {
                        _homeScrollController.jumpTo(0);
                      }
                    },
                    child: const Icon(Icons.arrow_upward),
                  )
                : null,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  extended: extendRail,
                  labelType:
                      extendRail ? null : NavigationRailLabelType.selected,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie),
                      label: Text('Reels'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: pageContent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile layout with bottom navigation
        return Scaffold(
          appBar: appBar,
          floatingActionButton: _currentIndex == 0 && _showToTopFab
              ? FloatingActionButton.small(
                  onPressed: () {
                    if (_homeScrollController.hasClients) {
                      _homeScrollController.jumpTo(0);
                    }
                  },
                  child: const Icon(Icons.arrow_upward),
                )
              : null,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: pageContent,
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: 'Reels'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        );
      },
    );
  }

  // HOME PAGE
  Widget _buildHomeContent(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {

        // Increase cacheExtent to reduce image decode spikes as you scroll.
        // Use ~2x viewport height for smoother prebuilding.
        final viewportH = MediaQuery.of(context).size.height;
        return CustomScrollView(
          controller: _currentIndex == 0 ? _homeScrollController : null,
          cacheExtent: viewportH * 2,
          slivers: [
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _SearchBar(
                  controller: _searchController,
                  query: _searchQuery,
                  onChanged: (v) {
                    _searchDebounce?.cancel();
                    _searchDebounce =
                        Timer(const Duration(milliseconds: 180), () {
                      if (mounted) setState(() => _searchQuery = v);
                    });
                  },
                  onSubmitted: (v) {
                    _searchDebounce?.cancel();
                    setState(() => _searchQuery = v);
                  },
                  onClear: () => setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                  onFilterPressed: _openFilterSheet,
                ),
              ),
            ),
            // Category chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    final selected = index == _selectedCategoryIndex;
                    return ChoiceChip(
                      label: Text(c.label),
                      avatar: Icon(c.icon,
                          size: 18,
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategoryIndex = index);
                      },
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemCount: _categories.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 4)),
            // Promo carousel
            SliverToBoxAdapter(
              child: Container(
                height: 140,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: PageView.builder(
                  controller: _promoController,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    final promos = [
                      {
                        'title': 'Summer Sale',
                        'subtitle': 'Up to 50% OFF',
                        'emoji': '☀️',
                        'color': Colors.orange
                      },
                      {
                        'title': 'New Arrivals',
                        'subtitle': 'Fresh picks for you',
                        'emoji': '🆕',
                        'color': Colors.blue
                      },
                      {
                        'title': 'Member Deals',
                        'subtitle': 'Exclusive rewards',
                        'emoji': '🎁',
                        'color': Colors.purple
                      },
                    ];
                    final promo = promos[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (promo['color'] as Color).withValues(alpha: 0.8),
                            (promo['color'] as Color).withValues(alpha: 0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              primary: false,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    promo['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    promo['subtitle'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.local_offer_rounded,
                                        size: 16),
                                    label: const Text('Shop now'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: promo['color'] as Color,
                                      minimumSize: const Size(0, 32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            promo['emoji'] as String,
                            style: const TextStyle(fontSize: 48),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Active filters bar
            SliverToBoxAdapter(
              child: _ActiveFiltersBar(
                priceRange: _priceRange,
                minRating: _minRatingFilter,
                selectedTags: _selectedTags,
                onClearTag: (t) => setState(() => _selectedTags.remove(t)),
                onClearAll: () => setState(() {
                  _priceRange = RangeValues(_priceMin, _priceMax);
                  _minRatingFilter = 0;
                  _sort = _SortOption.recommended;
                  _selectedTags.clear();
                }),
                onTapFilters: _openFilterSheet,
              ),
            ),
            // Product grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverLayoutBuilder(
                builder: (context, sliverConstraints) {
                  final w = sliverConstraints.crossAxisExtent;
                  int columns;
                  if (w >= 1200) {
                    columns = (w / 270).floor();
                  } else if (w >= 900) {
                    columns = (w / 250).floor();
                  } else if (w >= 600) {
                    columns = (w / 230).floor();
                  } else {
                    columns = (w / 210).floor();
                  }
                  columns = columns.clamp(2, 6);
                  final childAspect =
                      (w < 400) ? 0.60 : 0.65; // more height on compact phones

                  // Compute filtered list once per layout pass (with internal memoization)
                  final filteredProducts = _filteredProducts;
                  // Image precache removed (no product photos in UI)

                  // Pre-compute a stable cache size for product images to avoid a per-item
                  // LayoutBuilder in image widgets (reduces layout work per frame).
                  const crossAxisSpacing = 12.0;
                  final cellWidth =
                      (w - crossAxisSpacing * (columns - 1)) / columns;
                  final cellHeight = cellWidth / childAspect;
                  // Image area is the top Expanded(flex: 3) out of total flex 5
                  final imageAreaHeight = cellHeight * (3.0 / 5.0);
                  final dpr = MediaQuery.of(context).devicePixelRatio;
                  final imgCacheW = (cellWidth * dpr).clamp(64, 2048).round();
                  final imgCacheH =
                      (imageAreaHeight * dpr).clamp(64, 2048).round();

                  if (filteredProducts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 56, color: Colors.teal),
                              const SizedBox(height: 12),
                              Text('No products yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('Products you add will appear here.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: childAspect,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final p = filteredProducts[index];
                        final isFav = _isFavorite(p.id);
                        return _ProductCard(
                          key: ValueKey(p.id),
                          product: p,
                          isFavorite: isFav,
                          imageCacheWidth: imgCacheW,
                          imageCacheHeight: imgCacheH,
                          onHeartPressed: () {
                            final wasFavorite = _isFavorite(p.id);
                            _toggleFavorite(p.id);
                            if (!wasFavorite) {
                              setState(() {
                                _currentIndex = 2;
                                _profileSection = _ProfileSection.liked;
                              });
                            }
                          },
                          onTap: () {
                            // Robust gallery fallback to avoid runtime null issues
                            List<String> gallery;
                            try {
                              final g = p.images;
                              gallery = (g.isNotEmpty)
                                  ? g
                                  : [p.imageUrl];
                            } catch (_) {
                              gallery = [p.imageUrl];
                            }
      final data = ProductDetailData(
                              id: p.id,
                              name: p.name,
                              price: p.price,
                              imageUrl: p.imageUrl,
                              imageUrls: gallery,
                              rating: p.rating,
                              tag: p.tag,
                              description: p.description,
                              stock: p.stock,
                              condition: p.condition,
                              campus: p.campus,
                              pickupOnly: p.pickupOnly,
                              pickupLocation: p.pickupLocation,
                              negotiable: p.negotiable,
        sellerId: p.sellerId,
        updatedAt: p.updatedAt,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(product: data),
                              ),
                            );
                          },
                        );
                      },
                      childCount: filteredProducts.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      addSemanticIndexes: false,
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        );
      },
    );
  }

  // REELS PAGE
  Widget _buildReelsContent(BuildContext context) {
    return _ReelsView(
      reels: _combinedReels,
      savedReelIds: _savedReels,
      initialIndex: _reelStartIndex ?? 0,
      onInitialIndexConsumed: () {
        // Clear the start index once used
        _reelStartIndex = null;
      },
      onToggleSave: (id) => _toggleSaveReel(id),
      onOpenProduct: (productId) {
        if (_products.isEmpty) return;
        final p = _products.firstWhere((e) => e.id == productId,
            orElse: () => _products.first);
        List<String> gallery;
        try {
          final g = p.images;
          gallery = g.isNotEmpty ? g : [p.imageUrl];
        } catch (_) {
          gallery = [p.imageUrl];
        }
        final data = ProductDetailData(
          id: p.id,
          name: p.name,
          price: p.price,
          imageUrl: p.imageUrl,
          imageUrls: gallery,
          rating: p.rating,
          tag: p.tag,
          description: p.description,
          stock: p.stock,
          condition: p.condition,
          campus: p.campus,
          pickupOnly: p.pickupOnly,
          pickupLocation: p.pickupLocation,
          negotiable: p.negotiable,
          sellerId: p.sellerId,
          updatedAt: p.updatedAt,
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: data)),
        );
      },
    );
  }

  // PROFILE (with segmented sections: settings, saved, liked)
  Widget _buildProfileTab({
    required BuildContext context,
    required _ProfileSection section,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isFirst,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => setState(() => _profileSection = section),
      borderRadius: BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(12) : Radius.zero,
        right: isFirst ? Radius.zero : const Radius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(12) : Radius.zero,
            right: isFirst ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context) {
    final theme = Theme.of(context);

    // Filter favorites/saved
    final favoriteProducts =
        _products.where((p) => _favorites.contains(p.id)).toList();
    final favoriteReels = <_DemoReel>[];
    try {
      favoriteReels.addAll(_reels.where((r) => _savedReels.contains(r.id)));
    } catch (e) {
      // Handle error gracefully if _reels has issues
      // ignore for demo
    }

    return CustomScrollView(
      controller: null, // Use separate controller or no controller for profile
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _profile.avatarBytes != null
                      ? MemoryImage(_profile.avatarBytes!)
                      : (_profile.avatarUrl.isNotEmpty
                          ? NetworkImage(_profile.avatarUrl)
                          : null),
                  child: (_profile.avatarBytes == null &&
                          _profile.avatarUrl.isEmpty)
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_profile.fullName,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        _profile.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 4),
                      Builder(builder: (context) {
                        final email = _profile.email.trim();
                        final domain = email.contains('@')
                            ? email.split('@').last.toLowerCase()
                            : '';
                        final isEdu =
                            domain.endsWith('.edu') || domain.contains('.edu');
                        final verified = FirebaseAuthService.isEmailVerified;
                        if (isEdu && verified) {
                          return Row(
                            children: [
                              const Icon(Icons.verified,
                                  color: Colors.teal, size: 16),
                              const SizedBox(width: 6),
                              Text('Verified student',
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: Colors.teal)),
                            ],
                          );
                        }
                        if (isEdu && !verified) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                try {
                                  await FirebaseAuthService
                                      .sendEmailVerification();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Verification email sent. Check your inbox.')));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Could not send verification email: $e')));
                                  }
                                }
                              },
                              icon: const Icon(Icons.school_outlined,
                                  color: Colors.indigo),
                              label: const Text('Verify student email'),
                              style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Tab selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface,
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildProfileTab(
                      context: context,
                      section: _ProfileSection.settings,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      isSelected: _profileSection == _ProfileSection.settings,
                      isFirst: true,
                    ),
                  ),
                  Expanded(
                    child: _buildProfileTab(
                      context: context,
                      section: _ProfileSection.saved,
                      icon: Icons.bookmark_outlined,
                      label: 'Saved',
                      isSelected: _profileSection == _ProfileSection.saved,
                      isFirst: false,
                    ),
                  ),
                  Expanded(
                    child: _buildProfileTab(
                      context: context,
                      section: _ProfileSection.liked,
                      icon: Icons.favorite_outline,
                      label: 'Liked',
                      isSelected: _profileSection == _ProfileSection.liked,
                      isFirst: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Content switcher
        ...switch (_profileSection) {
          _ProfileSection.settings => _buildSettingsSlivers(context),
          _ProfileSection.saved => _buildSavedSlivers(context, favoriteReels),
          _ProfileSection.liked =>
            _buildLikedSlivers(context, favoriteProducts),
        },

        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  List<Widget> _buildSettingsSlivers(BuildContext context) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.list(
          children: [
            _SettingsCard(children: [
              _settingsTile(
                icon: Icons.person_outline,
                color: Colors.indigo,
                title: 'Edit Profile',
                subtitle: 'Update your name, photo, email',
                onTap: () async {
                  final updated = await Navigator.push<UserProfile>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditProfileScreen(initialProfile: _profile),
                    ),
                  );
                  if (updated != null) {
                    setState(() => _profile = updated);
                    try {
                      await LocalUserProfileStore.save(updated);
                    } catch (_) {}
                    _showSnack('Profile updated');
                     // Seller module removed; no seller status to refresh
                  }
                },
              ),
              _settingsTile(
                icon: Icons.store_mall_directory_outlined,
                color: Colors.teal,
                title: 'Seller Dashboard',
                subtitle: 'Manage your products',
                onTap: () async {
                  // Reuse the existing user session; no extra login required
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SellerDashboardScreen()),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.notifications_none,
                color: Colors.orange,
                title: 'Notifications',
                subtitle: 'Marketing and order updates',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.lock_outline,
                color: Colors.red,
                title: 'Privacy & Security',
                subtitle: 'Password, 2FA, sessions',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacySecurityScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 12),
            _SettingsCard(children: [
              _settingsTile(
                icon: Icons.location_on_outlined,
                color: Colors.teal,
                title: 'Addresses',
                subtitle: 'Shipping and billing addresses',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.payment,
                color: Colors.purple,
                title: 'Payment Methods',
                subtitle: 'Cards, UPI, wallets',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PaymentMethodsScreen()),
                  );
                },
              ),
              _settingsTile(
                icon: Icons.receipt_long,
                color: Colors.blue,
                title: 'Orders',
                subtitle: 'Track and manage orders',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()),
                  );
                },
              ),
            ]),
            const SizedBox(height: 12),
            _SettingsCard(children: [
              _settingsTile(
                icon: Icons.logout,
                color: Colors.grey,
                title: 'Log out',
                subtitle: 'Sign out from this device',
                onTap: _confirmAndLogout,
              ),
            ]),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildSavedSlivers(
      BuildContext context, List<_DemoReel> favoriteReels) {
    final theme = Theme.of(context);
    if (favoriteReels.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bookmark_border,
                    size: 72, color: Colors.deepOrange),
                const SizedBox(height: 16),
                Text(
                  'No saved reels yet',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the bookmark or heart on a reel to save it here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.movie, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Text('Saved Reels',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 9 / 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final r = favoriteReels[index];
              return _SavedReelTile(
                reel: r,
                isSaved: true,
                onUnsave: () => _toggleSaveReel(r.id),
                onOpen: () {
                  // Open reels tab at this index
                  final all = _combinedReels;
                  final targetIndex = all.indexWhere((e) => e.id == r.id);
                  setState(() {
                    _reelStartIndex = targetIndex >= 0 ? targetIndex : 0;
                    _currentIndex = 1; // Reels tab (middle)
                  });
                },
              );
            },
            childCount: favoriteReels.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildLikedSlivers(
      BuildContext context, List<_DemoProduct> favoriteProducts) {
    final theme = Theme.of(context);
    if (favoriteProducts.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_border, size: 72, color: Colors.pink),
                const SizedBox(height: 16),
                Text(
                  'No liked products yet',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the heart on a product to like it and see it here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag, color: Colors.teal),
              const SizedBox(width: 8),
              Text('Liked Products',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        sliver: SliverLayoutBuilder(
          builder: (context, sliverConstraints) {
            final w = sliverConstraints.crossAxisExtent;
            int columns;
            if (w >= 1200) {
              columns = (w / 270).floor();
            } else if (w >= 900) {
              columns = (w / 250).floor();
            } else if (w >= 600) {
              columns = (w / 230).floor();
            } else {
              columns = (w / 210).floor();
            }
            columns = columns.clamp(2, 6);
            final childAspect =
                (w < 400) ? 0.60 : 0.65; // give extra height on compact screens

            return SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: childAspect,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = favoriteProducts[index];
                  return _ProductCard(
                    key: ValueKey(p.id),
                    product: p,
                    isFavorite: true,
                    onHeartPressed: () {
                      // Unfavorite from profile page
                      _toggleFavorite(p.id);
                    },
                    onTap: () {
                      List<String> gallery;
                      try {
                        final g = p.images;
                        gallery = g.isNotEmpty ? g : [p.imageUrl];
                      } catch (_) {
                        gallery = [p.imageUrl];
                      }
                      final data = ProductDetailData(
                        id: p.id,
                        name: p.name,
                        price: p.price,
                        imageUrl: p.imageUrl,
                        imageUrls: gallery,
                        rating: p.rating,
                        tag: p.tag,
                        description: p.description,
                        stock: p.stock,
                        condition: p.condition,
                        campus: p.campus,
                        pickupOnly: p.pickupOnly,
                        pickupLocation: p.pickupLocation,
                        negotiable: p.negotiable,
                        sellerId: p.sellerId,
                       updatedAt: p.updatedAt,
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: data),
                        ),
                      );
                    },
                  );
                },
                childCount: favoriteProducts.length,
              ),
            );
          },
        ),
      ),
    ];
  }

  ListTile _settingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmAndLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.subtitle});
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_bag_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Passage',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...children,
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onFilterPressed;
  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search campus listings',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (query.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: onClear,
                  tooltip: 'Clear',
                ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.deepPurple),
                onPressed: onFilterPressed,
                tooltip: 'Filter',
              ),
            ],
          ),
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  final RangeValues priceRange;
  final double minRating;
  final Set<String> selectedTags;
  final ValueChanged<String> onClearTag;
  final VoidCallback onClearAll;
  final VoidCallback onTapFilters;
  const _ActiveFiltersBar({
    required this.priceRange,
    required this.minRating,
    required this.selectedTags,
    required this.onClearTag,
    required this.onClearAll,
    required this.onTapFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    chips.add(_chip(context,
        label:
            '\$${priceRange.start.toStringAsFixed(0)} - \$${priceRange.end.toStringAsFixed(0)}',
        onDelete: null));
    if (minRating > 0) {
      chips.add(_chip(context,
          label: '${minRating.toStringAsFixed(1)}★+', onDelete: null));
    }
    for (final t in selectedTags) {
      chips.add(_chip(context, label: t, onDelete: () => onClearTag(t)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (chips.isEmpty)
                    InkWell(
                      onTap: onTapFilters,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.tune,
                                size: 18, color: Colors.deepPurple),
                            SizedBox(width: 6),
                            Text('Refine results'),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                        children: chips
                            .map((e) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: e))
                            .toList()),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onTapFilters,
            icon: const Icon(Icons.tune, color: Colors.deepPurple),
            label: const Text('Filters'),
          ),
          if (chips.isNotEmpty)
            TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.clear_all, color: Colors.red),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required String label, VoidCallback? onDelete}) {
    return Chip(
      label: Text(label),
      onDeleted: onDelete,
      deleteIcon: onDelete == null ? null : const Icon(Icons.close, size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

// ignore: unused_element
class _BouncyChoiceChip extends StatelessWidget {
  const _BouncyChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: selected ? 1.0 : 0.96, end: selected ? 1.0 : 0.96),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: selected ? 1.0 : 0.98,
          child: ChoiceChip(
            label: Text(label),
            avatar: Icon(icon,
                size: 18,
                color: selected ? Colors.white : theme.colorScheme.primary),
            selected: selected,
            onSelected: (_) => onTap(),
            selectedColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final _DemoProduct product;
  final bool isFavorite;
  final VoidCallback onHeartPressed;
  final VoidCallback onTap;
  final int? imageCacheWidth;
  final int? imageCacheHeight;
  _ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onHeartPressed,
    required this.onTap,
    this.imageCacheWidth,
    this.imageCacheHeight,
  });

  // Key to anchor the quick success overlay
  final GlobalKey _addBtnKey = GlobalKey(debugLabel: 'addBtn');

  Future<void> _showAddSuccessOverlay(BuildContext context) async {
    try {
      final box = _addBtnKey.currentContext?.findRenderObject() as RenderBox?;
      final overlay = Overlay.of(context);
      if (box == null) return;
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      final entry = OverlayEntry(builder: (context) {
        return Positioned(
          left: pos.dx + size.width / 2 - 14,
          top: pos.dy - 10,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 450),
            tween: Tween(begin: 0.6, end: 1.0),
            builder: (context, t, child) {
              final opacity = (1.2 - t).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(scale: t, child: child),
              );
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
          ),
        );
      });
      overlay.insert(entry);
      await Future.delayed(const Duration(milliseconds: 520));
      entry.remove();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InkWellScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Product image
                      _AnyImage(url: product.imageUrl, fit: BoxFit.cover),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _FavoriteButton(
                            active: isFavorite, onPressed: onHeartPressed),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(product.rating.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '\$${product.price.toStringAsFixed(2)}',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () async {
                              await LocalCartStore.addOrIncrement(CartItem(
                                productId: product.id,
                                name: product.name,
                                  imageUrl: product.imageUrl,
                                unitPrice: product.price,
                                quantity: 1,
                              ));
                              await _showAddSuccessOverlay(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Added ${product.name} to cart'),
                                    behavior: SnackBarBehavior.floating,
                                    action: SnackBarAction(
                                      label: 'View',
                                      onPressed: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const CartScreen()));
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              key: _addBtnKey,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.add_shopping_cart_rounded,
                                  color: Colors.teal, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  final bool active;
  final VoidCallback onPressed;
  const _FavoriteButton({required this.active, required this.onPressed});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
// no longer animating; retained for compatibility

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: widget.onPressed,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(
            widget.active ? Icons.favorite : Icons.favorite_border,
            color: widget.active ? Colors.pink : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _NetworkImageWithShimmer extends StatefulWidget {
  final String url;
  const _NetworkImageWithShimmer({required this.url});

  @override
  State<_NetworkImageWithShimmer> createState() =>
      _NetworkImageWithShimmerState();
}

class _NetworkImageWithShimmerState extends State<_NetworkImageWithShimmer> {

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final cw = (constraints.maxWidth.isFinite
                ? constraints.maxWidth * dpr
                : 512 * dpr)
            .clamp(64, 2048)
            .round();
        final ch = (constraints.maxHeight.isFinite
                ? constraints.maxHeight * dpr
                : 512 * dpr)
            .clamp(64, 2048)
            .round();
        return Image.network(
          widget.url,
          fit: BoxFit.cover,
          cacheWidth: cw,
          cacheHeight: ch,
          filterQuality: FilterQuality.low,
          errorBuilder: (context, error, stack) => Image.asset(
              'assets/icons/dreamflow_icon.jpg',
              fit: BoxFit.cover),
        );
      },
    );
  }
}

class _SavedReelTile extends StatelessWidget {
  final _DemoReel reel;
  final bool isSaved;
  final VoidCallback onUnsave;
  final VoidCallback onOpen;
  const _SavedReelTile(
      {required this.reel,
      required this.isSaved,
      required this.onUnsave,
      required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _AnyImage(url: reel.coverImageUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: onUnsave,
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved ? Colors.deepOrange : Colors.white),
              tooltip: isSaved ? 'Unsave' : 'Save',
            ),
          ),
          const Center(
              child:
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 48)),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Text(
              reel.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelsView extends StatefulWidget {
  final List<_DemoReel> reels;
  final Set<String> savedReelIds;
  final ValueChanged<String> onToggleSave;
  final ValueChanged<String> onOpenProduct;
  final int initialIndex;
  final VoidCallback onInitialIndexConsumed;
  const _ReelsView({
    required this.reels,
    required this.savedReelIds,
    required this.onToggleSave,
    required this.onOpenProduct,
    required this.initialIndex,
    required this.onInitialIndexConsumed,
  });

  @override
  State<_ReelsView> createState() => _ReelsViewState();
}

class _ReelsViewState extends State<_ReelsView> {
  late final PageController _pageController;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex.clamp(0, widget.reels.length - 1);
    _pageController = PageController(initialPage: _current);
    // Notify parent that we've consumed the initial index
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onInitialIndexConsumed());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: (i) => setState(() => _current = i),
      itemCount: widget.reels.length,
      itemBuilder: (context, index) {
        final reel = widget.reels[index];
        final isSaved = widget.savedReelIds.contains(reel.id);
        final isActive = index == _current;
        return _ReelPlayerCard(
          reel: reel,
          isSaved: isSaved,
          isActive: isActive,
          onToggleSave: () => widget.onToggleSave(reel.id),
          onOpenProduct: () => widget.onOpenProduct(reel.productId),
        );
      },
    );
  }
}

class _ReelPlayerCard extends StatefulWidget {
  final _DemoReel reel;
  final bool isSaved;
  final bool isActive;
  final VoidCallback onToggleSave;
  final VoidCallback onOpenProduct;
  const _ReelPlayerCard({
    required this.reel,
    required this.isSaved,
    required this.isActive,
    required this.onToggleSave,
    required this.onOpenProduct,
  });

  @override
  State<_ReelPlayerCard> createState() => _ReelPlayerCardState();
}

class _ReelPlayerCardState extends State<_ReelPlayerCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl));
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      if (_muted) {
        await c.setVolume(0);
      }
      setState(() {
        _initialized = true;
      });
      if (widget.isActive) {
        c.play();
      }
    } catch (_) {
      // ignore errors for demo
    }
  }

  @override
  void didUpdateWidget(covariant _ReelPlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive &&
        _controller != null &&
        _initialized) {
      if (widget.isActive) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        if (_initialized && _controller != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else
          // Placeholder with cover image before init
          Positioned.fill(
            child: _AnyImage(url: widget.reel.coverImageUrl, fit: BoxFit.cover),
          ),

        // Top-right actions (save)
        Positioned(
          top: 16,
          right: 12,
          child: Column(
            children: [
              _roundButton(
                icon: widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: widget.isSaved ? Colors.deepOrange : Colors.white,
                bg: Colors.black.withValues(alpha: 0.35),
                onTap: widget.onToggleSave,
              ),
              const SizedBox(height: 10),
              _roundButton(
                icon: _muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                bg: Colors.black.withValues(alpha: 0.35),
                onTap: () async {
                  setState(() => _muted = !_muted);
                  if (_controller != null) {
                    await _controller!.setVolume(_muted ? 0 : 1);
                  }
                },
              ),
            ],
          ),
        ),

        // Bottom gradient + caption and action
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.reel.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: widget.onOpenProduct,
                          icon: const Icon(Icons.shopping_bag,
                              color: Colors.teal),
                          label: const Text('View product'),
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(
      {required IconData icon,
      required Color color,
      required Color bg,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

class _AnyImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _AnyImage({
    required this.url,
    this.fit = BoxFit.cover,
  });

  String get _src => url.trim();
  bool get _isDataImage => _src.startsWith('data:image');

  @override
  Widget build(BuildContext context) {
    // Prepare src and soft-normalize legacy bucket host if present.
    String src = fixFirebaseDownloadUrl(_src);
    const kPrefix = 'https://firebasestorage.googleapis.com/';

    Widget networkOrPlaceholder({int? cw, int? ch}) {
      if (_isDataImage) {
        try {
          final base64Part = src.split(',').last;
          final bytes = base64Decode(base64Part);
          return Image.memory(
            bytes,
            fit: fit,
            cacheWidth: cw,
            cacheHeight: ch,
            filterQuality: FilterQuality.low,
          );
        } catch (_) {
          return Image.asset('assets/icons/dreamflow_icon.jpg', fit: fit);
        }
      }
      if (!src.startsWith(kPrefix)) {
        return Image.asset('assets/icons/dreamflow_icon.jpg', fit: fit);
      }
      return Image.network(
        src,
        fit: fit,
        cacheWidth: cw,
        cacheHeight: ch,
        filterQuality: FilterQuality.low,
        // Loading placeholder
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Theme.of(context).colorScheme.surfaceVariant,
          );
        },
        // Error placeholder
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/icons/dreamflow_icon.jpg', fit: fit),
      );
    }

    // Compute a reasonable cache size based on current constraints.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.of(context).devicePixelRatio;
        final cw = (constraints.maxWidth.isFinite
                ? constraints.maxWidth * dpr
                : 256 * dpr)
            .clamp(32, 2048)
            .round();
        final ch = (constraints.maxHeight.isFinite
                ? constraints.maxHeight * dpr
                : 256 * dpr)
            .clamp(32, 2048)
            .round();
        return networkOrPlaceholder(cw: cw, ch: ch);
      },
    );
  }
}

class _InkWellScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  const _InkWellScale(
      {required this.child, required this.onTap, required this.borderRadius});

  @override
  State<_InkWellScale> createState() => _InkWellScaleState();
}

class _InkWellScaleState extends State<_InkWellScale> {
  @override
  Widget build(BuildContext context) {
    // No scale animation; keep a simple, lightweight InkWell without splash/highlight
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: widget.borderRadius,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}

class _StaggeredFadeIn extends StatefulWidget {
  const _StaggeredFadeIn(
      {required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<_StaggeredFadeIn> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Limit staggered animations to the first ~24 items to avoid many timers
    if (widget.index <= 24) {
      _timer = Timer(Duration(milliseconds: 40 * (widget.index % 12)), () {
        if (mounted) setState(() => _visible = true);
      });
    } else {
      // Instantly show remaining items (no animation/jank for long lists)
      _visible = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      opacity: _visible ? 1 : 0,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        // Previously used an optional constructor parameter offsetY with a default of 18.
        // Since callers never override it, inline the effective offset factor (18 / 100 = 0.18).
        offset: _visible ? Offset.zero : const Offset(0, 0.18),
        child: widget.child,
      ),
    );
  }
}

class _DemoProduct {
  final String id;
  final String name;
  final double price;
  final String imageUrl; // primary
  final List<String> images; // optional gallery
  final double rating;
  final String tag;
  final String category;
  final String description;
  final int stock;
  final String condition;
  final String campus;
  final bool pickupOnly;
  final String pickupLocation;
  final bool negotiable;
  final String sellerId;
  final DateTime updatedAt;
  const _DemoProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.images = const [],
    required this.rating,
    required this.tag,
    required this.category,
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

class _DemoReel {
  final String id;
  final String productId;
  final String videoUrl;
  final String coverImageUrl;
  final String caption;
  const _DemoReel({
    required this.id,
    required this.productId,
    required this.videoUrl,
    required this.coverImageUrl,
    required this.caption,
  });
}

class _CategoryItem {
  final String label;
  final IconData icon;
  const _CategoryItem(this.label, this.icon);
}

enum _ProfileSection { settings, saved, liked }

enum _SortOption { recommended, priceLowHigh, priceHighLow, ratingHighLow }

String _sortLabel(_SortOption opt) {
  switch (opt) {
    case _SortOption.priceLowHigh:
      return 'Price: Low-High';
    case _SortOption.priceHighLow:
      return 'Price: High-Low';
    case _SortOption.ratingHighLow:
      return 'Rating';
    case _SortOption.recommended:
    return 'Recommended';
  }
}
