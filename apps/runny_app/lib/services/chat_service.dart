import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, String>>> getChatHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('ai_chat_history')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    return (response as List).map((m) {
      return {
        'role': m['role'] as String,
        'content': m['content'] as String,
      };
    }).toList();
  }

  Future<void> saveMessage(String role, String content) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('ai_chat_history').insert({
      'user_id': user.id,
      'role': role,
      'content': content,
    });
  }

  Future<void> clearHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('ai_chat_history').delete().eq('user_id', user.id);
  }
}
