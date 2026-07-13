import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/widgets/device_permission_dialog.dart';

void main() {
  testWidgets('chỉ xác nhận quyền khi người dùng bấm nút cho phép', (
    tester,
  ) async {
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                confirmed = await showDevicePermissionDialog(
                  context,
                  icon: Icons.mic_none_outlined,
                  title: 'Cho phép dùng micro?',
                  message: 'Dùng micro để nhập câu hỏi bằng giọng nói.',
                  cancelLabel: 'Để sau',
                  confirmLabel: 'Cho phép truy cập micro',
                );
              },
              child: const Text('Mở hộp thoại'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở hộp thoại'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('device-permission-dialog')), findsOneWidget);
    expect(confirmed, isNull);

    await tester.tap(find.byKey(const Key('confirm-device-permission-button')));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
