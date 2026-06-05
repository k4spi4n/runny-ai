import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';
import '../services/social_service.dart';
import '../widgets/ui_components.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cộng đồng',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        glassCard(
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
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Huy hiệu'),
              Tab(text: 'Xếp hạng'),
              Tab(text: 'Ghép đôi'),
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
// 4.1 HUY HIỆU
// =====================================================================

class _BadgesTab extends StatelessWidget {
  const _BadgesTab();

  @override
  Widget build(BuildContext context) {
    final service = SocialService();
    return FutureBuilder<List<BadgeProgress>>(
      future: service.fetchBadges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorView('Không tải được huy hiệu: ${snapshot.error}');
        }
        final badges = snapshot.data ?? [];
        final earnedCount = badges.where((b) => b.isEarned).length;
        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = width > 1100 ? 3 : (width > 700 ? 2 : 1);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              glassCard(
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
                          const Text('Thành tích của bạn',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text('$earnedCount / ${badges.length} huy hiệu',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.4,
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
    final earned = badge.isEarned;
    return Opacity(
      opacity: earned ? 1 : 0.45,
      child: glassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: earned ? accentPulseGradient : null,
                color: earned ? null : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                earned ? _iconFor(badge.icon) : Icons.lock_outline,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(badge.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(badge.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            if (earned) const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 20),
          ],
        ),
      ),
    );
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
          return _errorView('Không tải được bảng xếp hạng: ${snapshot.error}');
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return _emptyView('Chưa có dữ liệu xếp hạng.');
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
    return glassCard(
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
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      badgeLabel('Bạn', background: const Color(0xFFF85F2B)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${entry.activityCount} buổi chạy',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Text('${entry.totalDistanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
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
        color: medal == null ? Colors.white.withValues(alpha: 0.08) : null,
        shape: BoxShape.circle,
      ),
      child: Text('$rank',
          style: TextStyle(
              color: medal != null ? Colors.black : Colors.white,
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
    try {
      await _service.sendMatchRequest(s.userId);
      messenger.showSnackBar(SnackBar(content: Text('Đã gửi lời mời tới ${s.displayName}')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _respond(RunMatch m, bool accept) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.respondToRequest(m.id, accept: accept);
      messenger.showSnackBar(SnackBar(
          content: Text(accept
              ? 'Đã kết nối với ${m.otherDisplayName}'
              : 'Đã từ chối lời mời')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MatchData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorView('Không tải được dữ liệu ghép đôi: ${snapshot.error}');
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            children: [
              if (data.incoming.isNotEmpty) ...[
                _sectionTitle('Lời mời đang chờ (${data.incoming.length})'),
                ...data.incoming.map((m) => _IncomingCard(match: m, onRespond: _respond)),
                const SizedBox(height: 16),
              ],
              if (data.partners.isNotEmpty) ...[
                _sectionTitle('Bạn chạy của bạn (${data.partners.length})'),
                ...data.partners.map((m) => _PartnerCard(match: m)),
                const SizedBox(height: 16),
              ],
              _sectionTitle('Gợi ý bạn chạy'),
              const SizedBox(height: 4),
              const Text(
                'Dựa trên pace và vị trí. Bật "Tìm bạn chạy" trong Hồ sơ để xuất hiện với người khác.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (data.suggestions.isEmpty)
                _emptyView('Chưa có gợi ý phù hợp.')
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
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
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  if (match.otherCity != null)
                    Text(match.otherCity!,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Color(0xFF4ADE80)),
              tooltip: 'Chấp nhận',
              onPressed: () => onRespond(match, true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white38),
              tooltip: 'Từ chối',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
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
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                  if (match.otherCity != null)
                    Text(match.otherCity!,
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            badgeLabel('Đã kết nối', background: const Color(0xFF1F7A4D)),
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
    final pace = suggestion.effectivePace;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: glassCard(
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
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800)),
                          ),
                          if (suggestion.sameCity) ...[
                            const SizedBox(width: 8),
                            badgeLabel('Cùng khu vực', background: const Color(0xFF2A3B6B)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (suggestion.city != null)
                            _meta(Icons.place, suggestion.city!),
                          if (pace != null) _meta(Icons.speed, '${_formatPace(pace)} /km'),
                          _meta(Icons.straighten,
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
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSend,
                style: primaryActionButton(),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Gửi lời mời chạy cùng'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- helpers dùng chung -----

Widget _sectionTitle(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    );

Widget _meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );

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

Widget _errorView(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70)),
      ),
    );

Widget _emptyView(String message) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(message, style: const TextStyle(color: Colors.white60)),
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
