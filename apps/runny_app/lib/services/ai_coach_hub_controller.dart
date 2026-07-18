import 'package:flutter/foundation.dart';

import '../models/workout_models.dart';

/// Ngữ cảnh được chuyển từ một tính năng khác vào chatbot HLV AI trung tâm.
class AICoachHubRequest {
  const AICoachHubRequest({
    required this.id,
    this.activity,
    this.prompt,
    this.autoSend = false,
  });

  final int id;
  final Activity? activity;
  final String? prompt;
  final bool autoSend;
}

/// Điều phối các yêu cầu mở chatbot HLV AI đang được giữ trong Dashboard.
class AICoachHubController extends ChangeNotifier {
  AICoachHubRequest? _request;
  var _nextRequestId = 0;

  AICoachHubRequest? get request => _request;

  void open({Activity? activity, String? prompt, bool autoSend = false}) {
    _request = AICoachHubRequest(
      id: ++_nextRequestId,
      activity: activity,
      prompt: prompt,
      autoSend: autoSend,
    );
    notifyListeners();
  }

  void clear() {
    _request = null;
  }
}
