import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runny_app/l10n/app_localizations.dart';
import 'package:runny_app/l10n/language_provider.dart';
import 'package:runny_app/pages/login_page.dart';
import 'package:runny_app/services/auth_service.dart';
import 'package:runny_app/theme/theme_provider.dart';
import 'package:runny_app/widgets/ui_components.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late SharedPreferences _testPreferences;

class _FakeRegistrationService implements RegistrationService {
  int callCount = 0;
  String? submittedEmail;
  String? submittedPassword;
  RegistrationResult result = const RegistrationResult(
    RegistrationStatus.confirmationRequired,
  );
  Object? error;
  Completer<RegistrationResult>? pendingResult;

  @override
  Future<RegistrationResult> signUp({
    required String email,
    required String password,
  }) async {
    callCount++;
    submittedEmail = email;
    submittedPassword = password;
    if (error case final error?) throw error;
    if (pendingResult case final pending?) return pending.future;
    return result;
  }
}

Finder get _emailField =>
    find.byKey(const ValueKey('auth-email-field'), skipOffstage: false);
Finder get _passwordField =>
    find.byKey(const ValueKey('auth-password-field'), skipOffstage: false);
Finder get _confirmPasswordField => find.descendant(
  of: find.byKey(
    const ValueKey('auth-confirm-password-field'),
    skipOffstage: false,
  ),
  matching: find.byType(TextFormField, skipOffstage: false),
  skipOffstage: false,
);
Finder get _submitButton =>
    find.byKey(const ValueKey('auth-submit-button'), skipOffstage: false);

EditableText _editableText(WidgetTester tester, Finder field) =>
    tester.widget<EditableText>(
      find.descendant(
        of: field,
        matching: find.byType(EditableText, skipOffstage: false),
        skipOffstage: false,
      ),
    );

