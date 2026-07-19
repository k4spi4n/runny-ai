import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../widgets/coach_suggestion_panel.dart';

List<CoachSuggestionItem> _previewItems(ColorScheme colors) => [
  CoachSuggestionItem(
    id: 'progress',
    icon: Icons.insights_rounded,
    title: 'Phân tích tiến bộ',
    description: 'Tìm xu hướng từ các buổi chạy và chỉ số gần đây.',
    prompt: 'Phân tích tiến bộ 4 tuần gần đây của tôi',
    accentColor: colors.primary,
  ),
  CoachSuggestionItem(
    id: 'workout',
    icon: Icons.fitness_center_rounded,
    title: 'Chọn bài tập',
    description: 'Nhận gợi ý dựa trên thể trạng và lịch hiện tại.',
    prompt: 'Hôm nay tôi nên chạy bài gì?',
    accentColor: colors.tertiary,
  ),
  CoachSuggestionItem(
    id: 'schedule',
    icon: Icons.calendar_month_rounded,
    title: 'Điều chỉnh lịch',
    description: 'Xem và duyệt đề xuất trước khi thay đổi được lưu.',
    prompt: 'Dời buổi chạy dài sang Chủ nhật',
    accentColor: colors.secondary,
  ),
  const CoachSuggestionItem(
    id: 'nutrition',
    icon: Icons.restaurant_rounded,
    title: 'Dinh dưỡng & phục hồi',
    description: 'Đối chiếu bữa ăn và phục hồi với kế hoạch tập.',
    prompt: 'Tôi đã ăn đủ cho buổi chạy tối chưa?',
    accentColor: Color(0xFF2E8B57),
  ),
];

@Preview(
  name: 'Coach suggestions · Mobile',
  group: 'AI Coach',
  size: Size(390, 820),
)
@Preview(
  name: 'Coach suggestions · Desktop',
  group: 'AI Coach',
  size: Size(900, 560),
)
Widget coachSuggestionPanelPreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF6750A4)),
    home: Builder(
      builder: (context) => Scaffold(
        body: SingleChildScrollView(
          child: CoachSuggestionPanel(
            title: 'Bạn muốn HLV giúp gì?',
            subtitle:
                'Chọn một câu hỏi mẫu hoặc hỏi về pace, nhịp tim, kỹ thuật chạy và hơn thế nữa.',
            items: _previewItems(Theme.of(context).colorScheme),
            onSelected: (_) {},
          ),
        ),
      ),
    ),
  );
}
