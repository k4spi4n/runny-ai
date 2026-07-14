import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../services/ai_coach_tool_service.dart';
import '../services/speech_service.dart';
import '../services/nutrition_service.dart';
import '../services/weather_service.dart';
import '../services/readiness_service.dart';
import '../services/run_reminder_service.dart';
import '../widgets/ui_components.dart';
import '../widgets/device_permission_dialog.dart';
import '../widgets/paywall.dart';
import '../services/paywall_exception.dart';
import '../models/workout_models.dart';
import '../models/nutrition_models.dart';
import '../models/weight_models.dart';
import '../models/coach_persona.dart';
import '../models/ai_coach_tool_models.dart';
import '../l10n/app_localizations.dart';

/// Các loại dữ liệu người dùng có thể đính kèm cho HLV AI phân tích kèm câu hỏi.
enum _ChatAttachment { activities, metrics, plan, nutrition }

class AICoachPage extends StatefulWidget {
  final Activity? initialActivity;
  final String? initialPrompt;

  /// [embedded] = true khi hiển thị bên trong khung tab của Dashboard: bỏ nền
  /// gradient riêng (Dashboard đã vẽ gradient toàn màn) để không tạo ra "box"
  /// hình chữ nhật lệch màu, đồng bộ với các tab còn lại.
  final bool embedded;

  const AICoachPage({
    super.key,
    this.initialActivity,
    this.initialPrompt,
    this.embedded = false,
  });

  @override
  State<AICoachPage> createState() => _AICoachPageState();
}

class _AICoachPageState extends State<AICoachPage> {
  final TextEditingController _controller = TextEditingController();
  final TrainingService _trainingService = TrainingService();
  final GeminiService _geminiService = GeminiService();
  final ChatService _chatService = ChatService();
  final SpeechService _speech = SpeechService();
  final WeatherService _weatherService = WeatherService();
  final AICoachToolService _coachToolService = AICoachToolService();
  final RunReminderService _runReminderService = RunReminderService();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _coachNameController = TextEditingController();
  String? _greetingText;
  bool _isLoading = false;
  bool _showLongWaitNotice = false;
  Timer? _longWaitTimer;
  bool _isRecording = false;
  final Set<int> _processingActionIndexes = <int>{};
  bool _hasConfirmedMicrophoneAccess = false;
  String _coachPersona = CoachPersona.calm.id;
  String _baseText = '';
  Activity? _contextActivity;
  // Dữ liệu người dùng chọn đính kèm vào câu hỏi để AI phân tích.
  // Mặc định bật tất cả để AI luôn có ngữ cảnh đầy đủ.
  final Set<_ChatAttachment> _attachments = {
    _ChatAttachment.activities,
    _ChatAttachment.metrics,
    _ChatAttachment.plan,
    _ChatAttachment.nutrition,
  };

