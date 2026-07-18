import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_models.dart';
import '../services/ai_coach_hub_controller.dart';

/// Gửi ngữ cảnh vào HLV AI trung tâm rồi đóng các màn hình con đang che
/// Dashboard. Dashboard sẽ tự chọn tab chatbot khi nhận được yêu cầu.
void openAICoachHub(
  BuildContext context, {
  Activity? activity,
  String? prompt,
  bool autoSend = false,
}) {
  context.read<AICoachHubController>().open(
    activity: activity,
    prompt: prompt,
    autoSend: autoSend,
  );
  Navigator.of(context).popUntil((route) => route.isFirst);
}
