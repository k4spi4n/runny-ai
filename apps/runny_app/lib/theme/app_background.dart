/// Ảnh nền tùy chọn cho khu vực ứng dụng sau khi đăng nhập.
///
/// [none] giữ nguyên gradient mặc định để người dùng có thể quay về giao diện
/// gốc bất cứ lúc nào.
enum AppBackground {
  none,
  goldenStart,
  flowingMiles,
  electricPace,
  forestCalm,
  cityPulse,
}

extension AppBackgroundDetails on AppBackground {
  String? get assetPath {
    switch (this) {
      case AppBackground.none:
        return null;
      case AppBackground.goldenStart:
        return 'assets/images/backgrounds/golden-start.webp';
      case AppBackground.flowingMiles:
        return 'assets/images/backgrounds/flowing-miles.webp';
      case AppBackground.electricPace:
        return 'assets/images/backgrounds/electric-pace.webp';
      case AppBackground.forestCalm:
        return 'assets/images/backgrounds/forest-calm.webp';
      case AppBackground.cityPulse:
        return 'assets/images/backgrounds/city-pulse.webp';
    }
  }

  String get labelKey {
    switch (this) {
      case AppBackground.none:
        return 'background_none';
      case AppBackground.goldenStart:
        return 'background_golden_start';
      case AppBackground.flowingMiles:
        return 'background_flowing_miles';
      case AppBackground.electricPace:
        return 'background_electric_pace';
      case AppBackground.forestCalm:
        return 'background_forest_calm';
      case AppBackground.cityPulse:
        return 'background_city_pulse';
    }
  }
}
