import 'package:flutter/material.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../widgets/ui_components.dart';
import '../models/workout_models.dart';

class AICoachPage extends StatefulWidget {
  final Activity? initialActivity;
  const AICoachPage({super.key, this.initialActivity});

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
  Activity? _contextActivity;

  @override
  void initState() {
    super.initState();
    _contextActivity = widget.initialActivity;
    if (_contextActivity != null) {
      _controller.text = "Hãy phân tích hoạt động chạy ${_contextActivity!.distanceKm.toStringAsFixed(2)}km của tôi.";
    }
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
        String prompt = text;
        if (_contextActivity != null) {
          prompt = "Dựa trên dữ liệu hoạt động chạy bộ này: "
              "Khoảng cách: ${_contextActivity!.distanceKm.toStringAsFixed(2)}km, "
              "Thời gian: ${_contextActivity!.durationMin.toStringAsFixed(1)} phút, "
              "Nhịp tim TB: ${_contextActivity!.avgHr ?? 'N/A'} bpm, "
              "Độ cao tích lũy: ${_contextActivity!.elevationGainM ?? 0}m. "
              "Ghi chú: ${_contextActivity!.notes ?? 'Không có'}. "
              "Hãy trả lời câu hỏi sau: $text";
          setState(() => _contextActivity = null); // Reset context after sending
        }

        final response = await _geminiService.generateResponse(
          prompt,
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AI Coach'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _clearHistory,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Xóa lịch sử',
          ),
        ],
      ),
      body: Stack(
        children: [
          const SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
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
                            color: isUser
                                ? const Color(0xFF4A82FF)
                                : Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            msg['content']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                if (_contextActivity != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Hoạt động: ${_contextActivity!.distanceKm.toStringAsFixed(2)}km',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => setState(() => _contextActivity = null),
                            icon: const Icon(Icons.close, color: Colors.white70, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Hỏi HLV ảo hoặc yêu cầu lịch tập...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4A82FF),
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
