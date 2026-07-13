import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

/// Hộp thoại giải thích mục đích trước khi gọi quyền hệ thống cho micro/camera.
class DevicePermissionDialog extends StatelessWidget {
  const DevicePermissionDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const Key('device-permission-dialog'),
      icon: Icon(icon, color: colorScheme.primary, size: 32),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton.icon(
          key: const Key('confirm-device-permission-button'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.lock_open_outlined, size: 18),
          label: Text(confirmLabel),
        ),
      ],
    );
  }
}

Future<bool> showDevicePermissionDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String cancelLabel,
  required String confirmLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => DevicePermissionDialog(
          icon: icon,
          title: title,
          message: message,
          cancelLabel: cancelLabel,
          confirmLabel: confirmLabel,
        ),
      ) ??
      false;
}

@Preview(
  name: 'Microphone permission',
  group: 'Permissions',
  size: Size(420, 300),
)
Widget microphonePermissionDialogPreview() {
  return const MaterialApp(
    home: Scaffold(
      body: Center(
        child: DevicePermissionDialog(
          icon: Icons.mic_none_outlined,
          title: 'Cho phép dùng micro?',
          message:
              'Nhấn nút để cấp quyền micro khi bạn muốn nhập câu hỏi bằng giọng nói.',
          cancelLabel: 'Để sau',
          confirmLabel: 'Cho phép truy cập micro',
        ),
      ),
    ),
  );
}
