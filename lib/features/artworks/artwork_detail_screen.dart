import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/painting.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/feed_provider.dart';
import '../../repositories/painting_repository.dart';
import '../../repositories/order_repository.dart';
import '../../services/payments/payment_service.dart';
import '../../widgets/feed/marketplace_media.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final String paintingId;
  final PaintingModel? initialPainting;

  const ArtworkDetailScreen({
    super.key,
    required this.paintingId,
    this.initialPainting,
  });

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  PaintingModel? _painting;
  bool _loading = true;
  String? _error;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _likeBusy = false;
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPainting != null) {
      _painting = widget.initialPainting;
      _isLiked = widget.initialPainting!.isLikedByMe;
      _likesCount = widget.initialPainting!.likesCount;
      _loading = false;
    }
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final painting =
          await PaintingRepository.getPaintingDetail(widget.paintingId);
      if (!mounted) return;

      setState(() {
        _painting = painting ?? _painting;
        _isLiked = painting?.isLikedByMe ?? _isLiked;
        _likesCount = painting?.likesCount ?? _likesCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = _painting == null;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/sign-in');
      return;
    }

    setState(() {
      _likeBusy = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await PaintingRepository.toggleLike(widget.paintingId);
      if (mounted) {
        context
            .read<FeedProvider>()
            .updateLikeLocally(widget.paintingId, _isLiked);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final painting = _painting;
    if (_loading && painting == null) {
      return _buildLoading();
    }
    if (painting == null) {
      return _buildError();
    }

    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            return SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(wide ? 30 : 18, 20, wide ? 30 : 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailTopBar(
                    isLiked: _isLiked,
                    likesCount: _likesCount,
                    likeBusy: _likeBusy,
                    onLikeTap: _toggleLike,
                  ),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _MediaColumn(painting: painting),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _DetailColumn(
                            painting: painting,
                            isLiked: _isLiked,
                            likesCount: _likesCount,
                            descExpanded: _descExpanded,
                            onToggleDescription: () =>
                                setState(() => _descExpanded = !_descExpanded),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _MediaColumn(painting: painting),
                    const SizedBox(height: 18),
                    _DetailColumn(
                      painting: painting,
                      isLiked: _isLiked,
                      likesCount: _likesCount,
                      descExpanded: _descExpanded,
                      onToggleDescription: () =>
                          setState(() => _descExpanded = !_descExpanded),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(child: MarketplaceShimmer()),
              SizedBox(height: 18),
              SizedBox(height: 120, child: MarketplaceShimmer()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.textTertiaryOf(context), size: 54),
              const SizedBox(height: 12),
              Text('Unable to open artwork',
                  style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_error ?? 'Unknown error',
                  style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: _loadDetail, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final bool likeBusy;
  final VoidCallback onLikeTap;

  const _DetailTopBar({
    required this.isLiked,
    required this.likesCount,
    required this.likeBusy,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.pop(),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimaryOf(context)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Artwork Detail',
            style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
        ),
        InkWell(
          onTap: likeBusy ? null : onLikeTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: isLiked
                      ? const Color(0xFFFF5D7A)
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 6),
                Text('$likesCount',
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaColumn extends StatelessWidget {
  final PaintingModel painting;

  const _MediaColumn({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderStrongOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: MarketplaceMediaFrame(
            imageUrl: painting.resolvedImageUrl,
            aspectRatio: 1,
            borderRadius: BorderRadius.circular(20),
          ),

        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderOf(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Authenticity-ready media with QR and NFC certificate pathways.',
                  style:
                      TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailColumn extends StatelessWidget {
  final PaintingModel painting;
  final bool isLiked;
  final int likesCount;
  final bool descExpanded;
  final VoidCallback onToggleDescription;

  const _DetailColumn({
    required this.painting,
    required this.isLiked,
    required this.likesCount,
    required this.descExpanded,
    required this.onToggleDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          painting.title,
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.06,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        _ArtistIdentityCard(painting: painting),
        const SizedBox(height: 14),
        _InfoChips(painting: painting, likesCount: likesCount),
        const SizedBox(height: 16),
        _ActionZone(painting: painting),
        const SizedBox(height: 18),
        _DescriptionPanel(
          description: painting.description,
          expanded: descExpanded,
          onToggle: onToggleDescription,
        ),
        if (painting.styleTags != null && painting.styleTags!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: painting.styleTags!
                .take(10)
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        _ProvenanceCard(painting: painting),
      ],
    );
  }
}

class _ArtistIdentityCard extends StatelessWidget {
  final PaintingModel painting;

  const _ArtistIdentityCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/public-profile/${painting.artistId}'),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.surfaceMutedOf(context),
              backgroundImage: painting.resolvedArtistAvatarUrl != null
                  ? CachedNetworkImageProvider(
                      painting.resolvedArtistAvatarUrl!,
                    )
                  : null,
              child: painting.resolvedArtistAvatarUrl == null
                  ? Icon(Icons.person_rounded,
                      color: AppColors.textSecondaryOf(context))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          painting.artistDisplayName ?? 'Artyug Artist',
                          style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (painting.artistIsVerified ?? false)
                        Icon(Icons.verified_rounded,
                            color: AppColors.info, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    painting.artistType ?? 'Creator',
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiaryOf(context)),
          ],
        ),
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  final PaintingModel painting;
  final int likesCount;

  const _InfoChips({required this.painting, required this.likesCount});

  @override
  Widget build(BuildContext context) {
    final chips = <(IconData, String)>[
      (Icons.favorite_rounded, '$likesCount likes'),
      (
        Icons.local_offer_rounded,
        painting.price != null ? painting.displayPrice : 'Not listed'
      ),
      if (painting.medium != null) (Icons.brush_rounded, painting.medium!),
      if (painting.dimensions != null)
        (Icons.straighten_rounded, painting.dimensions!),
      if (painting.category != null)
        (Icons.category_rounded, painting.category!),
      if (painting.listingType != null)
        (Icons.sell_outlined, painting.listingType!.replaceAll('_', ' ')),
      if (painting.yearCreated != null)
        (Icons.calendar_month_outlined, '${painting.yearCreated}'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (chip) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.$1, size: 14, color: AppColors.textSecondaryOf(context)),
                  const SizedBox(width: 6),
                  Text(chip.$2,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ActionZone extends StatelessWidget {
  final PaintingModel painting;

  const _ActionZone({required this.painting});

  @override
  Widget build(BuildContext context) {
    final listingType = painting.listingType ?? 'fixed_price';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderStrongOf(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: listingType == 'auction'
                    ? ElevatedButton.icon(
                        onPressed: () => _openAuction(context),
                        icon: Icon(Icons.gavel_rounded, size: 18),
                        label: const Text('Place Bid'),
                      )
                    : painting.isAvailable
                        ? ElevatedButton.icon(
                            onPressed: () => _openBuyIntent(context),
                            icon: Icon(Icons.shopping_bag_rounded, size: 18),
                            label: Text('Buy for ${painting.displayPrice}'),
                          )
                        : OutlinedButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.block_rounded, size: 18),
                            label: Text(painting.isSold ? 'Sold' : 'Not listed'),
                          ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/authenticity-center'),
                  icon: Icon(Icons.verified_user_rounded, size: 18),
                  label: const Text('Verify'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: 'artyug://artwork/${painting.id}'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Artwork link copied')));
                  },
                  icon: Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAuction(BuildContext context) async {
    try {
      final row = await Supabase.instance.client
          .from('auctions')
          .select('id, status, end_time')
          .eq('painting_id', painting.id)
          .inFilter('status', ['active', 'live', 'upcoming', 'pending'])
          .order('end_time', ascending: true)
          .limit(1)
          .maybeSingle();
      final auctionId = row?['id']?.toString();
      if (auctionId == null || auctionId.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No live auction found for this artwork.')),
        );
        return;
      }
      if (!context.mounted) return;
      context.push('/auction/$auctionId');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open auction right now.')),
      );
    }
  }

  /// Smart buy intent:
  /// - Demo mode → routes to /checkout/{id} (CheckoutScreen handles demo wallet)
  /// - Live mode → direct Razorpay → Solana mainnet memo attestation
  Future<void> _openBuyIntent(BuildContext ctx) async {
    final auth = ctx.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ctx.push('/sign-in');
      return;
    }

    final amountInr = (painting.price ?? 0).toDouble();
    if (amountInr <= 0) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('This artwork has no price set.')),
      );
      return;
    }

    // In demo mode: delegate to CheckoutScreen which handles demo wallet
    final isLive = ctx.read<AppModeProvider>().isLiveMode;
    if (!isLive) {
      ctx.push('/checkout/${painting.id}', extra: painting);
      return;
    }

    // ── Live mode: Razorpay → Solana mainnet memo attestation ────────────────
    // Step 1: Show spinner while Edge Function creates the Razorpay order
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await PaymentService.initiateRazorpayPayment(
        artworkId: painting.id,
        amountInr: amountInr,
        artworkTitle: painting.title,
        contactEmail: auth.user?.email,
      );

      if (!ctx.mounted) return;
      Navigator.of(ctx, rootNavigator: true).pop(); // dismiss order-creation spinner

      if (result == null || !result.success) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(result?.errorMessage ??
                'Payment cancelled or failed. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Step 2: Payment succeeded — record order + Solana mainnet memo
      if (!ctx.mounted) return;
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Recording on blockchain\u2026',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      );

      OrderResult orderResult;
      try {
        orderResult = await OrderRepository.createLiveOrder(
          paintingId: painting.id,
          razorpayOrderId: result.razorpayOrderId ?? '',
          razorpayPaymentId: result.razorpayPaymentId ?? '',
          amountPaid: amountInr,
        );
      } catch (e) {
        if (ctx.mounted) {
          Navigator.of(ctx, rootNavigator: true).pop();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('Payment received but order recording failed: $e'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      if (!ctx.mounted) return;
      Navigator.of(ctx, rootNavigator: true).pop(); // dismiss blockchain loader

      // Step 3: Navigate to confirmation with certificate + Solscan URL
      ctx.push('/order-confirm', extra: orderResult);
    } catch (e) {
      if (ctx.mounted) {
        Navigator.of(ctx, rootNavigator: true).pop();
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Checkout error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _DescriptionPanel extends StatelessWidget {
  final String? description;
  final bool expanded;
  final VoidCallback onToggle;

  const _DescriptionPanel(
      {required this.description,
      required this.expanded,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    if (description == null || description!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About this artwork',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            description!,
            maxLines: expanded ? null : 4,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
                color: AppColors.textSecondaryOf(context), fontSize: 13, height: 1.55),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: onToggle,
              child: Text(expanded ? 'Show less' : 'Read more')),
        ],
      ),
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  final PaintingModel painting;

  const _ProvenanceCard({required this.painting});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Provenance & Authenticity',
              style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _LineRow(
              label: 'Artwork ID',
              value: painting.id.substring(0, 8).toUpperCase()),
          _LineRow(
              label: 'Creator',
              value: painting.artistDisplayName ?? 'Artyug Artist'),
          _LineRow(
              label: 'Status',
              value: painting.isAvailable
                  ? 'Available'
                  : (painting.isSold ? 'Sold' : 'Not listed')),
          _LineRow(
              label: 'Verification',
              value: painting.isVerifiedArtwork ? 'Verified artwork' : 'Verification pending'),
          _LineRow(
              label: 'NFC',
              value: painting.nfcStatus ?? (painting.hasNfcAttached ? 'attached' : 'not_attached')),
          if (painting.solanaTxId != null && painting.solanaTxId!.isNotEmpty)
            _LineRow(label: 'Solana Tx', value: painting.solanaTxId!),
          _LineRow(
              label: 'Certificate',
              value: 'Available via Artyug authenticity center'),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final String label;
  final String value;

  const _LineRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textTertiaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppColors.textSecondaryOf(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

