import 'package:flutter/foundation.dart';

/// Kênh đồng bộ nhẹ giữa các tab giữ trạng thái trong Dashboard.
///
/// Những thao tác ở HLV AI, nhập hoạt động hoặc đồng bộ Strava có thể thay đổi
/// lịch tập trong khi tab Lịch tập đang nằm trong Offstage. Listener này giúp
/// trang tự nạp lại mà không buộc người dùng bấm "Làm mới".
class TrainingRefreshService extends ChangeNotifier {
  TrainingRefreshService._();

  static final TrainingRefreshService instance = TrainingRefreshService._();

  int _revision = 0;
  int get revision => _revision;

  int _pageOpenRevision = 0;
  int get pageOpenRevision => _pageOpenRevision;

  void notifyTrainingChanged() {
    _revision++;
    notifyListeners();
  }

  /// Báo rằng người dùng vừa chuyển trở lại tab Kế hoạch. Tách khỏi revision
  /// dữ liệu để trang chỉ hiện nhắc buổi bị lỡ khi thực sự được mở, không bật
  /// dialog trong lúc tab đang Offstage vì một tác vụ nền vừa đồng bộ xong.
  void notifyTrainingPageOpened() {
    _pageOpenRevision++;
    notifyListeners();
  }
}
