import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../widgets/premium/premium_ui.dart';

class ShopDetailScreen extends StatefulWidget {
  final String shopSlug;

  const ShopDetailScreen({super.key, required this.shopSlug});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final _client = Supabase.instance.client;

  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _collections = [];
  List<PaintingModel> _artworks = [];
  bool _loading = true;
  String? _error;
  String _sort = 'newest';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shop = await _client
          .from('shops')
          .select('*')
          .eq('slug', widget.shopSlug)
          .maybeSingle();

      if (shop == null) {
        throw Exception('Studio not found');
      }

      final shopId = shop['id'] as String;

      List<Map<String, dynamic>> collRows = [];
      try {
        final collections = await _client
            .from('collections')
            .select('*')
            .eq('shop_id', shopId)
            .order('created_at', ascending: false)
            .limit(24);
        collRows = List<Map<String, dynamic>>.from(collections as List);
      } catch (_) {
        collRows = [];
      }

      dynamic paintingsQuery = _client
          .from('paintings')
          .select('''
            id, artist_id, title, description, medium, dimensions, image_url, additional_images,
            price, is_for_sale, is_sold, style_tags, category, created_at, listing_type,
            shop_id, collection_id, is_verified, nfc_status, solana_tx_id, currency,
            profiles:artist_id(display_name, profile_picture_url, is_verified)
          ''')
          .eq('shop_id', shopId)
          .eq('is_sold', false);

      switch (_sort) {
        case 'price_asc':
          paintingsQuery = paintingsQuery.order('price', ascending: true);
          break;
        case 'price_desc':
          paintingsQuery = paintingsQuery.order('price', ascending: false);
          break;
        default:
          paintingsQuery = paintingsQuery.order('created_at', ascending: false);
      }

      final artworksData = await paintingsQuery.limit(80);
      final artworks = (artworksData as List<dynamic>).map((row) {
        final json = row as Map<String, dynamic>;
        final profile = json['profiles'] as Map<String, dynamic>?;
        return PaintingModel.fromJson({
          ...json,
          'display_name': profile?['display_name'],
          'profile_picture_url': profile?['profile_picture_url'],
          'artist_is_verified': profile?['is_verified'],
          'is_verified_artwork': json['is_verified'],
        });
      }).toList();

      if (!mounted) return;
      setState(() {
        _shop = Map<String, dynamic>.from(shop);
        _collections = collRows;
        _artworks = artworks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null || _shop == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.store_mall_directory_outlined, color: AppColors.textTertiary, size: 42),
                const SizedBox(height: 10),
                Text(_error ?? 'Unable to load studio', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    final shop = _shop!;
    final name = shop['name']?.toString() ?? 'Studio';
    final description = shop['description']?.toString();
    final cover = shop['cover_image_url']?.toString() ?? shop['banner_url']?.toString();
    final avatar = shop['avatar_url']?.toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackdrop(
            glows: [
              PremiumGlowSpec(
                alignment: Alignment(-0.9, -0.85),
                size: 270,
                color: Color(0x33FF6A2B),
              ),
              PremiumGlowSpec(
                alignment: Alignment(0.9, -0.2),
                size: 290,
                color: Color(0x224F8BFF),
              ),
            ],
          ),
          CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF121B2C), Color(0xFF0B101A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.cardOverlay)),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.surface,
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  name.isEmpty ? 'S' : name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null && description.isNotEmpty)
                    Text(description, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('${_artworks.length} artworks', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                      const Spacer(),
                      DropdownButton<String>(
                        value: _sort,
                        dropdownColor: AppColors.surfaceVariant,
                        style: const TextStyle(color: AppColors.textSecondary),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'newest', child: Text('Newest')),
                          DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
                          DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                          _load();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionHeader(
                title: 'Collections',
                subtitle: _collections.isEmpty ? 'No collections yet' : '${_collections.length} collections',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _collections.isEmpty
                ? const _InlineEmptyState(
                    title: 'This studio has no collections',
                    cta: 'Browse all artworks',
                  )
                : SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _collections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final c = _collections[i];
                        final coverUrl = c['cover_image_url']?.toString();
                        return GestureDetector(
                          onTap: () {
                            final slug = c['slug']?.toString() ?? c['id'].toString();
                            context.push('/shop/${widget.shopSlug}/collection/$slug');
                          },
                          child: Container(
                            width: 220,
                            decoration: premiumGlassDecoration(
                              borderRadius: BorderRadius.circular(14),
                              shadowAlpha: 0.18,
                              shadowBlur: 16,
                              shadowOffset: const Offset(0, 8),
                              gradientColors: [
                                AppColors.surface.withValues(alpha: 0.9),
                                AppColors.surfaceVariant.withValues(alpha: 0.72),
                              ],
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (coverUrl != null && coverUrl.isNotEmpty)
                                  CachedNetworkImage(imageUrl: coverUrl, fit: BoxFit.cover)
                                else
                                  Container(color: AppColors.surfaceVariant),
                                const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.cardOverlay)),
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Text(
                                    c['name']?.toString() ?? 'Collection',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _SectionHeader(title: 'Artworks', subtitle: 'From this studio'),
            ),
          ),
          if (_artworks.isEmpty)
            const SliverToBoxAdapter(
              child: _InlineEmptyState(
                    title: 'No active artworks in this studio',
                cta: 'Check back soon',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final art = _artworks[i];
                    return PremiumStaggerReveal(
                      index: i,
                      child: GestureDetector(
                      onTap: () => context.push('/artwork/${art.id}', extra: art),
                      child: Container(
                        decoration: premiumGlassDecoration(
                          borderRadius: BorderRadius.circular(12),
                          shadowAlpha: 0.16,
                          shadowBlur: 14,
                          shadowOffset: const Offset(0, 7),
                          gradientColors: [
                            AppColors.surface.withValues(alpha: 0.9),
                            AppColors.surfaceVariant.withValues(alpha: 0.7),
                          ],
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: art.resolvedImageUrl.isEmpty
                                  ? Container(color: AppColors.surfaceVariant)
                                  : CachedNetworkImage(imageUrl: art.resolvedImageUrl, fit: BoxFit.cover, width: double.infinity),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(art.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(art.displayPrice, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ));
                  },
                  childCount: _artworks.length,
                ),
              ),
            ),
        ],
      ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  final String title;
  final String cta;

  const _InlineEmptyState({required this.title, required this.cta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: premiumGlassDecoration(
          borderRadius: BorderRadius.circular(12),
          shadowAlpha: 0,
          gradientColors: [
            AppColors.surfaceVariant.withValues(alpha: 0.86),
            AppColors.surface.withValues(alpha: 0.72),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(cta, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
