import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/landing_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/reset_password_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'l10n/language_provider.dart';
import 'l10n/app_localizations.dart';

class RunnyApp extends StatelessWidget {
  const RunnyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      onGenerateTitle: (context) => context.translate('app_title'),
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _passwordRecovery = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          _passwordRecovery = true;
        }

        // Người dùng vừa bấm link đặt lại mật khẩu: yêu cầu đặt mật khẩu mới
        // trước khi cho vào ứng dụng.
        if (_passwordRecovery) {
          return ResetPasswordPage(
            onDone: () => setState(() => _passwordRecovery = false),
          );
        }

        final session = snapshot.data?.session;

        // Fallback to current session if stream hasn't emitted yet but we have data
        final effectiveSession = session ?? Supabase.instance.client.auth.currentSession;

        if (effectiveSession != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', effectiveSession.user.id)
                .maybeSingle(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final profile = profileSnapshot.data;
              if (profile == null || profile['has_completed_onboarding'] == false) {
                return const OnboardingPage();
              }

              return const DashboardPage();
            },
          );
        } else {
          return const LandingPage();
        }
      },
    );
  }
}
