import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';

/// Service cho Phân hệ 4: Động lực & Tương tác (Gamification & Social).
class SocialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _uid {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Chưa đăng nhập');
    return user.id;
  }

  // ----- 4.1 Huy hiệu -----

  /// Trả về toàn bộ danh mục huy hiệu kèm trạng thái đã đạt được của user.
  Future<List<BadgeProgress>> fetchBadges() async {
    final definitions = await _supabase
        .from('badge_definitions')
        .select()
        .order('sort_order', ascending: true);

    final earned = await _supabase
        .from('badges')
        .select('code, created_at')
        .eq('user_id', _uid);

    final earnedMap = <String, DateTime>{};
    for (final b in earned as List) {
      if (b['code'] != null) {
        earnedMap[b['code'] as String] = DateTime.parse(b['created_at'] as String);
      }
    }

    return (definitions as List).map((d) {
      final code = d['code'] as String;
      return BadgeProgress.fromJson(d, earnedAt: earnedMap[code]);
    }).toList();
  }

  // ----- 4.2 Bảng xếp hạng -----

  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 50}) async {
    final response = await _supabase.rpc('get_leaderboard', params: {'p_limit': limit});
    return (response as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
  }

  // ----- 4.3 Ghép đôi bạn chạy -----

  /// Cập nhật thông tin matching trên hồ sơ.
  Future<void> updateMatchingPreferences({
    required bool lookingForPartner,
    double? preferredPace,
    String? city,
    String? bio,
  }) async {
    await _supabase.from('profiles').update({
      'looking_for_partner': lookingForPartner,
      'preferred_pace_min_per_km': preferredPace,
      'city': city,
      'bio': bio,
    }).eq('id', _uid);
  }

  Future<List<MatchSuggestion>> fetchSuggestions({int limit = 20}) async {
    final response = await _supabase.rpc('get_match_suggestions', params: {'p_limit': limit});
    return (response as List).map((e) => MatchSuggestion.fromJson(e)).toList();
  }

  /// Gửi lời mời ghép đôi tới một runner khác.
  Future<void> sendMatchRequest(String addresseeId) async {
    await _supabase.from('run_matches').insert({
      'requester_id': _uid,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  /// Lời mời mình đã nhận đang chờ phản hồi.
  Future<List<RunMatch>> fetchIncomingRequests() async {
    final response = await _supabase
        .from('run_matches')
        .select('*, requester:profiles!run_matches_requester_id_fkey(display_name, city)')
        .eq('addressee_id', _uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (response as List).map((e) => RunMatch.fromJson(e, isIncoming: true)).toList();
  }

  /// Các kết nối đã được chấp nhận (bạn chạy của mình).
  Future<List<RunMatch>> fetchPartners() async {
    final response = await _supabase
        .from('run_matches')
        .select(
            '*, requester:profiles!run_matches_requester_id_fkey(display_name, city), addressee:profiles!run_matches_addressee_id_fkey(display_name, city)')
        .or('requester_id.eq.$_uid,addressee_id.eq.$_uid')
        .eq('status', 'accepted')
        .order('updated_at', ascending: false);
    final uid = _uid;
    return (response as List)
        .map((e) => RunMatch.fromJson(e, isIncoming: e['addressee_id'] == uid))
        .toList();
  }

  Future<void> respondToRequest(String matchId, {required bool accept}) async {
    await _supabase.rpc('respond_to_match', params: {
      'p_match_id': matchId,
      'p_accept': accept,
    });
  }

  Future<void> cancelMatchRequest(String matchId) =>
      _supabase.rpc('cancel_match', params: {'p_match_id': matchId});
}
