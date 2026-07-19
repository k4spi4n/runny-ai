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
import 'package:runny_app/widgets/password_requirements_checklist.dart';
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
  bool initialIsSignUp = true,
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
            initialIsSignUp: initialIsSignUp,
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
}) async {
  await tester.enterText(_emailField, 'runner@example.com');
  await tester.enterText(_passwordField, password);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submitButton);
  await tester.tap(_submitButton);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'selected_locale': 'en'});
    _testPreferences = await SharedPreferences.getInstance();
    expect(await AppLocalizations.preload(const Locale('en')), isTrue);
  });

  testWidgets('renders one password field with a Done keyboard action', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    expect(_passwordField, findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('auth-confirm-password-field'),
        skipOffstage: false,
      ),
      findsNothing,
    );

    final password = _editableText(tester, _passwordField);
    expect(password.obscureText, isTrue);
    expect(password.textInputAction, TextInputAction.done);
  });

  testWidgets('switches auth mode at the top without unavailable providers', (
    tester,
  ) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    final signUpMode = find.byKey(const ValueKey('auth-signup-mode'));
    final loginMode = find.byKey(const ValueKey('auth-login-mode'));
    expect(signUpMode, findsOneWidget);
    expect(loginMode, findsOneWidget);
    expect(
      tester.getTopLeft(signUpMode).dy,
      lessThan(tester.getTopLeft(_emailField).dy),
    );
    expect(find.byIcon(Icons.g_mobiledata), findsNothing);
    expect(find.byIcon(Icons.facebook), findsNothing);

    await tester.tap(loginMode);
    await tester.pumpAndSettle();

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(
      _editableText(tester, _passwordField).autofillHints,
      contains(AutofillHints.password),
    );
  });

  testWidgets('toggles password visibility with semantics', (tester) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    final passwordToggle = find.byKey(
      const ValueKey('auth-password-visibility-toggle'),
      skipOffstage: false,
    );
    expect(tester.widget<IconButton>(passwordToggle).tooltip, 'Show password');
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    semantics.dispose();

    await tester.tap(passwordToggle);
    await tester.pump();
    expect(_editableText(tester, _passwordField).obscureText, isFalse);
    expect(tester.widget<IconButton>(passwordToggle).tooltip, 'Hide password');
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

    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Please enter your email.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(service.callCount, 0);
  });

  testWidgets('rejects a weak password without calling auth', (tester) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);
    await tester.enterText(_emailField, 'runner@example.com');
    await tester.enterText(_passwordField, 'runny');

    await _tapSubmit(tester);
    await tester.pump();

    expect(
      find.text('Your password does not meet the requirements below.'),
      findsOneWidget,
    );
    expect(service.callCount, 0);
  });

  testWidgets('submits a valid password without confirmation', (tester) async {
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);
    await _fillValidForm(tester);

    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(service.callCount, 1);
    expect(service.submittedPassword, 'Runny1');
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

  testWidgets('keeps password guidance above the mobile keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    tester.view.viewInsets = FakeViewPadding(
      bottom: 280 * tester.view.devicePixelRatio,
    );
    addTearDown(() {
      tester.view.resetViewInsets();
      tester.binding.setSurfaceSize(null);
    });
    final service = _FakeRegistrationService();
    await _pumpSubject(tester, service);

    expect(find.byKey(const ValueKey('auth-brand')), findsNothing);
    await tester.tap(_passwordField);
    await tester.pumpAndSettle();

    final guidance = find.byType(PasswordRequirementsChecklist);
    expect(guidance, findsOneWidget);
    expect(tester.getBottomRight(guidance).dy, lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);
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
