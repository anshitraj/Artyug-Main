import 'package:supabase_flutter/supabase_flutter.dart';

class StudioService {
  StudioService._();

  static final SupabaseClient _db = Supabase.instance.client;

  /// Idempotent creator backfill:
  /// - If creator has no shop/studio, create a default studio.
  /// - Attach their existing artworks without shop_id to the created studio.
  /// - Create default "Featured Works" collection only once.
  static Future<void> ensureCreatorDefaultStudio(String userId) async {
    try {
      final profile = await _db
          .from('profiles')
          .select('id, role, username, display_name, bio, artist_type')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return;
      final role = (profile['role'] as String?)?.toLowerCase();
      if (role != 'creator') return;

      final existing = await _db
          .from('shops')
          .select('id')
          .eq('owner_id', userId)
          .limit(1)
          .maybeSingle();
      if (existing != null) return;

      final displayName = (profile['display_name'] as String?)?.trim();
      final username = (profile['username'] as String?)?.trim();
      final artistType = (profile['artist_type'] as String?)?.trim();
      final base = (displayName?.isNotEmpty == true
              ? displayName!
              : (username?.isNotEmpty == true ? username! : 'Creator'))
          .trim();

      final studioName = '$base Studio';
      final slug = _slugify(studioName);
      final bio = (profile['bio'] as String?)?.trim();

      final shopRow = await _db
          .from('shops')
          .insert({
            'owner_id': userId,
            'name': studioName,
            'slug': '${slug}-${userId.substring(0, 6)}',
            'description': (bio?.isNotEmpty == true)
                ? bio
                : 'A curated studio by $base.',
            'category': (artistType?.isNotEmpty == true)
                ? artistType
                : 'Contemporary Art',
            'status': 'active',
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final shopId = shopRow['id']?.toString();
      if (shopId == null || shopId.isEmpty) return;

      // Attach published artworks currently not linked to any studio.
      try {
        await _db
            .from('paintings')
            .update({'shop_id': shopId})
            .eq('artist_id', userId)
            .isFilter('shop_id', null)
            .neq('is_sold', true);
      } catch (_) {
        // Safe no-op if schema differs.
      }

      // Create default collection (idempotent via existence check).
      try {
        final existingCollection = await _db
            .from('collections')
            .select('id')
            .eq('shop_id', shopId)
            .eq('name', 'Featured Works')
            .maybeSingle();
        if (existingCollection == null) {
          await _db.from('collections').insert({
            'shop_id': shopId,
            'name': 'Featured Works',
            'slug': 'featured-works',
            'description': 'Signature works from this studio.',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      } catch (_) {
        // Optional enhancement only.
      }
    } catch (_) {
      // Never block auth/session flows on studio backfill.
    }
  }

  static Future<List<Map<String, dynamic>>> getFeaturedStudios({
    int limit = 10,
  }) async {
    try {
      final rows = await _db
          .from('shops')
          .select(
              'id, name, slug, description, avatar_url, cover_image_url, category, created_at, owner_id, profiles:owner_id(display_name, profile_picture_url, is_verified)')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);

      final studios = List<Map<String, dynamic>>.from(rows as List);
      final enriched = <Map<String, dynamic>>[];
      for (final s in studios) {
        final shopId = s['id']?.toString();
        int works = 0;
        int collections = 0;
        int views = 0;
        int likes = 0;
        if (shopId != null && shopId.isNotEmpty) {
          try {
            final arts = await _db
                .from('paintings')
                .select('id, views_count, likes_count, created_at')
                .eq('shop_id', shopId)
                .limit(300);
            final list = List<Map<String, dynamic>>.from(arts as List);
            works = list.length;
            views = list.fold<int>(
                0, (acc, e) => acc + ((e['views_count'] as num?)?.toInt() ?? 0));
            likes = list.fold<int>(
                0, (acc, e) => acc + ((e['likes_count'] as num?)?.toInt() ?? 0));
          } catch (_) {}
          try {
            final cols = await _db
                .from('collections')
                .select('id')
                .eq('shop_id', shopId);
            collections = (cols as List).length;
          } catch (_) {}
        }
        final createdAt =
            DateTime.tryParse((s['created_at'] ?? '').toString()) ??
                DateTime.now();
        final recencyBoost =
            (30 - DateTime.now().difference(createdAt).inDays).clamp(0, 30);
        final trendingScore = (works * 4) + (collections * 6) + views + (likes * 3) + recencyBoost;
        enriched.add({
          ...s,
          'artworks_count': works,
          'collections_count': collections,
          'views_count': views,
          'likes_count': likes,
          'trending_score': trendingScore,
        });
      }
      enriched.sort((a, b) => ((b['trending_score'] as num?) ?? 0)
          .compareTo((a['trending_score'] as num?) ?? 0));
      return enriched;
    } catch (_) {
      return [];
    }
  }

  static String _slugify(String input) {
    final lower = input.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
    return cleaned.trim().replaceAll(RegExp(r'[\s-]+'), '-');
  }
}
