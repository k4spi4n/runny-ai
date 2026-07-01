import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/pwa_install.dart';

/// Nút "Cài ứng dụng" trên thanh điều hướng. Chỉ hiển thị khi trình duyệt cho
/// biết app đủ điều kiện cài PWA (event `beforeinstallprompt`); ẩn trên native
/// và khi app đã được cài, nên không chiếm chỗ vô ích.
class PwaInstallButton extends StatefulWidget {
  const PwaInstallButton({super.key});

  @override
  State<PwaInstallButton> createState() => _PwaInstallButtonState();
}

class _PwaInstallButtonState extends State<PwaInstallButton> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _available = pwaInstallAvailable();
    // Event có thể tới sau khi widget dựng xong -> lắng nghe để cập nhật hiển thị.
    setPwaInstallabilityListener(() {
      if (mounted) setState(() => _available = pwaInstallAvailable());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.install_mobile, color: colorScheme.onSurface),
      tooltip: context.translate('install_app'),
      onPressed: () async {
        await promptPwaInstall();
        if (mounted) setState(() => _available = pwaInstallAvailable());
      },
    );
  }
}
