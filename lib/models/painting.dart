import '../core/utils/supabase_media_url.dart';

// Model for paintings table
class PaintingModel {
  final String id;
  final String artistId;
  final String title;
  final String? description;
  final String? medium;
  final String? dimensions;
  final String imageUrl;
  final List<String>? additionalImages;
  final double? price;
  final bool isForSale;
  final bool isSold;
  final List<String>? styleTags;
  final String? category;
  final String? style;
  final String? listingType;
  final String? status;
  final String? currency;
  final String? creatorLocation;
  final String? shopId;
  final String? collectionId;
  final String? nfcStatus;
  final String? solanaTxId;
  final bool isVerifiedArtwork;
  final bool nfcAttached;
  final int viewsCount;
  final int bidsCount;
  final int purchasesCount;
  final int? yearCreated;
  final String? sizeText;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final DateTime? createdAt;

  // Joined from profiles
  final String? artistDisplayName;
  final String? artistProfilePictureUrl;
  final bool? artistIsVerified;
  final String? artistType;

  // Aggregated
  final int likesCount;
  final bool isLikedByMe;

  const PaintingModel({
    required this.id,
    required this.artistId,
    required this.title,
    this.description,
    this.medium,
    this.dimensions,
    required this.imageUrl,
    this.additionalImages,
    this.price,
    this.isForSale = false,
    this.isSold = false,
    this.styleTags,
    this.category,
    this.style,
    this.listingType,
    this.status,
    this.currency,
    this.creatorLocation,
    this.shopId,
    this.collectionId,
    this.nfcStatus,
    this.solanaTxId,
    this.isVerifiedArtwork = false,
    this.nfcAttached = false,
    this.viewsCount = 0,
    this.bidsCount = 0,
    this.purchasesCount = 0,
    this.yearCreated,
    this.sizeText,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.createdAt,
    this.artistDisplayName,
    this.artistProfilePictureUrl,
    this.artistIsVerified,
    this.artistType,
    this.likesCount = 0,
    this.isLikedByMe = false,
  });

  factory PaintingModel.fromJson(Map<String, dynamic> json) {
    String? firstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final raw = json[key];
        if (raw is String && raw.trim().isNotEmpty) return raw.trim();
      }
      return null;
    }

    return PaintingModel(
      id: json['id'] as String,
      artistId: json['artist_id'] as String,
      title: json['title'] as String,
      description: firstNonEmpty(
        const ['description', 'caption', 'content', 'about', 'post_text'],
      ),
      medium: json['medium'] as String?,
      dimensions: json['dimensions'] as String?,
      imageUrl: (json['image_url'] as String?)?.trim() ?? '',
      additionalImages: (json['additional_images'] as List<dynamic>?)
          ?.map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isForSale: json['is_for_sale'] as bool? ?? false,
      isSold: json['is_sold'] as bool? ?? false,
      styleTags: (json['style_tags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      category: json['category'] as String?,
      style: json['style'] as String?,
      listingType: json['listing_type'] as String?,
      status: json['status'] as String?,
      currency: json['currency'] as String?,
      creatorLocation: json['creator_location'] as String?,
      shopId: json['shop_id'] as String?,
      collectionId: json['collection_id'] as String?,
      nfcStatus: json['nfc_status'] as String?,
      solanaTxId: json['solana_tx_id'] as String?,
      isVerifiedArtwork: (json['is_verified_artwork'] as bool?) ??
          (json['is_verified'] as bool?) ??
          false,
      nfcAttached: json['nfc_attached'] as bool? ?? false,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      bidsCount: (json['bids_count'] as num?)?.toInt() ?? 0,
      purchasesCount: (json['purchases_count'] as num?)?.toInt() ?? 0,
      yearCreated: (json['year_created'] as num?)?.toInt(),
      sizeText: json['size_text'] as String?,
      isBoosted: json['is_boosted'] as bool? ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.tryParse(json['boost_expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      // Joined profile fields
      artistDisplayName: firstNonEmpty(
        const ['display_name', 'artist_display_name', 'username'],
      ),
      artistProfilePictureUrl: firstNonEmpty(
        const ['profile_picture_url', 'artist_profile_picture_url', 'avatar_url'],
      ),
      artistIsVerified: (json['artist_is_verified'] as bool?) ??
          (json['artist_verified'] as bool?),
      artistType: json['artist_type'] as String?,
      // Aggregates
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['is_liked'] as bool? ?? false,
    );
  }

  String get displayPrice => price != null
      ? '₹${price!.toStringAsFixed(0)}'
      : 'Price on request';

  bool get isAvailable => isForSale && !isSold;

  bool get hasNfcAttached =>
      nfcAttached || (nfcStatus != null && nfcStatus != 'not_attached');

  /// Resolved CDN URL for the primary artwork image (fixes stale Supabase
  /// hosts, bare storage paths, and falls back to [additionalImages]).
  String get resolvedImageUrl {
    final primary = SupabaseMediaUrl.resolve(imageUrl);
    if (primary.isNotEmpty) return primary;
    final extras = additionalImages;
    if (extras == null) return '';
    for (final u in extras) {
      final r = SupabaseMediaUrl.resolve(u);
      if (r.isNotEmpty) return r;
    }
    return '';
  }

  String? get resolvedArtistAvatarUrl {
    final u = artistProfilePictureUrl?.trim();
    if (u == null || u.isEmpty) return null;
    return SupabaseMediaUrl.resolve(u);
  }
}
