import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class MarketplaceMediaFrame extends StatelessWidget {
  static const String sampleImageUrl =
      'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?auto=format&fit=crop&w=1200&q=80';
  final String imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;
  final bool showGradientOverlay;
  final String? heroTag;

  const MarketplaceMediaFrame({
    super.key,
    required this.imageUrl,
    this.aspectRatio = 4 / 3,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.showGradientOverlay = false,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) {
      Widget empty = ClipRRect(
        borderRadius: borderRadius,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: const _MediaFallback(),
        ),
      );
      if (heroTag != null) {
        empty = Hero(tag: heroTag!, child: empty);
      }
      return empty;
    }

    Widget content = ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => const MarketplaceShimmer(),
              errorWidget: (_, __, ___) =>
                  const _MediaFallback(showSampleLabel: true),
            ),
            if (showGradientOverlay)
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.cardOverlay),
              ),
          ],
        ),
      ),
    );

    if (heroTag != null) {
      content = Hero(tag: heroTag!, child: content);
    }
    return content;
  }
}

class MarketplaceShimmer extends StatefulWidget {
  const MarketplaceShimmer({super.key});

  @override
  State<MarketplaceShimmer> createState() => _MarketplaceShimmerState();
}

class _MarketplaceShimmerState extends State<MarketplaceShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _position = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (_, __) {
        final muted = AppColors.surfaceMutedOf(context);
        final hi = AppColors.surfaceHighOf(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_position.value, -0.1),
              end: Alignment(_position.value + 1.1, 0.1),
              colors: [muted, hi, muted],
            ),
          ),
        );
      },
    );
  }
}

class _MediaFallback extends StatelessWidget {
  final bool showSampleLabel;

  const _MediaFallback({this.showSampleLabel = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          MarketplaceMediaFrame.sampleImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surfaceMutedOf(context),
            alignment: Alignment.center,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textTertiaryOf(context),
              size: 28,
            ),
          ),
        ),
        if (showSampleLabel)
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Sample image',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
