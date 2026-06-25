import 'package:flutter/material.dart';
import '../widgets/ui_components.dart';
import '../l10n/app_localizations.dart';
import 'login_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _goToAuth(BuildContext context, {bool signUp = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginPage(initialIsSignUp: signUp)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: sportPlatformGradient(context))),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFFA6B27).withValues(alpha: 0.35), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                  child: Row(
                    children: [
                      const RunnyLogo(fontSize: 24),
                      const Spacer(),
                      const LanguageSwitcher(),
                      const ThemeToggle(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 860;
                            final hero = _Hero(
                              onGetStarted: () => _goToAuth(context, signUp: true),
                              onLogin: () => _goToAuth(context),
                              center: !isWide,
                            );
                            final features = _FeatureGrid(isWide: isWide);

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(flex: 5, child: hero),
                                  const SizedBox(width: 40),
                                  Expanded(flex: 4, child: features),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                hero,
                                const SizedBox(height: 40),
                                features,
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  child: Text(
                    context.translate('landing_footer'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;
  final bool center;

  const _Hero({
    required this.onGetStarted,
    required this.onLogin,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final align = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        badgeLabel(context, context.translate('landing_tagline')),
        const SizedBox(height: 20),
        Text(
          context.translate('landing_hero_title'),
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.translate('landing_hero_subtitle'),
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDark ? Colors.white70 : Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: 14,
          runSpacing: 14,
          children: [
            GradientButton.icon(
              onPressed: onGetStarted,
              width: 200,
              icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
              label: Text(context.translate('get_started')),
            ),
            OutlinedButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded, size: 20),
              label: Text(context.translate('login')),
              style: secondaryActionButton(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  final bool isWide;

  const _FeatureGrid({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final features = <_FeatureData>[
      _FeatureData(
        icon: Icons.smart_toy_rounded,
        title: context.translate('landing_feature_ai_title'),
        desc: context.translate('landing_feature_ai_desc'),
      ),
      _FeatureData(
        icon: Icons.show_chart_rounded,
        title: context.translate('landing_feature_tracking_title'),
        desc: context.translate('landing_feature_tracking_desc'),
      ),
      _FeatureData(
        icon: Icons.groups_rounded,
        title: context.translate('landing_feature_community_title'),
        desc: context.translate('landing_feature_community_desc'),
      ),
    ];

    return Column(
      children: [
        for (final f in features) ...[
          _FeatureCard(data: f),
          if (f != features.last) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureData({required this.icon, required this.title, required this.desc});
}

class _FeatureCard extends StatelessWidget {
  final _FeatureData data;

  const _FeatureCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return glassCard(
      context: context,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: accentPulseGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFA6B27).withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(data.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.desc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
