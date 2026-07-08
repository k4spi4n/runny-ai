import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/training_service.dart';
import '../services/gemini_service.dart';
import '../services/chat_service.dart';
import '../services/speech_service.dart';
import '../services/nutrition_service.dart';
import '../services/weather_service.dart';
import '../widgets/ui_components.dart';
import '../widgets/paywall.dart';
import '../services/paywall_exception.dart';
import '../models/workout_models.dart';
import '../models/nutrition_models.dart';
import '../models/weight_models.dart';
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
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  String? _greetingText;
  bool _isLoading = false;
  // Đang nhận phản hồi streaming (chữ chạy dần trong bong bóng cuối).
  bool _isStreaming = false;
  bool _isRecording = false;
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handlePromptChanged);
    _contextActivity = widget.initialActivity;
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _controller.text = widget.initialPrompt!;
    }
    _loadGreeting();
    _loadHistory();
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
    // Chặn gửi chồng khi đang chờ/đang stream phản hồi trước đó.
    if (_isLoading || _isStreaming) return;

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
    });
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

    // Save user message
    await _chatService.saveMessage('user', text);

    try {
      // Check if user is asking for a plan (localized keywords)
      final lowercaseText = text.toLowerCase();
      bool isRequestingPlan =
          lowercaseText.contains('lịch tập') ||
          lowercaseText.contains('kế hoạch') ||
          lowercaseText.contains('training plan') ||
          lowercaseText.contains('schedule');

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
        // Streaming: phát từng đoạn văn bản ngay khi tới để chữ chạy dần, người
        // dùng không phải đợi phản hồi đầy đủ.
        final history = _messages.sublist(0, _messages.length - 1);
        final buffer = StringBuffer();
        int? assistantIndex; // vị trí bong bóng trả lời (tạo khi có token đầu)
        setState(() => _isStreaming = true);
        try {
          await for (final chunk in _geminiService.streamResponse(
            prompt,
            history: history,
          )) {
            buffer.write(chunk);
            if (!mounted) return;
            setState(() {
              if (assistantIndex == null) {
                _messages.add({
                  'role': 'assistant',
                  'content': buffer.toString(),
                });
                assistantIndex = _messages.length - 1;
                _isLoading = false; // token đầu tiên -> tắt spinner chờ
              } else {
                _messages[assistantIndex!]['content'] = buffer.toString();
              }
            });
            _scrollToBottom();
          }
        } catch (e) {
          // Chưa nhận được token nào -> để catch ngoài hiển thị lỗi/paywall như cũ.
          if (buffer.isEmpty) rethrow;
          // Đã có nội dung một phần: giữ lại, coi như kết thúc sớm.
          debugPrint('AI stream ended early: $e');
        } finally {
          if (mounted) setState(() => _isStreaming = false);
        }
        final full = buffer.toString();
        if (full.isNotEmpty) {
          await _chatService.saveMessage('assistant', full);
        }
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendSuggestedQuestion(String question) {
    if (_isLoading || _isStreaming) return;
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
            .select('distance_km, duration_min, avg_hr');
        final list = rows as List;
        double dist = 0, dur = 0;
        int hrSum = 0, hrCount = 0;
        for (final a in list) {
          dist += (a['distance_km'] as num).toDouble();
          dur += (a['duration_min'] as num).toDouble();
          if (a['avg_hr'] != null) {
            hrSum += (a['avg_hr'] as num).toInt();
            hrCount++;
          }
        }
        final pace = dist > 0 ? dur / dist : 0.0;
        buffer.writeln(
          '• Chỉ số tổng: ${list.length} buổi, ${dist.toStringAsFixed(1)} km, '
          'pace TB ${_fmtPace(pace)}/km'
          '${hrCount > 0 ? ', HR TB ${(hrSum / hrCount).round()} bpm' : ''}.',
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
      buffer.writeln(
        '• Dinh dưỡng hôm nay: nạp ${s.caloriesIn.toStringAsFixed(0)} kcal, '
        'tiêu hao ${s.caloriesOut.toStringAsFixed(0)} kcal, '
        'còn lại ${s.caloriesLeft.toStringAsFixed(0)} kcal '
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

  @override
  void dispose() {
    _controller.removeListener(_handlePromptChanged);
    _speech.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cuộn xuống cuối danh sách sau khung hình kế tiếp (dùng khi có tin nhắn mới
  /// hoặc khi bong bóng streaming dài ra).
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
          _controller.selection = TextSelection.collapsed(
            offset: combined.length,
          );
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: widget.embedded ? Colors.transparent : null,
      appBar: AppBar(
        title: Text(
          context.translate('ai_coach'),
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
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        _messages.length + (_greetingText != null ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasGreeting = _greetingText != null;
                      final msg = hasGreeting && index == 0
                          ? {'role': 'assistant', 'content': _greetingText!}
                          : _messages[index - (hasGreeting ? 1 : 0)];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
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
                          child: Text(
                            msg['content']!,
                            style: TextStyle(
                              color: isUser
                                  ? Colors.white
                                  : colorScheme.onSurface,
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
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
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
                  padding: const EdgeInsets.all(16.0),
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

  Widget _buildSuggestedQuestions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldShow =
        _messages.isEmpty &&
        _controller.text.trim().isEmpty &&
        !_isRecording &&
        !_isLoading &&
        !_isStreaming;
    if (!shouldShow) return const SizedBox.shrink();

    final suggestions = [
      'Hôm nay tôi nên chạy bài gì?',
      'Phân tích tiến bộ gần đây của tôi',
      'Tôi nên cải thiện pace hay nhịp tim trước?',
      'Gợi ý lịch tập 7 ngày tới',
      'Tôi cần lưu ý gì để tránh chấn thương?',
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final question = suggestions[index];
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
        itemCount: suggestions.length,
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
