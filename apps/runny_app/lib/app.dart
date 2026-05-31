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
    return MaterialApp(
      title: 'Runny AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orangeAccent,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.lexendTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orangeAccent,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.lexendTextTheme(ThemeData.dark().textTheme),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        
        if (session != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', session.user.id)
                .maybeSingle(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final profile = profileSnapshot.data;
              // If weight_kg is null, we assume onboarding is not finished
              if (profile == null || profile['weight_kg'] == null) {
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
