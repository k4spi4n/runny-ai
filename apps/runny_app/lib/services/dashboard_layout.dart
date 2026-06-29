import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý bố cục các mục tùy chỉnh được trên trang Tổng quan (dashboard):
/// thứ tự hiển thị + ẩn/hiện. Lưu bền qua [SharedPreferences] để giữ nguyên
/// lựa chọn của người dùng giữa các phiên.
///
/// Mặc định: ẩn "dinh dưỡng" và "tổng quan hiệu suất" cho gọn với người dùng
/// mới, tập trung vào hoạt động gần đây và nhận xét AI.
class DashboardLayout extends ChangeNotifier {
  static const String nutrition = 'nutrition';
  static const String performance = 'performance';
  static const String aiInsight = 'ai_insight';
  static const String todaySchedule = 'today_schedule';

  /// Tất cả mục có thể cấu hình (dùng để lọc dữ liệu cũ/không hợp lệ).
  static const List<String> allKeys = [
    nutrition,
    performance,
    aiInsight,
    todaySchedule,
  ];

  // Mặc định: nhận xét AI lên đầu, kế đến là lịch tập hôm nay; dinh dưỡng và
  // tổng quan hiệu suất bị ẩn cho gọn với người dùng mới.
  static const List<String> _defaultOrder = [
    aiInsight,
    todaySchedule,
    nutrition,
    performance,
  ];
  static const List<String> _defaultHidden = [nutrition, performance];

  static const String _orderKey = 'dash_section_order';
  static const String _hiddenKey = 'dash_section_hidden';

  List<String> _order = List.of(_defaultOrder);
  Set<String> _hidden = Set.of(_defaultHidden);
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Thứ tự hiện tại của các mục cấu hình.
  List<String> get order => List.unmodifiable(_order);

  bool isVisible(String key) => !_hidden.contains(key);

  /// Nạp cấu hình đã lưu (gọi một lần khi khởi tạo trang).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_orderKey);
      final savedHidden = prefs.getStringList(_hiddenKey);

      if (savedOrder != null) {
        // Giữ lại các key hợp lệ theo thứ tự đã lưu, rồi bổ sung key mới (nếu
        // sau này thêm mục) để không bao giờ thiếu mục nào.
        final known = savedOrder.where(allKeys.contains).toList();
        for (final k in allKeys) {
          if (!known.contains(k)) known.add(k);
        }
        _order = known;
      }
      if (savedHidden != null) {
        _hidden = savedHidden.where(allKeys.contains).toSet();
      }
    } catch (_) {
      // Lỗi đọc prefs -> giữ mặc định.
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderKey, _order);
      await prefs.setStringList(_hiddenKey, _hidden.toList());
    } catch (_) {
      // Bỏ qua lỗi lưu: trạng thái trong phiên vẫn áp dụng.
    }
  }

  void setVisible(String key, bool visible) {
    if (!allKeys.contains(key)) return;
    final changed = visible ? _hidden.remove(key) : _hidden.add(key);
    if (changed) {
      notifyListeners();
      _persist();
    }
  }

  /// [newIndex] đã được điều chỉnh sẵn cho mục bị gỡ ở [oldIndex]
  /// (theo ngữ nghĩa của `ReorderableListView.onReorderItem`).
  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _order.length) return;
    final item = _order.removeAt(oldIndex);
    _order.insert(newIndex.clamp(0, _order.length), item);
    notifyListeners();
    _persist();
  }

  void resetToDefault() {
    _order = List.of(_defaultOrder);
    _hidden = Set.of(_defaultHidden);
    notifyListeners();
    _persist();
  }
}
