/// Bản no-op cho nền tảng native (Android/iOS/desktop): không có luồng cài PWA
/// nên nút cài luôn ẩn.
bool pwaInstallAvailable() => false;

Future<void> promptPwaInstall() async {}

void setPwaInstallabilityListener(void Function() onChange) {}
