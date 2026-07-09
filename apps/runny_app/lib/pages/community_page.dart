import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../models/social_models.dart';
import '../services/social_service.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';

/// Phân hệ 4: Động lực & Tương tác (Gamification & Social).
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.translate('community'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        glassCard(
          context: context,
          padding: const EdgeInsets.all(6),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: accentPulseGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [
              Tab(text: context.translate('badges_tab')),
              Tab(text: context.translate('leaderboard_tab')),
              Tab(text: context.translate('matching_tab')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _BadgesTab(),
              _LeaderboardTab(),
              _MatchingTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// 4.1 HUY HIỆU (Redesigned)
// =====================================================================

class _BadgesTab extends StatelessWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context) {
    final service = SocialService();
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<BadgeProgress>>(
      future: service.fetchBadges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorView(context, context.translate('load_badges_error', [snapshot.error.toString()]));
        }
        final badges = snapshot.data ?? [];
        final earnedCount = badges.where((b) => b.isEarned).length;
        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = width > 1100 ? 5 : (width > 700 ? 3 : 2);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              glassCard(
                context: context,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: accentPulseGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.translate('your_achievements'),
                              style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(
                              context.translate('badges_earned_count', [earnedCount.toString(), badges.length.toString()]),
                              style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: badges.map((b) => _BadgeCard(badge: b)).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeProgress badge;
  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final earned = badge.isEarned;
    final isDark = theme.brightness == Brightness.dark;

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: earned ? accentPulseGradient : null,
                  color: earned ? null : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  border: Border.all(
                    color: earned ? Colors.white.withValues(alpha: 0.2) : colorScheme.outline.withValues(alpha: 0.1),
                    width: 2,
                  ),
                  boxShadow: earned ? [
                    BoxShadow(
                      color: const Color(0xFFFA6B27).withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ] : null,
                ),
                child: Icon(
                  _iconFor(badge.icon),
                  color: earned ? Colors.white : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  size: 28,
                ),
              ),
              if (!earned)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Icon(Icons.lock, size: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Badge Name
          Text(
            _getTranslatedName(context),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: earned ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          // Badge Description
          Expanded(
            child: Text(
              _getTranslatedDesc(context),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 10,
                height: 1.2,
              ),
            ),
          ),
          if (earned && badge.earnedAt != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy').format(badge.earnedAt!),
                style: const TextStyle(
                  color: Color(0xFF4ADE80),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTranslatedName(BuildContext context) {
    final key = 'badge_name_${badge.code}';
    final translated = context.translate(key);
    return (translated == key) ? badge.name : translated;
  }

  String _getTranslatedDesc(BuildContext context) {
    final key = 'badge_desc_${badge.code}';
    final translated = context.translate(key);
    return (translated == key) ? badge.description : translated;
  }
}

// =====================================================================
// 4.2 BẢNG XẾP HẠNG
// =====================================================================

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    final service = SocialService();
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return FutureBuilder<List<LeaderboardEntry>>(
      future: service.fetchLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorView(context, context.translate('load_leaderboard_error', [snapshot.error.toString()]));
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return _emptyView(context, context.translate('no_leaderboard_data'));
        }
        return ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final e = entries[index];
            final isMe = e.userId == myId;
            return _LeaderboardRow(entry: e, isMe: isMe);
          },
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  const _LeaderboardRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return glassCard(
          context: context,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          _RankBadge(rank: entry.rank),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (entry.isPro) ...[
                      const SizedBox(width: 6),
                      const ProBadge(),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      badgeLabel(context, context.translate('you'), background: const Color(0xFFF85F2B)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(context.translate('sessions_count', [entry.activityCount.toString()]),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Text('${entry.totalDistanceKm.toStringAsFixed(1)} km',
              style: TextStyle(
                  color: colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final medal = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: medal != null
            ? LinearGradient(colors: [medal, medal.withValues(alpha: 0.6)])
            : null,
        color: medal == null ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)) : null,
        shape: BoxShape.circle,
      ),
      child: Text('$rank',
          style: TextStyle(
              color: medal != null ? Colors.black : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900)),
    );
  }
}

// =====================================================================
// 4.3 GHÉP ĐÔI BẠN CHẠY
// =====================================================================

class _MatchingTab extends StatefulWidget {
  const _MatchingTab();

  @override
  State<_MatchingTab> createState() => _MatchingTabState();
}

class _MatchingTabState extends State<_MatchingTab> {
  final _service = SocialService();
  late Future<_MatchData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MatchData> _load() async {
    final results = await Future.wait([
      _service.fetchIncomingRequests(),
      _service.fetchPartners(),
      _service.fetchSuggestions(),
    ]);
    return _MatchData(
      incoming: results[0] as List<RunMatch>,
      partners: results[1] as List<RunMatch>,
      suggestions: results[2] as List<MatchSuggestion>,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _sendRequest(MatchSuggestion s) async {
    final messenger = ScaffoldMessenger.of(context);
    final invitationSentToText = context.translate('invitation_sent_to', [s.displayName]);
    final errorText = context.translate('error');
    try {
      await _service.sendMatchRequest(s.userId);
      messenger.showSnackBar(SnackBar(content: Text(invitationSentToText)));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  Future<void> _respond(RunMatch m, bool accept) async {
    final messenger = ScaffoldMessenger.of(context);
    final connectedWithText = context.translate('connected_with', [m.otherDisplayName]);
    final invitationDeclinedText = context.translate('invitation_declined');
    final errorText = context.translate('error');
    try {
      await _service.respondToRequest(m.id, accept: accept);
      messenger.showSnackBar(SnackBar(
          content: Text(accept
              ? connectedWithText
              : invitationDeclinedText)));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$errorText: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<_MatchData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorView(context, context.translate('load_matching_error', [snapshot.error.toString()]));
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            children: [
              if (data.incoming.isNotEmpty) ...[
                _sectionTitle(context, context.translate('pending_invitations', [data.incoming.length.toString()])),
                ...data.incoming.map((m) => _IncomingCard(match: m, onRespond: _respond)),
                const SizedBox(height: 16),
              ],
              if (data.partners.isNotEmpty) ...[
                _sectionTitle(context, context.translate('your_partners', [data.partners.length.toString()])),
                ...data.partners.map((m) => _PartnerCard(match: m)),
                const SizedBox(height: 16),
              ],
              _sectionTitle(context, context.translate('partner_suggestions')),
              const SizedBox(height: 4),
              Text(
                context.translate('partner_suggestions_desc'),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (data.suggestions.isEmpty)
                _emptyView(context, context.translate('no_suggestions_found'))
              else
                ...data.suggestions.map((s) => _SuggestionCard(
                      suggestion: s,
                      onSend: () => _sendRequest(s),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _MatchData {
  final List<RunMatch> incoming;
  final List<RunMatch> partners;
  final List<MatchSuggestion> suggestions;
  _MatchData({required this.incoming, required this.partners, required this.suggestions});
}

class _IncomingCard extends StatelessWidget {
  final RunMatch match;
  final Future<void> Function(RunMatch, bool) onRespond;
  const _IncomingCard({required this.match, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
          context: context,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _avatar(match.otherDisplayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.otherDisplayName,
                      style: TextStyle(
                          color: colorScheme.onSurface, fontWeight: FontWeight.w800)),
                  if (match.otherCity != null)
                    Text(match.otherCity!,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFF4ADE80)),
              tooltip: context.translate('accept'),
              onPressed: () => onRespond(match, true),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              tooltip: context.translate('decline'),
              onPressed: () => onRespond(match, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final RunMatch match;
  const _PartnerCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
          context: context,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _avatar(match.otherDisplayName),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.otherDisplayName,
                      style: TextStyle(
                          color: colorScheme.onSurface, fontWeight: FontWeight.w800)),
                  if (match.otherCity != null)
                    Text(match.otherCity!,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            badgeLabel(context, context.translate('connected'), background: const Color(0xFF1F7A4D)),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final MatchSuggestion suggestion;
  final VoidCallback onSend;
  const _SuggestionCard({required this.suggestion, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pace = suggestion.effectivePace;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
          context: context,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(suggestion.displayName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(suggestion.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: colorScheme.onSurface, fontWeight: FontWeight.w800)),
                          ),
                          if (suggestion.sameCity) ...[
                            const SizedBox(width: 8),
                            badgeLabel(context, context.translate('same_area'), background: const Color(0xFF2A3B6B)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (suggestion.city != null)
                            _meta(context, Icons.place, suggestion.city!),
                          if (pace != null) _meta(context, Icons.speed, '${_formatPace(pace)} /km'),
                          _meta(context, Icons.straighten,
                              '${suggestion.totalDistanceKm.toStringAsFixed(0)} km'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (suggestion.bio != null && suggestion.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(suggestion.bio!,
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSend,
                style: primaryActionButton(context),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(context.translate('send_invitation')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- helpers dùng chung -----

Widget _sectionTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w800)),
    );

Widget _meta(BuildContext context, IconData icon, String text) {
  final colorScheme = Theme.of(context).colorScheme;
  return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
}

Widget _avatar(String name) {
  final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
  return Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: const BoxDecoration(gradient: secondaryPulseGradient, shape: BoxShape.circle),
    child: Text(initial,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
  );
}

Widget _errorView(BuildContext context, String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );

Widget _emptyView(BuildContext context, String message) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
      ),
    );

String _formatPace(double paceDecimal) {
  if (paceDecimal.isInfinite || paceDecimal.isNaN || paceDecimal <= 0) return '-:--';
  final minutes = paceDecimal.floor();
  final seconds = ((paceDecimal - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

IconData _iconFor(String name) {
  switch (name) {
    case 'flag':
      return Icons.flag;
    case 'directions_run':
      return Icons.directions_run;
    case 'military_tech':
      return Icons.military_tech;
    case 'looks_5':
      return Icons.looks_5;
    case 'looks_one':
      return Icons.looks_one;
    case 'workspace_premium':
      return Icons.workspace_premium;
    case 'route':
      return Icons.route;
    case 'public':
      return Icons.public;
    case 'emoji_events':
    default:
      return Icons.emoji_events;
  }
}
