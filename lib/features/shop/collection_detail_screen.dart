import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../widgets/premium/premium_ui.dart';

class CollectionDetailScreen extends StatefulWidget {
  final String shopSlug;
  final String collectionSlug;

  const CollectionDetailScreen({
    super.key,
    required this.shopSlug,
    required this.collectionSlug,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final _client = Supabase.instance.client;

  Map<String, dynamic>? _shop;
  Map<String, dynamic>? _collection;
  List<PaintingModel> _artworks = [];
  bool _loading = true;
  String? _error;

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
      if (shop == null) throw Exception('Studio not found');

      final shopId = shop['id'] as String;

      Map<String, dynamic>? collection = await _client
          .from('collections')
          .select('*')
          .eq('shop_id', shopId)
          .eq('slug', widget.collectionSlug)
          .maybeSingle();

      collection ??= await _client
          .from('collections')
          .select('*')
          .eq('shop_id', shopId)
          .eq('id', widget.collectionSlug)
          .maybeSingle();

      if (collection == null) throw Exception('Collection not found');

      final collectionId = collection['id'] as String;
      final rows = await _client
          .from('paintings')
          .select('''
            id, artist_id, title, description, medium, dimensions, image_url, additional_images,
            price, is_for_sale, is_sold, style_tags, category, created_at, listing_type,
            collection_id, is_verified, nfc_status, solana_tx_id, currency,
            profiles:artist_id(display_name, profile_picture_url, is_verified)
          ''')
          .eq('collection_id', collectionId)
          .eq('is_sold', false)
          .order('created_at', ascending: false)
          .limit(80);

      final artworks = (rows as List<dynamic>).map((row) {
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
        _collection = Map<String, dynamic>.from(collection!);
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

    if (_error != null || _collection == null || _shop == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'Unable to load collection', style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }

    final collection = _collection!;
    final shop = _shop!;
    final cover = collection['cover_image_url']?.toString();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection['name']?.toString() ?? 'Collection'),
            Text(
              shop['name']?.toString() ?? 'Studio',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackdrop(
            glows: [
              PremiumGlowSpec(
                alignment: Alignment(-0.85, -0.85),
                size: 260,
                color: Color(0x33FF6A2B),
              ),
            ],
          ),
          CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 2.2,
                  child: cover != null && cover.isNotEmpty
                      ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                      : Container(color: AppColors.surfaceVariant),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(collection['name']?.toString() ?? 'Collection', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(collection['description']?.toString() ?? 'Curated collection from this studio.',
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
          ),
          if (_artworks.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _CollectionEmptyState(),
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

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This collection has no artworks yet', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Check back soon for new listings.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
