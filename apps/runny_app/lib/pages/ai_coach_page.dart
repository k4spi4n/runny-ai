import 'package:flutter/material.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
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
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
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
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: context.translate('ai_coach_hint'),
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
}
