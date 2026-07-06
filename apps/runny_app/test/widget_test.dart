import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:runny_app/app.dart';
import 'package:runny_app/theme/theme_provider.dart';
import 'package:runny_app/l10n/language_provider.dart';
import 'package:runny_app/services/nutrition_service.dart';
import 'package:runny_app/widgets/ui_components.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder_anon_key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => LanguageProvider(prefs)),
          ChangeNotifierProvider(create: (_) => NutritionService()),
        ],
        child: const RunnyApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify that our app starts.
    expect(find.byType(RunnyLogo), findsAtLeastNWidgets(1));
  });
}
