import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/canonical_guilds.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/supabase_media_url.dart';
import '../../providers/auth_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _officialGuilds = [];
  bool _loading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchOfficialGuilds(), _fetchConversations()]);
  }

  Future<void> _fetchOfficialGuilds() async {
    try {
      final list = await CanonicalGuilds.fetchOfficialCommunities(_supabase);
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final row in list) {
        final id = (row['id'] ?? '').toString();
        final key = id.isNotEmpty ? id : (row['name'] ?? '').toString().toLowerCase();
        if (seen.add(key)) deduped.add(row);
      }
      if (mounted) setState(() => _officialGuilds = deduped);
    } catch (_) {
      if (mounted) setState(() => _officialGuilds = []);
    }
  }

  Future<void> _fetchConversations() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }

      final response = await _supabase
          .from('conversations')
          .select('*')
          .or('participant1_id.eq.${user.id},participant2_id.eq.${user.id}')
          .order('updated_at', ascending: false);

      if (response.isEmpty) {
        if (!mounted) return;
        setState(() {
          _conversations = [];
          _loading = false;
        });
        return;
      }

      final conversationsData = List<Map<String, dynamic>>.from(response);

      final participantIds = <String>{};
      for (final conv in conversationsData) {
        if (conv['participant1_id'] != null) participantIds.add(conv['participant1_id'] as String);
        if (conv['participant2_id'] != null) participantIds.add(conv['participant2_id'] as String);
      }
      participantIds.remove(user.id);

      final profilesResponse = await _supabase
          .from('profiles')
          .select('id, username, display_name, profile_picture_url')
          .inFilter('id', participantIds.toList());

      final profilesData = List<Map<String, dynamic>>.from(profilesResponse);
      final profilesMap = {for (final p in profilesData) p['id']: p};

      final withDetails = await Future.wait(
        conversationsData.map((conversation) async {
          final otherUserId = conversation['participant1_id'] == user.id
              ? conversation['participant2_id'] as String
              : conversation['participant1_id'] as String;

          final otherUser = profilesMap[otherUserId] ?? {};

          final lastMessageResponse = await _supabase
              .from('messages')
              .select('*')
              .eq('conversation_id', conversation['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          final unreadResponse = await _supabase
              .from('messages')
              .select('id')
              .eq('conversation_id', conversation['id'])
              .eq('is_read', false)
              .neq('sender_id', user.id);

          final unreadCount = (unreadResponse as List).length;

          return {
            ...conversation,
            'other_user': otherUser,
            'other_user_id': otherUserId,
            'last_message': lastMessageResponse,
            'unread_count': unreadCount,
          };
        }),
      );

      if (!mounted) return;
      setState(() {
        _conversations = withDetails;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conversations = [];
        _loading = false;
      });
    }
  }

  void _setupRealtimeSubscription() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    _subscription = _supabase
        .channel('conversations:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _fetchConversations(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant1_id',
            value: user.id,
          ),
          callback: (_) => _fetchConversations(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'participant2_id',
            value: user.id,
          ),
          callback: (_) => _refreshAll(),
        )
        .subscribe();
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _surfaceCard(BuildContext context, Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: child,
    );
  }

  Widget _buildGuildChannelCard(Map<String, dynamic> community) {
    final name = community['name'] as String? ?? 'Guild';
    final id = (community['id'] ?? '').toString();
    final n = Uri.encodeComponent(name);
    final avatarRaw = (community['avatar_url'] as String?)?.trim();
    final avatar = SupabaseMediaUrl.resolve(avatarRaw);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _surfaceCard(
        context,
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: id.isEmpty ? null : () => context.push('/community-chat/$id?name=$n'),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accentSoftOf(context),
                  backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                  child: avatar.isNotEmpty
                      ? null
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'G',
                          style: TextStyle(
                            color: AppColors.accentOf(context),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name — main',
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Guild chat · history for all members',
                        style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textTertiaryOf(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final otherUser = conversation['other_user'] ?? {};
    final lastMessage = conversation['last_message'] as Map<String, dynamic>?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;
    final otherUserId = conversation['other_user_id'] as String?;

    final otherUserName = (otherUser['display_name'] ?? otherUser['username'] ?? 'Unknown').toString();
    final rawProfilePicture = (otherUser['profile_picture_url'] as String?)?.trim();
    final profilePictureUrl = SupabaseMediaUrl.resolve(rawProfilePicture);

    final lastMessageContent = (lastMessage?['content'] as String? ?? '').trim();
    final lastMessageTime = lastMessage?['created_at'] as String?;

    return _surfaceCard(
      context,
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (otherUserId != null) context.push('/chat/$otherUserId');
          },
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.accentSoftOf(context),
                    backgroundImage: profilePictureUrl.isNotEmpty ? CachedNetworkImageProvider(profilePictureUrl) : null,
                    child: profilePictureUrl.isEmpty
                        ? Text(
                            otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: AppColors.accentOf(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceOf(context), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUserName,
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 16,
                              fontWeight: unreadCount > 0 ? FontWeight.w800 : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null)
                          Text(
                            _formatTime(lastMessageTime),
                            style: TextStyle(
                              color: AppColors.textTertiaryOf(context),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageContent.isNotEmpty ? lastMessageContent : 'No messages yet',
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? AppColors.textPrimaryOf(context)
                                  : AppColors.textSecondaryOf(context),
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: AppColors.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      padding: const EdgeInsets.all(14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasOf(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.canvasOf(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Messages',
          style: TextStyle(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : (_conversations.isEmpty && _officialGuilds.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _surfaceCard(
                      context,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 58,
                            color: AppColors.textTertiaryOf(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No conversations yet',
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start chatting with creators and collectors.',
                            style: TextStyle(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshAll,
                  color: AppColors.primary,
                  child: CustomScrollView(
                    slivers: [
                      if (_officialGuilds.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Guild channels',
                                  style: TextStyle(
                                    color: AppColors.textPrimaryOf(context),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Main chat for each official guild.',
                                  style: TextStyle(
                                    color: AppColors.textSecondaryOf(context),
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._officialGuilds.map(_buildGuildChannelCard),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Text(
                            'Direct messages',
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildConversationCard(_conversations[index]),
                            ),
                            childCount: _conversations.length,
                          ),
                        ),
                      ),
                      if (_conversations.isEmpty && _officialGuilds.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Text(
                              'No direct messages yet — open a profile to start a private chat.',
                              style: TextStyle(color: AppColors.textSecondaryOf(context)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
