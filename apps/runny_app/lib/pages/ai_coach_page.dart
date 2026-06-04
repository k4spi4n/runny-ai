import 'package:flutter/material.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';

class AICoachPage extends StatefulWidget {
  const AICoachPage({super.key});

  @override
  State<AICoachPage> createState() => _AICoachPageState();
}

class _AICoachPageState extends State<AICoachPage> {
  final TextEditingController _controller = TextEditingController();
  final TrainingService _trainingService = TrainingService();
  final GeminiService _geminiService = GeminiService();
  final ChatService _chatService = ChatService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _chatService.getChatHistory();
      setState(() {
        _messages.addAll(history);
      });
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (!_geminiService.isConfigured) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'AI đang tạm tắt vì thiếu GEMINI_API_KEY trong .env.',
        });
      });
      return;
    }

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _controller.clear();

    // Save user message
    await _chatService.saveMessage('user', text);

    try {
      // Check if user is asking for a plan
      if (text.toLowerCase().contains('lịch tập') ||
          text.toLowerCase().contains('kế hoạch')) {
        await _trainingService.createGoalBasedPlan(text);
        const assistantMsg =
            'Tôi đã tạo xong lịch tập dựa trên mục tiêu của bạn! Bạn có thể xem chi tiết trong phần Lịch tập.';
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': assistantMsg,
          });
        });
        await _chatService.saveMessage('assistant', assistantMsg);
      } else {
        final response = await _geminiService.generateResponse(
          text,
          history: _messages.sublist(0, _messages.length - 1),
        );
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
        });
        await _chatService.saveMessage('assistant', response);
      }
    } catch (e) {
      final errorMsg = 'Xin lỗi, đã có lỗi xảy ra: $e';
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': errorMsg,
        });
      });
      await _chatService.saveMessage('assistant', errorMsg);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa lịch sử?'),
        content: const Text('Hành động này sẽ xóa tất cả tin nhắn trong phiên chat này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatService.clearHistory();
      setState(() {
        _messages.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lịch sử trò chuyện', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _clearHistory,
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Xóa lịch sử'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg['content']!,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading && _messages.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Hỏi HLV ảo hoặc yêu cầu lịch tập...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
  }
}
