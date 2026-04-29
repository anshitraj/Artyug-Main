/// My Studios — manage studios (maps to DB `shops` table).
/// Free creators: max 2 studios. Premium: unlimited.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';

const _kFreeGalleryLimit = 2;

class MyGalleriesScreen extends StatefulWidget {
  const MyGalleriesScreen({super.key});

  @override
  State<MyGalleriesScreen> createState() => _MyGalleriesScreenState();
}

class _MyGalleriesScreenState extends State<MyGalleriesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _studios = [];
  bool _loading = true;
  String _plan = 'free';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // Fetch user plan
      final profile = await _client
          .from('profiles')
          .select('plan')
          .eq('id', uid)
          .maybeSingle();
      _plan = (profile?['plan'] as String?) ?? 'free';

      // Fetch studios
      final data = await _client
          .from('shops')
          .select('id, name, description, avatar_url, banner_url, is_active, created_at')
          .eq('owner_id', uid)
          .order('created_at', ascending: false);
      _studios = List<Map<String, dynamic>>.from(data as List);
    } catch (e) {
      debugPrint('[MyGalleries] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _canCreateMore =>
      _plan == 'premium' || _studios.length < _kFreeGalleryLimit;

  void _createGallery() {
    if (_canCreateMore) {
      context.push('/create-gallery');
    } else {
      _showUpgradeDialog();
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6A2B), Color(0xFFE8470A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upgrade to Creator Pro',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Free creators can manage up to 2 studios.\n'
                'Upgrade to Creator Pro to unlock unlimited studios, '
                'a verified badge, priority marketplace listing, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              // Feature highlights
              ...[
                ('Unlimited studios', Icons.collections_rounded),
                ('Verified creator badge', Icons.verified_rounded),
                ('Priority marketplace listing', Icons.trending_up_rounded),
                ('Advanced analytics', Icons.insights_rounded),
                ('Custom studio covers', Icons.image_rounded),
                ('Early access to auctions', Icons.gavel_rounded),
              ].map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(f.$2,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(f.$1,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push('/premium');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('View Creator Pro',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later',
                    style: TextStyle(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleGallery(String id, bool currentActive) async {
    try {
      await _client.from('shops').update({
        'is_active': !currentActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteGallery(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete studio',
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'This will remove the studio but your artworks will remain in your account.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _client.from('shops').delete().eq('id', id);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('studio deleted'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
        ),
        title: const Text(
          'My Studios',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          // Plan badge
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: _plan == 'premium'
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6A2B), Color(0xFFE8470A)])
                  : null,
              color: _plan == 'free' ? AppColors.surfaceVariant : null,
              borderRadius: BorderRadius.circular(100),
              border: _plan == 'free'
                  ? Border.all(color: AppColors.border)
                  : null,
            ),
            child: Text(
              _plan == 'premium' ? '✦ PRO' : 'FREE',
              style: TextStyle(
                color: _plan == 'premium'
                    ? Colors.white
                    : AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGallery,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('New studio',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: _studios.isEmpty
                  ? _buildEmptyState()
                  : _buildstudioList(),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: AppColors.primary, size: 44),
              ),
              const SizedBox(height: 20),
              const Text(
                'No studios yet',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create your first studio to start listing\n'
                'artworks for sale in the marketplace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/create-gallery'),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create studio',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildstudioList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _studios.length + 1, // +1 for the limit card at bottom
      itemBuilder: (context, index) {
        if (index == _studios.length) {
          return _buildLimitInfo();
        }
        return _studioCard(
          studio: _studios[index],
          onToggle: () => _toggleGallery(
            _studios[index]['id'] as String,
            _studios[index]['is_active'] as bool? ?? true,
          ),
          onDelete: () => _deleteGallery(
            _studios[index]['id'] as String,
            _studios[index]['name'] as String? ?? 'studio',
          ),
        );
      },
    );
  }

  Widget _buildLimitInfo() {
    final used = _studios.length;
    final limit = _plan == 'premium' ? '∞' : '$_kFreeGalleryLimit';
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              _plan == 'premium'
                  ? Icons.all_inclusive_rounded
                  : Icons.info_outline_rounded,
              color: AppColors.textTertiary,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$used of $limit studios used',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (_plan == 'free')
              GestureDetector(
                onTap: () => context.push('/premium'),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _studioCard extends StatelessWidget {
  final Map<String, dynamic> studio;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _studioCard({
    required this.studio,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = studio['name'] as String? ?? 'Untitled studio';
    final desc = studio['description'] as String?;
    final avatarUrl = studio['avatar_url'] as String?;
    final bannerUrl = studio['banner_url'] as String?;
    final isActive = studio['is_active'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / avatar strip
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(17)),
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner
                  if (bannerUrl != null)
                    CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      color: Colors.black26,
                      colorBlendMode: BlendMode.darken,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.surfaceVariant,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // Avatar overlay
                  Positioned(
                    left: 14,
                    bottom: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.2),
                        backgroundImage: avatarUrl != null
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'G',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  // Status badge
                  Positioned(
                    right: 12,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.success.withValues(alpha: 0.2)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isActive
                              ? AppColors.success.withValues(alpha: 0.4)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isActive ? 'Active' : 'Paused',
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.textTertiary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info + actions
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Action chips
                Row(
                  children: [
                    _ActionChip(
                      icon: isActive
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      label: isActive ? 'Pause' : 'Activate',
                      onTap: onToggle,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      destructive: true,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.error : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


