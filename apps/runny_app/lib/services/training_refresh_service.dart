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

  void notifyTrainingChanged() {
    _revision++;
    notifyListeners();
  }
}
