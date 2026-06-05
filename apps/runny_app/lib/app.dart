import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/onboarding_page.dart';

class RunnyApp extends StatelessWidget {
  const RunnyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseDark = ThemeData.dark();
    return MaterialApp(
      title: 'Runny AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA6B27),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050814),
        canvasColor: Colors.transparent,
        cardColor: const Color(0xFF0D1230),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF111A38),
        ),
        textTheme: GoogleFonts.lexendTextTheme(baseDark.textTheme).apply(bodyColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          hintStyle: const TextStyle(color: Colors.white38),
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFA6B27), width: 1.6),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA6B27),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050814),
        canvasColor: Colors.transparent,
        cardColor: const Color(0xFF0D1230),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        textTheme: GoogleFonts.lexendTextTheme(baseDark.textTheme).apply(bodyColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          hintStyle: const TextStyle(color: Colors.white38),
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFA6B27), width: 1.6),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
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
          return const LoginPage();
        }
      },
    );
  }
}