  final List<String> _suggestedQuestionKeys = List.generate(
    16,
    (index) => 'chat_suggestion_${index + 1}',
  );
  List<String> _selectedSuggestions = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handlePromptChanged);
    _contextActivity = widget.initialActivity;
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _controller.text = widget.initialPrompt!;
    }
    _loadGreeting();
    _loadCoachSettings();
    _loadHistory();
    _randomizeSuggestions();
  }

  Future<void> _loadCoachSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('coach_name, coach_persona')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _coachNameController.text =
            profile?['coach_name'] as String? ?? 'Runny';
        _coachPersona = CoachPersona.byId(
          profile?['coach_persona'] as String?,
        ).id;
      });
    } catch (e) {
      debugPrint('Error loading AI coach settings: $e');
    }
  }

  Future<void> _saveCoachSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final coachName = _coachNameController.text.trim();
    if (coachName.isEmpty || coachName.length > 24) {
      _showToast(context.translate('coach_name_invalid'));
      return;
    }

    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'coach_name': coachName,
            'coach_persona': CoachPersona.byId(_coachPersona).id,
          })
          .eq('id', user.id);
      GeminiService.clearCoachPreferenceCache();
      if (mounted) {
        setState(() {});
        Navigator.of(context).pop();
        _showToast(context.translate('coach_settings_saved'));
      }
    } catch (e) {
      if (mounted) _showToast('${context.translate('error')}: $e');
    }
  }

  void _showCoachSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) => _CoachSettingsSheet(
            coachNameController: _coachNameController,
            persona: _coachPersona,
            isSaving: isSaving,
            onPersonaChanged: (persona) {
              setState(() => _coachPersona = persona);
              setSheetState(() {});
            },
            onSave: () async {
              if (isSaving) return;
              setSheetState(() => isSaving = true);
              await _saveCoachSettings();
              if (context.mounted) {
                setSheetState(() => isSaving = false);
              }
            },
          ),
        );
      },
    );
  }

  void _randomizeSuggestions() {
    final random = Random();
    final keysCopy = List<String>.from(_suggestedQuestionKeys);
    keysCopy.shuffle(random);
    _selectedSuggestions = keysCopy.take(4).toList();
  }

  void _handlePromptChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contextActivity != null &&
        _messages.isEmpty &&
        _controller.text.isEmpty) {
      _controller.text = context.translate('ai_coach_analyze_activity', [
        _contextActivity!.distanceKm.toStringAsFixed(2),
      ]);
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

  Future<void> _loadGreeting() async {
    final name = await _loadUserDisplayName();
    final displayName = (name == null || name.isEmpty) ? 'bạn' : name;
    final variants = [
      'Xin chào $displayName, tôi có thể hỗ trợ bạn hôm nay?',
      'Xin chào $displayName, tôi có thể đưa lời khuyên nào cho bạn hôm nay?',
      'Xin chào $displayName, tôi có thể giúp bạn cải thiện chỉ số nào hôm nay?',
    ];
    if (!mounted) return;
    setState(() {
      _greetingText = variants[Random().nextInt(variants.length)];
    });
  }

  Future<String?> _loadUserDisplayName() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final profile = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final displayName = (profile?['display_name'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
    } catch (e) {
      debugPrint('Error loading AI greeting profile name: $e');
    }

    final metadataName =
        (user.userMetadata?['display_name'] as String?) ??
        (user.userMetadata?['name'] as String?);
    final trimmedMetadataName = metadataName?.trim();
    if (trimmedMetadataName != null && trimmedMetadataName.isNotEmpty) {
      return trimmedMetadataName;
    }

    final emailPrefix = user.email?.split('@').first.trim();
    return emailPrefix?.isEmpty == false ? emailPrefix : null;
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Chặn gửi chồng khi đang chờ phản hồi trước đó.
    if (_isLoading) return;

    if (!_geminiService.isConfigured) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': context.translate('ai_disabled_no_key'),
        });
      });
      return;
    }

    // Chụp nhanh lựa chọn dữ liệu đính kèm trước khi reset UI (đọc Provider
    // đồng bộ, không dùng context sau async gap).
    final attachments = Set<_ChatAttachment>.from(_attachments);
    final nutritionSummary = attachments.contains(_ChatAttachment.nutrition)
        ? context.read<NutritionService>().getDailySummary(DateTime.now())
        : null;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _showLongWaitNotice = false;
    });
    _startLongWaitTimer();
    _controller.clear();
    _scrollToBottom();

    // Cache context-dependent translations before any async gaps
    final errorOccurredTranslation = context.translate('error_occurred');
    final planCreatedTranslation = context.translate('plan_created_assistant');

    String prompt = text;
    final contextActivity = _contextActivity;
    if (contextActivity != null) {
      final hasEnglishL10n = context.translate('english') == 'English';
      final activityContextParts = <String>[
        if (contextActivity.name != null && contextActivity.name!.isNotEmpty)
          '${hasEnglishL10n ? 'Name' : 'Tên'}: ${contextActivity.name}',
        if (contextActivity.notes != null &&
            contextActivity.notes!.isNotEmpty &&
            contextActivity.notes != contextActivity.name)
          '${hasEnglishL10n ? 'Notes' : 'Ghi chú'}: ${contextActivity.notes}',
      ];
      final activityContextText = activityContextParts.isEmpty
          ? (hasEnglishL10n ? 'None' : 'Không có')
          : activityContextParts.join('; ');
      prompt = context.translate('ai_prompt_context', [
        contextActivity.distanceKm.toStringAsFixed(2),
        contextActivity.durationMin.toStringAsFixed(1),
        contextActivity.avgHr?.toString() ?? 'N/A',
        contextActivity.elevationGainM?.toString() ?? '0',
        activityContextText,
        text,
      ]);
      setState(
        () => _contextActivity = null,
      ); // Reset context immediately (safe since it's synchronous)
    }

    // Đính kèm dữ liệu người dùng đã chọn (Hoạt động, Chỉ số, Kế hoạch, Dinh dưỡng).
    final attachmentBlock = await _buildAttachmentContext(
      attachments: attachments,
      nutritionSummary: nutritionSummary,
    );
    if (attachmentBlock.isNotEmpty) {
      prompt = '$attachmentBlock\n\n$prompt';
    }

    // Readiness is a shared AI tool: only fetch it when the question concerns
    // fatigue, pain, recovery, rest, load, or changing the training schedule.
    final lowerForReadiness = text.toLowerCase();
    final readinessIntent = RegExp(
      r'readiness|hồi phục|mệt|đau|nghỉ|rpe|tải tập|giảm|dời|đổi lịch|recovery|fatigue|sore|rest|load|reschedule',
    ).hasMatch(lowerForReadiness);
    if (readinessIntent) {
      try {
        final readiness = await ReadinessService().getSnapshot();
        prompt =
            '''CÔNG CỤ READINESS (dữ liệu hiện tại): điểm ${readiness.score}/100, trạng thái ${readiness.status}, tải 7 ngày ${readiness.acuteLoad.toStringAsFixed(0)}, tải nền 28 ngày ${readiness.chronicLoad.toStringAsFixed(0)}, ACWR ${readiness.acwr?.toStringAsFixed(2) ?? 'chưa đủ dữ liệu'}, cờ đau bất thường ${readiness.painFlag ? 'CÓ' : 'không'}. ${readiness.painFlag ? 'Không đề xuất điều chỉnh lịch; khuyên nghỉ và tìm tư vấn y tế phù hợp.' : 'Nếu khuyến nghị giảm/dời lịch, nói rõ người dùng cần xác nhận trong tab Lịch tập.'}

$prompt''';
      } catch (e) {
        debugPrint('Readiness tool error: $e');
      }
    }

    // Save user message
    await _chatService.saveMessage('user', text);

    try {
      // Chỉ mở luồng tạo kế hoạch mới khi người dùng thực sự yêu cầu tạo. Các
      // câu hỏi xem/sửa lịch hiện có phải đi qua tool để có thẻ xác nhận.
      final lowercaseText = text.toLowerCase();
      final mentionsPlan =
          lowercaseText.contains('lịch tập') ||
          lowercaseText.contains('kế hoạch') ||
          lowercaseText.contains('training plan') ||
          lowercaseText.contains('schedule');
      final asksToCreate =
          lowercaseText.contains('tạo') ||
          lowercaseText.contains('lập') ||
          lowercaseText.contains('xây dựng') ||
          lowercaseText.contains('create') ||
          lowercaseText.contains('make me') ||
          lowercaseText.contains('build');
      final asksToEdit = RegExp(
        r'sửa|đổi|dời|chỉnh|giảm|tăng|update|edit|change|move|reschedule',
      ).hasMatch(lowercaseText);
      final isRequestingPlan = mentionsPlan && asksToCreate && !asksToEdit;

      if (isRequestingPlan) {
        // Tạo kế hoạch là tính năng cao cấp: chặn sớm với tier free (UX).
        if (!mounted) return;
        if (!await ensurePaywall(context, 'plan')) {
          return; // sheet nâng cấp đã hiện; finally sẽ tắt loading
        }
        await _trainingService.createGoalBasedPlan(text);
        if (!mounted) return;
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': planCreatedTranslation,
          });
        });
        await _chatService.saveMessage('assistant', planCreatedTranslation);
      } else {
        // Tool-aware completion: model có thể tự lấy workout/meal hiện có và
        // tạo đề xuất, nhưng không có tool nào được phép ghi dữ liệu trực tiếp.
        final allHistory = _messages.sublist(0, _messages.length - 1);
        final history = allHistory.length <= 30
            ? allHistory
            : allHistory.sublist(allHistory.length - 30);
        final result = await _geminiService.generateCoachTurn(
          prompt,
          history: history,
          tools: AICoachToolService.definitions,
          executeTool: _coachToolService.execute,
        );
        final savedReply = await _chatService.saveMessage(
          'assistant',
          result.content,
        );
        if (!mounted) return;
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': result.content,
            if (savedReply?['id'] != null) 'id': savedReply!['id'],
          });
        });

        for (final action in result.actions) {
          final metadata = {'interactive_action': action.toJson()};
          final cardText = context.translate(
            action.kind == 'workout_update'
                ? 'coach_workout_proposal'
                : 'coach_meal_proposal',
            [action.title],
          );
          final savedCard = await _chatService.saveMessage(
            'assistant',
            cardText,
            metadata: metadata,
          );
          if (!mounted) return;
          setState(() {
            _messages.add({
              'role': 'assistant',
              'content': cardText,
              'metadata': metadata,
              if (savedCard?['id'] != null) 'id': savedCard!['id'],
            });
          });
        }
        _cancelLongWaitTimer();
        _scrollToBottom();
      }
    } on PaywallException catch (e) {
      // Hết quyền (vd hết trial) ngay khi gọi: mở luồng nâng cấp thay vì báo lỗi.
      if (!mounted) return;
      await showUpgradeSheet(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = '$errorOccurredTranslation: $e';
      setState(() {
        _messages.add({'role': 'assistant', 'content': errorMsg});
      });
      await _chatService.saveMessage('assistant', errorMsg);
    } finally {
      _cancelLongWaitTimer();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showLongWaitNotice = false;
        });
      }
    }
  }

  void _startLongWaitTimer() {
    _longWaitTimer?.cancel();
    _longWaitTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _showLongWaitNotice = true);
      }
    });
  }

  void _cancelLongWaitTimer() {
    _longWaitTimer?.cancel();
    _longWaitTimer = null;
  }

  void _sendSuggestedQuestion(String question) {
    if (_isLoading) return;
    _controller.text = question;
    _controller.selection = TextSelection.collapsed(offset: question.length);
    _sendMessage();
  }

  /// Tổng hợp dữ liệu người dùng đã chọn thành một khối văn bản để gửi kèm câu
  /// hỏi cho AI phân tích. Mỗi nguồn lỗi đều fail-soft (bỏ qua, không chặn chat).
  Future<String> _buildAttachmentContext({
    required Set<_ChatAttachment> attachments,
    required DailyNutritionSummary? nutritionSummary,
  }) async {
    if (attachments.isEmpty) return '';
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final buffer = StringBuffer();

    // --- Hoạt động gần đây ---
    if (attachments.contains(_ChatAttachment.activities)) {
      try {
        final rows = await supabase
            .from('activities')
            .select()
            .order('started_at', ascending: false)
            .limit(7);
        final activities = (rows as List)
            .map((j) => Activity.fromJson(j))
            .toList();
        if (activities.isNotEmpty) {
          buffer.writeln('• Hoạt động gần đây:');
          for (final a in activities) {
            buffer.writeln('  - ${_fmtActivityLine(a)}');
          }
        }
      } catch (e) {
        debugPrint('Attach activities error: $e');
      }
    }

    // --- Chỉ số tổng hợp ---
    if (attachments.contains(_ChatAttachment.metrics)) {
      // Thể trạng người dùng (chiều cao, cân nặng, nhịp tim tối đa).
      if (user != null) {
        try {
          final profile = await supabase
              .from('profiles')
              .select(
                'height_cm, weight_kg, max_hr, gender, '
                'target_weight_kg, start_weight_kg',
              )
              .eq('id', user.id)
              .maybeSingle();
          if (profile != null) {
            final parts = <String>[];
            final h = profile['height_cm'];
            final w = profile['weight_kg'];
            final mhr = profile['max_hr'];
            final gender = _genderLabel(profile['gender']);
            if (gender != null) parts.add(gender);
            if (h != null) parts.add('cao ${(h as num).toStringAsFixed(0)} cm');
            if (w != null) {
              parts.add('nặng ${(w as num).toStringAsFixed(0)} kg');
            }
            if (mhr != null) {
              parts.add('nhịp tim tối đa ${(mhr as num).toInt()} bpm');
            }
            if (parts.isNotEmpty) {
              buffer.writeln('• Thể trạng: ${parts.join(', ')}.');
            }

            // Mục tiêu + xu hướng cân nặng: chỉ đính kèm khi người dùng ĐANG có
            // mục tiêu cân nặng (đủ mốc bắt đầu + mục tiêu + hiện tại), giúp AI
            // tư vấn theo tiến trình thực tế.
            final goal = WeightGoal.fromProfile(profile);
            if (goal.hasGoal) {
              final dir = goal.isLosing ? 'giảm' : 'tăng';
              buffer.writeln(
                '• Mục tiêu cân nặng: ${goal.start!.toStringAsFixed(1)}kg → '
                '${goal.target!.toStringAsFixed(1)}kg '
                '(hiện tại ${goal.current!.toStringAsFixed(1)}kg, đã $dir '
                '${goal.achievedDelta.toStringAsFixed(1)}kg, còn '
                '${goal.remaining.toStringAsFixed(1)}kg, '
                '${(goal.progress * 100).toStringAsFixed(0)}%).',
              );
              final trend = await _fetchWeightTrend(user.id);
              if (trend != null) buffer.writeln('  Cột mốc gần đây: $trend.');
            }
          }
        } catch (e) {
          debugPrint('Attach body stats error: $e');
        }
      }
      try {
        final rows = await supabase
            .from('activities')
            .select('distance_km, duration_min, avg_hr, avg_cadence');
        final list = rows as List;
        double dist = 0, dur = 0;
        int hrSum = 0, hrCount = 0;
        int cadSum = 0, cadCount = 0;
        for (final a in list) {
          dist += (a['distance_km'] as num).toDouble();
          dur += (a['duration_min'] as num).toDouble();
          if (a['avg_hr'] != null) {
            hrSum += (a['avg_hr'] as num).toInt();
            hrCount++;
          }
          if (a['avg_cadence'] != null) {
            cadSum += (a['avg_cadence'] as num).toInt();
            cadCount++;
          }
        }
        final pace = dist > 0 ? dur / dist : 0.0;
        buffer.writeln(
          '• Chỉ số tổng: ${list.length} buổi, ${dist.toStringAsFixed(1)} km, '
          'pace TB ${_fmtPace(pace)}/km'
          '${hrCount > 0 ? ', HR TB ${(hrSum / hrCount).round()} bpm' : ''}'
          '${cadCount > 0 ? ', Cadence TB ${(cadSum / cadCount).round()} spm' : ''}.',
        );
      } catch (e) {
        debugPrint('Attach metrics error: $e');
      }

      // Thời tiết hiện tại tại vị trí người dùng (giúp AI tư vấn theo điều kiện
      // chạy thực tế). Fail-soft: bỏ qua nếu không lấy được vị trí/thời tiết.
      final weatherLine = await _fetchWeatherLine();
      if (weatherLine != null) buffer.writeln(weatherLine);
    }

    // --- Kế hoạch tập đang hoạt động ---
    if (attachments.contains(_ChatAttachment.plan) && user != null) {
      try {
        final schedule = await supabase
            .from('training_schedules')
            .select()
            .eq('user_id', user.id)
            .eq('status', 'active')
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (schedule != null) {
          buffer.writeln('• Kế hoạch tập: "${schedule['title']}".');
          final workouts = await supabase
              .from('scheduled_workouts')
              .select('title, date, target_distance_km, status')
              .eq('schedule_id', schedule['id'])
              .eq('status', 'planned')
              .order('date', ascending: true)
              .limit(5);
          final ws = workouts as List;
          if (ws.isNotEmpty) {
            buffer.writeln('  Buổi sắp tới:');
            for (final w in ws) {
              final dist = w['target_distance_km'];
              buffer.writeln(
                '  - ${w['date']}: ${w['title']}'
                '${dist != null ? ' ($dist km)' : ''}',
              );
            }
          }
        } else {
          buffer.writeln('• Kế hoạch tập: chưa có lịch tập đang hoạt động.');
        }
      } catch (e) {
        debugPrint('Attach plan error: $e');
      }
    }

    // --- Dinh dưỡng hôm nay ---
    if (attachments.contains(_ChatAttachment.nutrition) &&
        nutritionSummary != null) {
      final s = nutritionSummary;
      final calorieStatus = s.isOverCalories
          ? 'vượt ${s.caloriesOver.toStringAsFixed(0)} kcal'
          : 'còn lại ${s.caloriesRemaining.toStringAsFixed(0)} kcal';
      buffer.writeln(
        '• Dinh dưỡng hôm nay: nạp ${s.caloriesIn.toStringAsFixed(0)} kcal, '
        'tiêu hao ${s.caloriesOut.toStringAsFixed(0)} kcal, '
        '$calorieStatus '
        '(mục tiêu ${s.goal.dailyCalories.toStringAsFixed(0)} kcal); '
        'P ${s.protein.toStringAsFixed(0)}g / C ${s.carbs.toStringAsFixed(0)}g '
        '/ F ${s.fat.toStringAsFixed(0)}g.',
      );
    }

    final body = buffer.toString().trim();
    if (body.isEmpty) return '';
    return '[Dữ liệu người dùng đính kèm để phân tích]\n$body';
  }

  /// Lấy các mốc cân nặng gần đây (tối đa 6 lần ghi) theo thứ tự thời gian và
  /// định dạng thành chuỗi xu hướng "d/m: X.Ykg → ...". Trả về null nếu không có
  /// dữ liệu hoặc lỗi (fail-soft).
  Future<String?> _fetchWeightTrend(String userId) async {
    try {
      final rows = await Supabase.instance.client
          .from('weight_logs')
          .select('weight_kg, logged_at')
          .eq('user_id', userId)
          .order('logged_at', ascending: false)
          .limit(6);
      final logs = (rows as List).map((r) {
        return WeightLog.fromJson(r as Map<String, dynamic>);
      }).toList();
      if (logs.isEmpty) return null;
      // Đảo về thứ tự tăng dần (cũ -> mới) để thể hiện xu hướng.
      final ordered = logs.reversed;
      return ordered
          .map(
            (l) =>
                '${l.loggedAt.day}/${l.loggedAt.month}: '
                '${l.weightKg.toStringAsFixed(1)}kg',
          )
          .join(' → ');
    } catch (e) {
      debugPrint('Attach weight trend error: $e');
      return null;
    }
  }

  /// Lấy thời tiết hiện tại tại vị trí người dùng và định dạng thành một dòng
  /// để đính kèm cho AI. Trả về null nếu không có vị trí hoặc lỗi (fail-soft).
  Future<String?> _fetchWeatherLine() async {
    try {
      final position = await _getCurrentPosition();
      if (position == null) return null;
      final w = await _weatherService.fetchWeatherSnapshot(
        lat: position.latitude,
        lon: position.longitude,
      );
      final parts = <String>[];
      if (w.temperatureC != null) {
        parts.add('${w.temperatureC!.toStringAsFixed(1)}°C');
      }
      if (w.summary != null) parts.add(w.summary!.toLowerCase());
      if (w.humidity != null) parts.add('độ ẩm ${w.humidity}%');
      if (w.windKph != null) {
        parts.add('gió ${w.windKph!.toStringAsFixed(0)} km/h');
      }
      if (w.aqi != null) parts.add('AQI ${w.aqi} (${w.aqiLabel})');
      if (parts.isEmpty) return null;
      final place = w.locationName != null ? ' tại ${w.locationName}' : '';
      return '• Thời tiết hiện tại$place: ${parts.join(', ')}.';
    } catch (e) {
      debugPrint('Attach weather error: $e');
      return null;
    }
  }

  /// Lấy vị trí hiện tại (độ chính xác thấp, đủ cho thời tiết). Web/Debug dùng
  /// vị trí mặc định (Hà Nội) nếu định vị thất bại.
  Future<Position?> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('AI coach position error: $e');
      if (kIsWeb || kDebugMode) {
        return Position(
          latitude: 21.0285,
          longitude: 105.8342,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Nhãn tiếng Việt cho giới tính (null nếu chưa đặt) để ghép vào dòng thể trạng.
  String? _genderLabel(dynamic gender) {
    switch (gender) {
      case 'male':
        return 'giới tính nam';
      case 'female':
        return 'giới tính nữ';
      case 'other':
        return 'giới tính khác';
      default:
        return null;
    }
  }

  String _fmtPace(double pace) {
    if (pace <= 0 || pace.isInfinite || pace.isNaN) return '--';
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtActivityLine(Activity a) {
    final date = DateFormat('dd/MM').format(a.startedAt.toLocal());
    final pace = a.distanceKm > 0 ? a.durationMin / a.distanceKm : 0.0;
    return '$date: ${a.distanceKm.toStringAsFixed(1)} km, '
        '${a.durationMin.toStringAsFixed(0)} phút, pace ${_fmtPace(pace)}/km'
        '${a.avgHr != null ? ', HR ${a.avgHr} bpm' : ''}';
  }

  void _clearHistory() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          context.translate('delete_history'),
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        content: Text(
          context.translate('delete_history_confirm'),
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              context.translate('cancel'),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
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

  CoachInteractiveAction? _interactiveActionAt(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return null;
    final metadata = _messages[messageIndex]['metadata'];
    if (metadata is! Map || metadata['interactive_action'] is! Map) return null;
    try {
      return CoachInteractiveAction.fromJson(
        Map<String, dynamic>.from(metadata['interactive_action'] as Map),
      );
    } catch (e) {
      debugPrint('Invalid interactive coach action: $e');
      return null;
    }
  }

  Future<void> _applyInteractiveAction(int messageIndex) async {
    final action = _interactiveActionAt(messageIndex);
    if (action == null || !action.isPending) return;
    final nutritionService = context.read<NutritionService>();
    setState(() => _processingActionIndexes.add(messageIndex));
    try {
      DateTime? rescheduledAt;
      if (action.kind == 'workout_update' &&
          (action.changes.containsKey('date') ||
              action.changes.containsKey('start_time'))) {
        rescheduledAt = _workoutDateTimeForAction(action);
        await _trainingService.rescheduleWorkout(
          workoutId: action.targetId,
          workoutAt: rescheduledAt,
        );
      }
      await _coachToolService.applyAction(action);
      final updatedAction = action.copyWith(status: 'applied');
      final metadata = {'interactive_action': updatedAction.toJson()};
      if (!mounted) return;
      setState(() => _messages[messageIndex]['metadata'] = metadata);

      // Đồng bộ reminder local/DB sau khi ngày hoặc giờ buổi tập đổi. Đây là
      // best-effort: buổi tập đã được lưu thành công không bị rollback chỉ vì
      // thiết bị từ chối quyền thông báo.
      if (rescheduledAt != null) {
        try {
          final reminders = await _runReminderService.remindersForWorkouts([
            action.targetId,
          ]);
          final reminder = reminders[action.targetId];
          if (reminder != null) {
            await _runReminderService.saveReminder(
              workoutId: action.targetId,
              workoutTitle: action.changes['title']?.toString() ?? action.title,
              workoutAt: rescheduledAt,
              leadMinutes: reminder.leadMinutes,
              enabled: reminder.enabled,
            );
          }
        } catch (e) {
          debugPrint('Coach reminder sync failed: $e');
        }
      }
      if (action.kind == 'meal_update') await nutritionService.refresh();

      final messageId = _messages[messageIndex]['id'] as String?;
      if (messageId != null) {
        try {
          await _chatService.updateMessageMetadata(messageId, metadata);
        } catch (e) {
          // Dữ liệu đích đã được cập nhật; giữ card ở trạng thái applied để
          // tránh người dùng bấm lại và chỉ log lỗi persistence của lịch sử.
          debugPrint('Coach action metadata persistence failed: $e');
        }
      }
      if (!mounted) return;
      _showToast(context.translate('coach_change_applied'));
    } catch (e) {
      if (mounted) {
        _showToast('${context.translate('error_occurred')}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingActionIndexes.remove(messageIndex));
      }
    }
  }

  DateTime _workoutDateTimeForAction(CoachInteractiveAction action) {
    final dateText =
        action.changes['date']?.toString() ?? action.before['date']?.toString();
    final date = dateText == null ? null : DateTime.tryParse(dateText);
    if (date == null) throw const FormatException('Ngày tập không hợp lệ.');
    final timeText =
        action.changes['start_time']?.toString() ??
        action.before['start_time']?.toString() ??
        '06:00';
    final parts = timeText.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      throw const FormatException('Giờ tập không hợp lệ.');
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _cancelInteractiveAction(int messageIndex) async {
    final action = _interactiveActionAt(messageIndex);
    if (action == null || !action.isPending) return;
    final updatedAction = action.copyWith(status: 'cancelled');
    final metadata = {'interactive_action': updatedAction.toJson()};
    final messageId = _messages[messageIndex]['id'] as String?;
    if (messageId != null) {
      await _chatService.updateMessageMetadata(messageId, metadata);
    }
    if (!mounted) return;
    setState(() => _messages[messageIndex]['metadata'] = metadata);
  }

  void _discussInteractiveAction(int messageIndex) {
    final action = _interactiveActionAt(messageIndex);
    if (action == null) return;
    _controller.text = context.translate('coach_discuss_prompt', [
      action.title,
    ]);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _cancelLongWaitTimer();
    _controller.removeListener(_handlePromptChanged);
    _speech.cancel();
    _controller.dispose();
    _coachNameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cuộn xuống cuối danh sách sau khung hình kế tiếp (dùng khi có tin nhắn mới
  /// hoặc khi HLV thêm thẻ đề xuất tương tác).
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ----- Speech-to-Text (Issue #29) -----

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _speech.stop();
      return;
    }
    if (!_speech.isSupported) {
      _showToast('Trình duyệt không hỗ trợ nhập liệu bằng giọng nói.');
      return;
    }
    if (!_hasConfirmedMicrophoneAccess) {
      final confirmed = await showDevicePermissionDialog(
        context,
        icon: Icons.mic_none_outlined,
        title: context.translate('microphone_permission_title'),
        message: context.translate('microphone_permission_hint'),
        cancelLabel: context.translate('not_now'),
        confirmLabel: context.translate('request_microphone_permission'),
      );
      if (!confirmed || !mounted) return;
      _hasConfirmedMicrophoneAccess = true;
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
          _controller.selection = TextSelection.collapsed(
            offset: combined.length,
          );
        });
        if (isFinal) _baseText = combined;
      },
      onError: (code) {
        if (!mounted) return;
        if (code == 'not-allowed' || code == 'service-not-allowed') {
          _hasConfirmedMicrophoneAccess = false;
        }
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
      _controller.selection = TextSelection.collapsed(offset: _baseText.length);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final coachName = _coachNameController.text.trim();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: AppBar(
        title: Text(
          coachName.isEmpty ? 'Runny' : coachName,
          style: TextStyle(color: colorScheme.onSurface),
        ),
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
            onPressed: _showCoachSettings,
            icon: Icon(
              LucideIcons.user_round_pen,
              color: colorScheme.onSurface,
            ),
            tooltip: context.translate('coach_settings_title'),
          ),
          IconButton(
            onPressed: _clearHistory,
            icon: Icon(Icons.delete_outline, color: colorScheme.onSurface),
            tooltip: context.translate('delete_history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!widget.embedded)
            SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: sportPlatformGradient(context),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.embedded ? 0.0 : 16.0,
                      vertical: 16.0,
                    ),
                    itemCount:
                        _messages.length + (_greetingText != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasGreeting = _greetingText != null;
                      final messageIndex = index - (hasGreeting ? 1 : 0);
                      final msg = hasGreeting && index == 0
                          ? <String, dynamic>{
                              'role': 'assistant',
                              'content': _greetingText!,
                            }
                          : _messages[messageIndex];
                      final isUser = msg['role'] == 'user';
                      final hasInteractiveAction =
                          msg['metadata'] is Map &&
                          (msg['metadata'] as Map)['interactive_action'] is Map;
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width *
                                (hasInteractiveAction ? 0.9 : 0.75),
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? colorScheme.primary
                                : (isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isUser ? 20 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 20),
                            ),
                            border: isUser
                                ? null
                                : Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                          ),
                          child: _buildMessageContent(
                            context,
                            content: msg['content']!,
                            isUser: isUser,
                            messageIndex: messageIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        if (_showLongWaitNotice) ...[
                          const SizedBox(height: 12),
                          Text(
                            context.translate('ai_coach_long_wait_notice'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_contextActivity != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${context.translate('activity')}: ${_contextActivity!.distanceKm.toStringAsFixed(2)}km',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () =>
                                setState(() => _contextActivity = null),
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.primary,
                              size: 14,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isRecording) _buildListeningIndicator(context),
                _buildSuggestedQuestions(context),
                _buildAttachmentBar(context),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.embedded ? 0.0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    children: [
                      if (_isRecording)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            onPressed: _cancelRecording,
                            tooltip: 'Huỷ ghi âm',
                            icon: Icon(
                              Icons.close,
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
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

  Widget _buildMessageContent(
    BuildContext context, {
    required String content,
    required bool isUser,
    required int messageIndex,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = isUser ? Colors.white : colorScheme.onSurface;
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(color: textColor);

    if (isUser) {
      return Text(content, style: baseStyle);
    }

    final action = _interactiveActionAt(messageIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: content,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: baseStyle,
            strong: baseStyle?.copyWith(fontWeight: FontWeight.w700),
            em: baseStyle?.copyWith(fontStyle: FontStyle.italic),
            listBullet: baseStyle,
            code: baseStyle?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: colorScheme.surface.withValues(alpha: 0.45),
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          _buildInteractiveActionCard(context, action, messageIndex),
        ],
      ],
    );
  }

  Widget _buildInteractiveActionCard(
    BuildContext context,
    CoachInteractiveAction action,
    int messageIndex,
  ) {
    final colors = Theme.of(context).colorScheme;
    final processing = _processingActionIndexes.contains(messageIndex);
    final statusColor = switch (action.status) {
      'applied' => Colors.green,
      'cancelled' => colors.outline,
      _ => colors.primary,
    };
    return Container(
      key: ValueKey('coach_action_${action.kind}_${action.targetId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                action.kind == 'workout_update'
                    ? LucideIcons.calendar_sync
                    : LucideIcons.utensils,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ActionStatusChip(status: action.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          ...action.changes.entries.map((entry) {
            final oldValue = action.before[entry.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      _coachFieldLabel(context, entry.key),
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (oldValue != null)
                            TextSpan(
                              text: '${_coachValue(oldValue)}  →  ',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          TextSpan(
                            text: _coachValue(entry.value),
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (action.isPending) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: processing
                      ? null
                      : () => _applyInteractiveAction(messageIndex),
                  icon: processing
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(context.translate('coach_apply_change')),
                ),
                OutlinedButton.icon(
                  onPressed: processing
                      ? null
                      : () => _discussInteractiveAction(messageIndex),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(context.translate('coach_discuss_change')),
                ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () => _cancelInteractiveAction(messageIndex),
                  child: Text(context.translate('cancel')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _coachFieldLabel(BuildContext context, String field) =>
      switch (field) {
        'title' || 'food_name' => context.translate('coach_field_name'),
        'date' => context.translate('coach_field_date'),
        'start_time' || 'consumed_at' => context.translate('coach_field_time'),
        'description' => context.translate('coach_field_notes'),
        'target_distance_km' => context.translate('coach_field_distance'),
        'target_duration_min' => context.translate('coach_field_duration'),
        'workout_type' => context.translate('coach_field_workout_type'),
        'calories' => 'Calories',
        'protein' => 'Protein',
        'carbs' => 'Carbs',
        'fat' => 'Fat',
        'amount' => context.translate('coach_field_amount'),
        'unit' => context.translate('coach_field_unit'),
        'meal_type' => context.translate('meal_type'),
        _ => field,
      };

  String _coachValue(dynamic value) {
    if (value is double) {
      return value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(1);
    }
    return value?.toString() ?? '—';
  }

  Widget _buildSuggestedQuestions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldShow =
        _messages.isEmpty &&
        _controller.text.trim().isEmpty &&
        !_isRecording &&
        !_isLoading;
    if (!shouldShow || _selectedSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final key = _selectedSuggestions[index];
          final question = context.translate(key);
          return ActionChip(
            avatar: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: colorScheme.primary,
            ),
            label: Text(question),
            labelStyle: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            side: BorderSide(
              color: colorScheme.primary.withValues(
                alpha: isDark ? 0.24 : 0.18,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: () => _sendSuggestedQuestion(question),
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemCount: _selectedSuggestions.length,
      ),
    );
  }

  /// Hàng nút chọn dữ liệu đính kèm (cuộn ngang), hiển thị ngay trên ô nhập.
  Widget _buildAttachmentBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <(_ChatAttachment, IconData, String)>[
      (
        _ChatAttachment.activities,
        Icons.directions_run,
        context.translate('chat_ctx_activities'),
      ),
      (
        _ChatAttachment.metrics,
        Icons.insights,
        context.translate('chat_ctx_metrics'),
      ),
      (
        _ChatAttachment.plan,
        Icons.calendar_month,
        context.translate('chat_ctx_plan'),
      ),
      (
        _ChatAttachment.nutrition,
        Icons.restaurant,
        context.translate('chat_ctx_nutrition'),
      ),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Row(
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.translate('chat_attach_label'),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }
          final (key, icon, label) = items[index - 1];
          final selected = _attachments.contains(key);
          return Center(
            child: FilterChip(
              avatar: Icon(
                icon,
                size: 16,
                color: selected ? colorScheme.onPrimary : colorScheme.primary,
              ),
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              onSelected: (value) => setState(() {
                if (value) {
                  _attachments.add(key);
                } else {
                  _attachments.remove(key);
                }
              }),
            ),
          );
        },
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
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 10),
            _AudioWave(),
          ],
        ),
      ),
    );
  }
}

class _ActionStatusChip extends StatelessWidget {
  const _ActionStatusChip({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = context.translate(switch (status) {
      'applied' => 'coach_status_applied',
      'cancelled' => 'coach_status_cancelled',
      _ => 'coach_status_pending',
    });
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
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

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
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

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
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
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
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

class _AudioWaveState extends State<_AudioWave>
    with SingleTickerProviderStateMixin {
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

class _CoachSettingsSheet extends StatelessWidget {
  const _CoachSettingsSheet({
    required this.coachNameController,
    required this.persona,
    required this.isSaving,
    required this.onPersonaChanged,
    required this.onSave,
  });

  final TextEditingController coachNameController;
  final String persona;
  final bool isSaving;
  final ValueChanged<String> onPersonaChanged;
  final VoidCallback onSave;

  IconData _personaIcon(String id) => switch (id) {
    'disciplined' => Icons.flag_outlined,
    'energetic' => Icons.bolt_outlined,
    'scientific' => Icons.insights_outlined,
    'concise' => Icons.checklist_outlined,
    _ => Icons.spa_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedPersona = CoachPersona.byId(persona);

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.psychology_alt, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    context.translate('coach_settings_title'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.translate('coach_settings_desc'),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: coachNameController,
                maxLength: 24,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.translate('coach_name'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.translate('coach_persona'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CoachPersona.values.map((item) {
                  final isSelected = item.id == persona;
                  return ChoiceChip(
                    label: Text(context.translate(item.labelKey)),
                    avatar: Icon(
                      _personaIcon(item.id),
                      size: 16,
                      color: isSelected ? colors.onPrimary : colors.primary,
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    onSelected: (_) => onPersonaChanged(item.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                context.translate(selectedPersona.descriptionKey),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.translate('save_coach_settings')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