Future<void> _pumpSubject(
  WidgetTester tester,
  _FakeRegistrationService service, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider(_testPreferences),
          ),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(_testPreferences),
          ),
        ],
        child: MaterialApp(
          key: ObjectKey(service),
          navigatorKey: GlobalKey<NavigatorState>(),
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeMode,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('vi')],
          home: LoginPage(
            key: ObjectKey(service),
            initialIsSignUp: true,
            registrationService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

Future<void> _fillValidForm(
  WidgetTester tester, {
  String password = 'Runny1',
  String? confirmation,
}) async {
  await tester.enterText(_emailField, 'runner@example.com');
  await tester.enterText(_passwordField, password);
  await tester.enterText(_confirmPasswordField, confirmation ?? password);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'selected_locale': 'en'});
    _testPreferences = await SharedPreferences.getInstance();
  });

  testWidgets('renders both password fields with keyboard actions', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    expect(_passwordField, findsOneWidget);
    expect(_confirmPasswordField, findsOneWidget);
    expect(
      find.textContaining('Confirm password', findRichText: true),
      findsOneWidget,
    );

    final password = _editableText(tester, _passwordField);
    final confirmation = _editableText(tester, _confirmPasswordField);
    expect(password.obscureText, isTrue);
    expect(confirmation.obscureText, isTrue);
    expect(password.textInputAction, TextInputAction.next);
    expect(confirmation.textInputAction, TextInputAction.done);
  });

  testWidgets('toggles password visibility independently with semantics', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    final passwordToggle = find.byKey(
      const ValueKey('auth-password-visibility-toggle'),
      skipOffstage: false,
    );
    final confirmationToggle = find.byKey(
      const ValueKey('auth-confirm-password-visibility-toggle'),
      skipOffstage: false,
    );
    expect(tester.widget<IconButton>(passwordToggle).tooltip, 'Show password');
    expect(
      tester.widget<IconButton>(confirmationToggle).tooltip,
      'Show password',
    );
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Show password'), findsNWidgets(2));
    semantics.dispose();

    await tester.tap(passwordToggle);
    await tester.pump();
    expect(_editableText(tester, _passwordField).obscureText, isFalse);
    expect(_editableText(tester, _confirmPasswordField).obscureText, isTrue);
    expect(tester.widget<IconButton>(passwordToggle).tooltip, 'Hide password');

    await tester.tap(confirmationToggle);
    await tester.pump();
    expect(_editableText(tester, _passwordField).obscureText, isFalse);
    expect(_editableText(tester, _confirmPasswordField).obscureText, isFalse);
  });

  testWidgets('renders the signup form in light and dark themes', (
    tester,
  ) async {
    final lightService = _FakeRegistrationService();
    await _pumpSubject(tester, lightService);
    expect(
      Theme.of(tester.element(_passwordField)).brightness,
      Brightness.light,
    );

    final darkService = _FakeRegistrationService();
    await _pumpSubject(tester, darkService, themeMode: ThemeMode.dark);
    expect(
      Theme.of(tester.element(_passwordField)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows required errors only after submit and skips auth', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    expect(find.text('Please enter your password.'), findsNothing);
    expect(find.text('Please confirm your password.'), findsNothing);

    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(find.text('Please confirm your password.'), findsOneWidget);
    expect(service.callCount, 0);
  });

  testWidgets('rejects a weak password without calling auth', (tester) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);
    await tester.enterText(_emailField, 'runner@example.com');
    await tester.enterText(_passwordField, 'runny');
    await tester.enterText(_confirmPasswordField, 'runny');

    await _tapSubmit(tester);
    await tester.pump();

    expect(
      find.text('Your password does not meet the requirements below.'),
      findsOneWidget,
    );
    expect(service.callCount, 0);
  });

  testWidgets('updates mismatch error when either password changes', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);
    await _fillValidForm(tester, confirmation: 'Runny2');

    await _tapSubmit(tester);
    await tester.pump();
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(service.callCount, 0);

    await tester.enterText(_confirmPasswordField, 'Runny1');
    await tester.pump();
    expect(find.text('The passwords do not match.'), findsNothing);

    await tester.enterText(_passwordField, 'Runny2');
    await tester.pump();
    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(service.callCount, 0);
  });

  testWidgets(
    'submits once, sends only primary password, and disables button',
    (tester) async {
      final service = _FakeRegistrationService()
        ..pendingResult = Completer<RegistrationResult>();
      await _pumpSubject(tester, service);
      await _fillValidForm(tester);

      await _tapSubmit(tester);
      await tester.pump();

      expect(service.callCount, 1);
      expect(service.submittedEmail, 'runner@example.com');
      expect(service.submittedPassword, 'Runny1');
      expect(tester.widget<GradientButton>(_submitButton).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(_submitButton);
      await tester.pump();
      expect(service.callCount, 1);

      service.pendingResult!.complete(
        const RegistrationResult(RegistrationStatus.confirmationRequired),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('submits with the keyboard Done action', (tester) async {
    final service = _FakeRegistrationService()
      ..pendingResult = Completer<RegistrationResult>();
    await _pumpSubject(tester, service);
    await _fillValidForm(tester);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(service.callCount, 1);
    service.pendingResult!.complete(
      const RegistrationResult(RegistrationStatus.confirmationRequired),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('maps Supabase signup errors to friendly localized messages', (
    tester,
  ) async {
    final service = _FakeRegistrationService()
      ..error = const AuthException(
        'technical user lookup detail',
        code: 'user_already_exists',
      );
    await _pumpSubject(tester, service);
    await _fillValidForm(tester);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('This email is already registered. Please log in instead.'),
      findsOneWidget,
    );
    expect(find.textContaining('technical user lookup detail'), findsNothing);
  });

  testWidgets('maps network and timeout failures without technical details', (
    tester,
  ) async {
    final service = _FakeRegistrationService()
      ..error = AuthRetryableFetchException(message: 'failed to fetch');
    await _pumpSubject(tester, service);
    await _fillValidForm(tester);
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to connect. Check your network and try again.'),
      findsOneWidget,
    );

    service.error = TimeoutException('backend detail');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('The request took too long. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('backend detail'), findsNothing);
  });

  testWidgets('does not overflow on a small mobile viewport with errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(service.callCount, 0);
  });

  testWidgets('disposes local password field state when page is removed', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);
    await _fillValidForm(tester);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
