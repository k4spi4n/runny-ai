import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 50}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final pageSize = limit.clamp(1, 100);
    final response = await _supabase
        .from('ai_chat_history')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(pageSize);

    return (response as List).reversed.map((m) {
      return {
        'id': m['id'] as String,
        'role': m['role'] as String,
        'content': m['content'] as String,
        if (m['metadata'] is Map)
          'metadata': Map<String, dynamic>.from(m['metadata'] as Map),
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> saveMessage(
    String role,
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final row = await _supabase
        .from('ai_chat_history')
        .insert({
          'user_id': user.id,
          'role': role,
          'content': content,
          'metadata': ?metadata,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> updateMessageMetadata(
    String messageId,
    Map<String, dynamic> metadata,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('ai_chat_history')
        .update({'metadata': metadata})
        .eq('id', messageId)
        .eq('user_id', user.id);
  }

  Future<void> clearHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('ai_chat_history').delete().eq('user_id', user.id);
  }
}
