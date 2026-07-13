import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/widgets/password_requirements_checklist.dart';

Widget _buildSubject(String password) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('vi')],
    home: Scaffold(body: PasswordRequirementsChecklist(password: password)),
  );
}

void main() {
  testWidgets('updates each requirement from the entered password', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject('runny'));
    await tester.pumpAndSettle();

    expect(find.text('Different from your email password'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(3));

    await tester.pumpWidget(_buildSubject('Runny1'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);
  });

  test('requires length, lowercase, uppercase, and a number', () {
    expect(PasswordRequirementsChecklist.isValid('Runny1'), isTrue);
    expect(PasswordRequirementsChecklist.isValid('runny1'), isFalse);
    expect(PasswordRequirementsChecklist.isValid('RUNNY1'), isFalse);
    expect(PasswordRequirementsChecklist.isValid('Runny'), isFalse);
  });
}
