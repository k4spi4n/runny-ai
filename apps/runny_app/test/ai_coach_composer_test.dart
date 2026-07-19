import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/pages/ai_coach_page.dart';
import 'package:runny_app/services/ai_coach_hub_controller.dart';
import 'package:runny_app/services/nutrition_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder_anon_key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    expect(await AppLocalizations.preload(const Locale('vi')), isTrue);
  });

  testWidgets(
    'one tap focuses the coach input without moving it under the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AICoachHubController()),
            ChangeNotifierProvider(create: (_) => NutritionService()),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('vi')],
            home: const AICoachPage(),
          ),
        ),
      );
      // The page owns an indeterminate progress indicator while history loads,
      // so bounded pumps are more appropriate than pumpAndSettle here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final input = find.byKey(const ValueKey('coach-chat-input'));
      final editable = find.descendant(
        of: input,
        matching: find.byType(EditableText),
      );
      final initialRect = tester.getRect(input);

      await tester.tap(input);
      await tester.pump();

      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(tester.getRect(input), initialRect);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      expect(tester.getBottomLeft(input).dy, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    },
  );
}
