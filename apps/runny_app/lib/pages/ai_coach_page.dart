import 'package:flutter/material.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../services/speech_service.dart';
import '../widgets/ui_components.dart';
import '../models/workout_models.dart';
import '../l10n/app_localizations.dart';

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
  final SpeechService _speech = SpeechService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isRecording = false;
  String _baseText = '';
  Activity? _contextActivity;

  @override
  void initState() {
    super.initState();
    _contextActivity = widget.initialActivity;
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contextActivity != null && _messages.isEmpty && _controller.text.isEmpty) {
      _controller.text = context.translate(
        'ai_coach_analyze_activity',
        [_contextActivity!.distanceKm.toStringAsFixed(2)],
      );
    }
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
          'content': context.translate('ai_disabled_no_key'),
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
      // Check if user is asking for a plan (localized keywords)
      final lowercaseText = text.toLowerCase();
      bool isRequestingPlan = lowercaseText.contains('lịch tập') ||
          lowercaseText.contains('kế hoạch') ||
          lowercaseText.contains('training plan') ||
          lowercaseText.contains('schedule');

      if (isRequestingPlan) {
        await _trainingService.createGoalBasedPlan(text);
        final assistantMsg = context.translate('plan_created_assistant');
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
          prompt = context.translate('ai_prompt_context', [
            _contextActivity!.distanceKm.toStringAsFixed(2),
            _contextActivity!.durationMin.toStringAsFixed(1),
            _contextActivity!.avgHr?.toString() ?? 'N/A',
            _contextActivity!.elevationGainM?.toString() ?? '0',
            _contextActivity!.notes ?? (context.translate('english') == 'English' ? 'None' : 'Không có'),
            text,
          ]);
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
      final errorMsg = '${context.translate('error_occurred')}: $e';
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
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(context.translate('delete_history'), style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(context.translate('delete_history_confirm'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.translate('cancel'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.translate('delete'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
  void dispose() {
    _speech.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ----- Speech-to-Text (Issue #29) -----

  void _toggleRecording() {
    if (_isRecording) {
      _speech.stop();
      return;
    }
    if (!_speech.isSupported) {
      _showToast('Trình duyệt không hỗ trợ nhập liệu bằng giọng nói.');
      return;
    }
    _baseText = _controller.text;
    setState(() => _isRecording = true);
    _speech.start(
      localeId: 'vi-VN',
      onResult: (text, isFinal) {
        if (!mounted) return;
        final sep = (_baseText.isEmpty || _baseText.endsWith(' ')) ? '' : ' ';
        final combined = '$_baseText$sep$text';
        setState(() {
          _controller.text = combined;
          _controller.selection =
              TextSelection.collapsed(offset: combined.length);
        });
        if (isFinal) _baseText = combined;
      },
      onError: (code) {
        if (!mounted) return;
        setState(() => _isRecording = false);
        _showToast(_mapSpeechError(code));
      },
      onEnd: () {
        if (mounted) setState(() => _isRecording = false);
      },
    );
  }

  void _cancelRecording() {
    _speech.cancel();
    setState(() {
      _isRecording = false;
      _controller.text = _baseText;
      _controller.selection =
          TextSelection.collapsed(offset: _baseText.length);
    });
  }

  String _mapSpeechError(String code) {
    switch (code) {
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Bạn đã từ chối quyền truy cập Micro. Hãy cấp quyền trong trình duyệt để dùng nhập giọng nói.';
      case 'no-speech':
        return 'Không nhận diện được giọng nói. Hãy thử lại ở nơi yên tĩnh hơn.';
      case 'audio-capture':
        return 'Không tìm thấy Micro. Vui lòng kiểm tra thiết bị của bạn.';
      case 'network':
        return 'Lỗi mạng khi nhận diện giọng nói. Vui lòng thử lại.';
      case 'unsupported':
        return 'Trình duyệt không hỗ trợ nhập liệu bằng giọng nói.';
      default:
        return 'Đã xảy ra lỗi khi ghi âm ($code). Vui lòng thử lại.';
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(context.translate('ai_coach'), style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _clearHistory,
            icon: Icon(Icons.delete_outline, color: colorScheme.onSurface),
            tooltip: context.translate('delete_history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
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
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser
                                ? colorScheme.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isUser ? 20 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 20),
                            ),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
                          ),
                          child: Text(
                            msg['content']!,
                            style: TextStyle(
                              color: isUser ? Colors.white : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(color: colorScheme.primary),
                  ),
                if (_contextActivity != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.description_outlined, color: colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${context.translate('activity')}: ${_contextActivity!.distanceKm.toStringAsFixed(2)}km',
                            style: TextStyle(color: colorScheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => setState(() => _contextActivity = null),
                            icon: Icon(Icons.close, color: colorScheme.primary, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isRecording) _buildListeningIndicator(context),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            onPressed: _cancelRecording,
                            tooltip: 'Huỷ ghi âm',
                            icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: _isRecording
                                ? 'Đang nghe...'
                                : 'Hỏi HLV ảo hoặc yêu cầu lịch tập...',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
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
                      _MicButton(
                        isRecording: _isRecording,
                        color: colorScheme.primary,
                        onTap: _toggleRecording,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
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

  Widget _buildListeningIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _PulsingDot(),
            SizedBox(width: 10),
            Text(
              'Đang nghe... Hãy nói câu hỏi của bạn',
              style: TextStyle(
                  color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(width: 10),
            _AudioWave(),
          ],
        ),
      ),
    );
  }
}

/// Nút Micro với hiệu ứng nhấp nháy đỏ + quầng sáng khi đang ghi âm.
class _MicButton extends StatefulWidget {
  final bool isRecording;
  final Color color;
  final VoidCallback onTap;

  const _MicButton({
    required this.isRecording,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = widget.isRecording;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = recording ? (0.4 + _controller.value * 0.6) : 0.0;
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? Colors.redAccent : widget.color,
            boxShadow: recording
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: pulse),
                      blurRadius: 16,
                      spreadRadius: 2 + _controller.value * 3,
                    ),
                  ]
                : null,
          ),
          child: IconButton(
            onPressed: widget.onTap,
            tooltip: recording ? 'Dừng ghi âm' : 'Nhập bằng giọng nói',
            icon: Icon(recording ? Icons.stop : Icons.mic, color: Colors.white),
          ),
        );
      },
    );
  }
}

/// Chấm tròn nhấp nháy báo hiệu đang lắng nghe.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}

/// Hiệu ứng sóng âm (audio visualizer) đơn giản.
class _AudioWave extends StatefulWidget {
  const _AudioWave();

  @override
  State<_AudioWave> createState() => _AudioWaveState();
}

class _AudioWaveState extends State<_AudioWave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 18,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(4, (i) {
              final phase = (_controller.value + i * 0.25) % 1.0;
              final height = 6 + (1 - (2 * phase - 1).abs()) * 12;
              return Container(
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
