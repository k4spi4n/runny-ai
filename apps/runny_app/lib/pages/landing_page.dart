import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_components.dart';
import 'login_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _featuresKey = GlobalKey();
  final _howItWorksKey = GlobalKey();
  final _techStackKey = GlobalKey();
  final _getStartedKey = GlobalKey();

  void _goToAuth(BuildContext context, {bool signUp = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginPage(initialIsSignUp: signUp)),
    );
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: sportPlatformGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _LandingNavbar(
                onFeatures: () => _scrollTo(_featuresKey),
                onHowItWorks: () => _scrollTo(_howItWorksKey),
                onTechStack: () => _scrollTo(_techStackKey),
                onGetStarted: () => _scrollTo(_getStartedKey),
                onLogin: () => _goToAuth(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionBand(
                        topPadding: 42,
                        bottomPadding: 72,
                        child: _HeroSection(
                          onGetStarted: () => _goToAuth(context, signUp: true),
                          onExploreFeatures: () => _scrollTo(_featuresKey),
                        ),
                      ),
                      _SectionBand(
                        key: _featuresKey,
                        child: const _FeaturesSection(),
                      ),
                      const _SectionBand(child: _ProductValueSection()),
                      _SectionBand(
                        key: _howItWorksKey,
                        child: const _HowItWorksSection(),
                      ),
                      _SectionBand(
                        key: _techStackKey,
                        child: const _TechStackSection(),
                      ),
                      _SectionBand(
                        key: _getStartedKey,
                        child: _FinalCtaSection(
                          onGetStarted: () => _goToAuth(context, signUp: true),
                        ),
                      ),
                      const _SectionBand(
                        topPadding: 28,
                        bottomPadding: 0,
                        child: _LandingFooter(),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.dividerColor.withValues(
                  alpha: isDark ? 0.12 : 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingNavbar extends StatelessWidget {
  const _LandingNavbar({
    required this.onFeatures,
    required this.onHowItWorks,
    required this.onTechStack,
    required this.onGetStarted,
    required this.onLogin,
  });

  final VoidCallback onFeatures;
  final VoidCallback onHowItWorks;
  final VoidCallback onTechStack;
  final VoidCallback onGetStarted;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final navItems = <_NavItem>[
      _NavItem(context.translate('landing_nav_features'), onFeatures),
      _NavItem(context.translate('landing_nav_how_it_works'), onHowItWorks),
      _NavItem(context.translate('landing_nav_tech_stack'), onTechStack),
      _NavItem(context.translate('get_started'), onGetStarted),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF050814).withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.78),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: isDark ? 0.12 : 0.18),
          ),
        ),
      ),
      child: ResponsiveContent(
        maxWidth: 1180,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = MediaQuery.sizeOf(context).width < 980;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                12,
                isCompact ? 8 : 16,
                12,
              ),
              child: Row(
                children: [
                  RunnyLogo(fontSize: isCompact ? 20 : 24),
                  const Spacer(),
                  if (isCompact)
                    PopupMenuButton<VoidCallback>(
                      tooltip: context.translate('landing_nav_menu'),
                      icon: const Icon(Icons.menu_rounded),
                      onSelected: (callback) => callback(),
                      itemBuilder: (context) => [
                        for (final item in navItems)
                          PopupMenuItem(
                            value: item.onTap,
                            child: Text(item.label),
                          ),
                        PopupMenuItem(
                          value: onLogin,
                          child: Text(context.translate('login')),
                        ),
                      ],
                    )
                  else ...[
                    for (final item in navItems)
                      _NavTextButton(label: item.label, onTap: item.onTap),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(context.translate('login')),
                      style: secondaryActionButton(context).copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const LanguageSwitcher(),
                  const ThemeToggle(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;
}

class _NavTextButton extends StatelessWidget {
  const _NavTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _SectionBand extends StatelessWidget {
  const _SectionBand({
    super.key,
    required this.child,
    this.topPadding = 58,
    this.bottomPadding = 58,
  });

  final Widget child;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ResponsiveContent(
      maxWidth: 1180,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
        child: child,
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onGetStarted,
    required this.onExploreFeatures,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onExploreFeatures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 880;
        final headlineStyle =
            (isWide
                    ? theme.textTheme.displayMedium
                    : theme.textTheme.displaySmall)
                ?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.06,
                  letterSpacing: 0,
                  color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                );

        final content = Column(
          crossAxisAlignment: isWide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            badgeLabel(
              context,
              context.translate('landing_badge'),
              background: isDark
                  ? const Color(0xFF173A33)
                  : const Color(0xFFE4F8EC),
            ),
            const SizedBox(height: 22),
            Text(
              'Runny AI',
              textAlign: isWide ? TextAlign.start : TextAlign.center,
              style: headlineStyle,
            ),
            const SizedBox(height: 14),
            Text(
              context.translate('landing_slogan'),
              textAlign: isWide ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                context.translate('landing_description'),
                textAlign: isWide ? TextAlign.start : TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Wrap(
              alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: [
                GradientButton.icon(
                  onPressed: onGetStarted,
                  width: 198,
                  icon: const Icon(
                    Icons.directions_run_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(context.translate('get_started')),
                ),
                OutlinedButton.icon(
                  onPressed: onExploreFeatures,
                  icon: const Icon(Icons.travel_explore_rounded, size: 20),
                  label: Text(context.translate('landing_explore_features')),
                  style: secondaryActionButton(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _HeroMetricsStrip(),
          ],
        );

        final visual = const _HeroDashboardMockup();
        if (!isWide) {
          return Column(
            children: [content, const SizedBox(height: 42), visual],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 11, child: content),
            const SizedBox(width: 44),
            Expanded(flex: 9, child: visual),
          ],
        );
      },
    );
  }
}

class _HeroMetricsStrip extends StatelessWidget {
  const _HeroMetricsStrip();

  @override
  Widget build(BuildContext context) {
    return const _AtomicFeatureCarousel();
  }
}

class _AtomicFeatureCarousel extends StatefulWidget {
  const _AtomicFeatureCarousel();

  @override
  State<_AtomicFeatureCarousel> createState() => _AtomicFeatureCarouselState();
}

class _AtomicFeatureCarouselState extends State<_AtomicFeatureCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _atomicFeatureRows(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        height: 154,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0, 0.08, 0.92, 1],
              ).createShader(bounds);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _AtomicFeatureRow(
                    controller: _controller,
                    features: rows[0],
                    reverse: false,
                  ),
                  _AtomicFeatureRow(
                    controller: _controller,
                    features: rows[1],
                    reverse: true,
                  ),
                  _AtomicFeatureRow(
                    controller: _controller,
                    features: rows[2],
                    reverse: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AtomicFeatureRow extends StatelessWidget {
  static const double _gap = 10;
  static const double _chipMinWidth = 96;
  static const double _chipMaxWidth = 292;
  static const double _chipHorizontalPadding = 24;
  static const double _iconWidth = 18;
  static const double _iconGap = 8;

  final AnimationController controller;
  final List<_AtomicFeatureData> features;
  final bool reverse;

  const _AtomicFeatureRow({
    required this.controller,
    required this.features,
    required this.reverse,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = _chipTextStyle(context);
    final textDirection = Directionality.of(context);
    final chipWidths = [
      for (final feature in features)
        _chipWidthFor(feature.label, textStyle, textDirection),
    ];
    final sequenceWidth = chipWidths.fold<double>(
      0,
      (total, width) => total + width + _gap,
    );

    return SizedBox(
      height: 38,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final progress = controller.value;
            final offset = reverse
                ? -progress * sequenceWidth
                : -sequenceWidth + progress * sequenceWidth;

            return Transform.translate(
              offset: Offset(offset, 0),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: sequenceWidth * 3,
                maxWidth: sequenceWidth * 3,
                child: Row(
                  children: [
                    _FeatureSequence(features: features, widths: chipWidths),
                    _FeatureSequence(features: features, widths: chipWidths),
                    _FeatureSequence(features: features, widths: chipWidths),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static TextStyle _chipTextStyle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.textTheme.labelMedium?.copyWith(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ) ??
        TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        );
  }

  static double _chipWidthFor(
    String label,
    TextStyle style,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();
    return (painter.width + _chipHorizontalPadding + _iconWidth + _iconGap)
        .clamp(_chipMinWidth, _chipMaxWidth)
        .toDouble();
  }
}

class _FeatureSequence extends StatelessWidget {
  final List<_AtomicFeatureData> features;
  final List<double> widths;

  const _FeatureSequence({required this.features, required this.widths});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < features.length; i++) ...[
          _AtomicFeatureChip(feature: features[i], width: widths[i]),
          const SizedBox(width: _AtomicFeatureRow._gap),
        ],
      ],
    );
  }
}

class _AtomicFeatureChip extends StatelessWidget {
  final _AtomicFeatureData feature;
  final double width;

  const _AtomicFeatureChip({required this.feature, required this.width});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final innerColor = isDark
        ? const Color(0xFF0E1430).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.92);
    final regularBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: width,
      height: 38,
      padding: EdgeInsets.all(feature.isAi ? 1.4 : 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: feature.isAi ? accentPulseGradient : null,
        color: feature.isAi ? null : regularBorderColor,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: innerColor,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(feature.icon, size: 18, color: feature.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                feature.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _AtomicFeatureRow._chipTextStyle(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtomicFeatureData {
  final IconData icon;
  final String label;
  final Color color;
  final bool isAi;

  const _AtomicFeatureData({
    required this.icon,
    required this.label,
    required this.color,
    this.isAi = false,
  });
}

List<List<_AtomicFeatureData>> _atomicFeatureRows(BuildContext context) {
  const orange = Color(0xFFFF8E53);
  const green = Color(0xFF4ADE80);
  const blue = Color(0xFF3CABFF);
  const yellow = Color(0xFFFFC66A);

  return [
    [
      _AtomicFeatureData(
        icon: Icons.smart_toy_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Chat với HLV AI',
          en: 'Chat with AI coach',
        ),
        color: orange,
        isAi: true,
      ),
      _AtomicFeatureData(
        icon: Icons.auto_awesome_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'AI tạo giáo án cá nhân',
          en: 'AI builds personal plans',
        ),
        color: green,
        isAi: true,
      ),
      _AtomicFeatureData(
        icon: Icons.tune_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'AI tinh chỉnh lịch tập',
          en: 'AI tunes training plans',
        ),
        color: blue,
        isAi: true,
      ),
      _AtomicFeatureData(
        icon: Icons.local_fire_department_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Gợi ý khởi động theo buổi',
          en: 'Workout-specific warmups',
        ),
        color: yellow,
      ),
      _AtomicFeatureData(
        icon: Icons.route_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Lịch tập hôm nay',
          en: "Today's workout schedule",
        ),
        color: green,
      ),
      _AtomicFeatureData(
        icon: Icons.history_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Lịch sử giáo án',
          en: 'Training plan history',
        ),
        color: blue,
      ),
    ],
    [
      _AtomicFeatureData(
        icon: Icons.upload_file_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Nhập file GPX/FIT/TCX',
          en: 'Import GPX/FIT/TCX files',
        ),
        color: blue,
      ),
      _AtomicFeatureData(
        icon: Icons.edit_note_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Ghi buổi chạy thủ công',
          en: 'Manual run logging',
        ),
        color: yellow,
      ),
      _AtomicFeatureData(
        icon: Icons.link_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Gắn hoạt động vào buổi tập',
          en: 'Link runs to workouts',
        ),
        color: green,
      ),
      _AtomicFeatureData(
        icon: Icons.speed_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Biểu đồ pace theo thời gian',
          en: 'Pace chart over time',
        ),
        color: orange,
      ),
      _AtomicFeatureData(
        icon: Icons.monitor_heart_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Theo dõi vùng nhịp tim',
          en: 'Heart-rate zone tracking',
        ),
        color: green,
      ),
      _AtomicFeatureData(
        icon: Icons.landscape_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Phân tích độ cao tích lũy',
          en: 'Elevation gain analysis',
        ),
        color: blue,
      ),
      _AtomicFeatureData(
        icon: Icons.cloud_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Thời tiết & chất lượng khí',
          en: 'Weather and air quality',
        ),
        color: yellow,
      ),
    ],
    [
      _AtomicFeatureData(
        icon: Icons.restaurant_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Nhật ký dinh dưỡng runner',
          en: 'Runner nutrition log',
        ),
        color: green,
      ),
      _AtomicFeatureData(
        icon: Icons.camera_alt_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'AI nhận diện món ăn từ ảnh',
          en: 'AI food photo recognition',
        ),
        color: orange,
        isAi: true,
      ),
      _AtomicFeatureData(
        icon: Icons.lightbulb_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'AI gợi ý thực đơn',
          en: 'AI meal suggestions',
        ),
        color: yellow,
        isAi: true,
      ),
      _AtomicFeatureData(
        icon: Icons.monitor_weight_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Theo dõi cân nặng & mục tiêu',
          en: 'Weight and goal tracking',
        ),
        color: blue,
      ),
      _AtomicFeatureData(
        icon: Icons.groups_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Cộng đồng runner',
          en: 'Runner community',
        ),
        color: green,
      ),
      _AtomicFeatureData(
        icon: Icons.leaderboard_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Bảng xếp hạng cộng đồng',
          en: 'Community leaderboard',
        ),
        color: orange,
      ),
      _AtomicFeatureData(
        icon: Icons.emoji_events_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Huy hiệu thành tích chạy',
          en: 'Running achievement badges',
        ),
        color: yellow,
      ),
      _AtomicFeatureData(
        icon: Icons.handshake_rounded,
        label: _landingFeatureLabel(
          context,
          vi: 'Ghép bạn chạy cùng pace',
          en: 'Match partners by pace',
        ),
        color: blue,
      ),
    ],
  ];
}

String _landingFeatureLabel(
  BuildContext context, {
  required String vi,
  required String en,
}) {
  return Localizations.localeOf(context).languageCode == 'vi' ? vi : en;
}

class _HeroDashboardMockup extends StatelessWidget {
  const _HeroDashboardMockup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final panelColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.82);

    return AspectRatio(
      aspectRatio: 0.92,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0C1430), Color(0xFF102E34)]
                : const [Color(0xFFFFFFFF), Color(0xFFEAF7FF)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.9),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 34,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: accentPulseGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.translate('landing_mockup_insight_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        context.translate('landing_mockup_insight_desc'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const _DashboardStat(
                          labelKey: 'landing_mockup_distance',
                          value: '8.4 km',
                          icon: Icons.route_rounded,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 12),
                        const _DashboardStat(
                          labelKey: 'landing_mockup_pace',
                          value: '5:28',
                          icon: Icons.speed_rounded,
                          color: AppTheme.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: CustomPaint(
                        painter: _RouteAndChartPainter(
                          primary: AppTheme.success,
                          secondary: AppTheme.secondary,
                          muted: theme.colorScheme.outline.withValues(
                            alpha: 0.28,
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ProgressBar(
                            labelKey: 'landing_mockup_weekly_goal',
                            value: 0.72,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ProgressBar(
                            labelKey: 'landing_mockup_training_load',
                            value: 0.56,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.translate('landing_mockup_next'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStat extends StatelessWidget {
  const _DashboardStat({
    required this.labelKey,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String labelKey;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              context.translate(labelKey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.labelKey,
    required this.value,
    required this.color,
  });

  final String labelKey;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.translate(labelKey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            color: color,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
      ],
    );
  }
}

class _RouteAndChartPainter extends CustomPainter {
  const _RouteAndChartPainter({
    required this.primary,
    required this.secondary,
    required this.muted,
  });

  final Color primary;
  final Color secondary;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = muted
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final routePath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.72)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.28,
        size.width * 0.38,
        size.height * 0.88,
        size.width * 0.54,
        size.height * 0.46,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.12,
        size.width * 0.76,
        size.height * 0.72,
        size.width * 0.92,
        size.height * 0.32,
      );

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 8
      ..shader = LinearGradient(
        colors: [primary, secondary],
      ).createShader(Offset.zero & size);
    canvas.drawPath(routePath, routePaint);

    final dotPaint = Paint()..color = primary;
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.72),
      7,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.32),
      7,
      Paint()..color = secondary,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteAndChartPainter oldDelegate) {
    return oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.muted != muted;
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureData(
        icon: Icons.smart_toy_rounded,
        color: AppTheme.secondary,
        title: context.translate('landing_feature_ai_title'),
        bullets: [
          context.translate('landing_feature_ai_bullet_1'),
          context.translate('landing_feature_ai_bullet_2'),
        ],
      ),
      _FeatureData(
        icon: Icons.query_stats_rounded,
        color: AppTheme.success,
        title: context.translate('landing_feature_tracking_full_title'),
        bullets: [
          context.translate('landing_feature_tracking_bullet_1'),
          context.translate('landing_feature_tracking_bullet_2'),
        ],
      ),
      _FeatureData(
        icon: Icons.groups_rounded,
        color: const Color(0xFFFFC66A),
        title: context.translate('landing_feature_social_title'),
        bullets: [
          context.translate('landing_feature_social_bullet_1'),
          context.translate('landing_feature_social_bullet_2'),
        ],
      ),
      _FeatureData(
        icon: Icons.monitor_weight_rounded,
        color: const Color(0xFF2DD4BF),
        title: context.translate('landing_feature_health_title'),
        bullets: [
          context.translate('landing_feature_health_bullet_1'),
          context.translate('landing_feature_health_bullet_2'),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker: context.translate('landing_features_kicker'),
          title: context.translate('landing_features_title'),
          description: context.translate('landing_features_desc'),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            return GridView.builder(
              itemCount: features.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isNarrow ? 1 : 2,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                mainAxisExtent: isNarrow ? 300 : 292,
              ),
              itemBuilder: (context, index) {
                return _FeatureCard(data: features[index]);
              },
            );
          },
        ),
      ],
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.color,
    required this.title,
    required this.bullets,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> bullets;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});

  final _FeatureData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.2 : 0.55,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: isDark ? 0.18 : 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              for (var i = 0; i < data.bullets.length; i++) ...[
                _BulletLine(text: data.bullets[i], color: data.color),
                if (i != data.bullets.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductValueSection extends StatelessWidget {
  const _ProductValueSection();

  @override
  Widget build(BuildContext context) {
    final values = [
      _ValuePoint(
        icon: Icons.tune_rounded,
        title: context.translate('landing_value_personal_title'),
        description: context.translate('landing_value_personal_desc'),
      ),
      _ValuePoint(
        icon: Icons.trending_up_rounded,
        title: context.translate('landing_value_performance_title'),
        description: context.translate('landing_value_performance_desc'),
      ),
      _ValuePoint(
        icon: Icons.emoji_events_rounded,
        title: context.translate('landing_value_motivation_title'),
        description: context.translate('landing_value_motivation_desc'),
      ),
      _ValuePoint(
        icon: Icons.hub_rounded,
        title: context.translate('landing_value_platform_title'),
        description: context.translate('landing_value_platform_desc'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker: context.translate('landing_value_kicker'),
          title: context.translate('landing_value_title'),
          description: context.translate('landing_value_desc'),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            if (!isWide) {
              return Column(
                children: [
                  for (final value in values) ...[
                    _ValueTile(data: value),
                    if (value != values.last) const SizedBox(height: 14),
                  ],
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 5, child: _ValueStatementCard()),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      for (final value in values) ...[
                        _ValueTile(data: value),
                        if (value != values.last) const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ValueStatementCard extends StatelessWidget {
  const _ValueStatementCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102E34), Color(0xFF151C3E)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_graph_rounded,
            color: AppTheme.success,
            size: 38,
          ),
          const SizedBox(height: 22),
          Text(
            context.translate('landing_value_statement'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniChip(label: context.translate('landing_chip_ai_coach')),
              _MiniChip(label: context.translate('landing_chip_activity')),
              _MiniChip(label: context.translate('landing_chip_health')),
              _MiniChip(label: context.translate('landing_chip_community')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ValuePoint {
  const _ValuePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.data});

  final _ValuePoint data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.18 : 0.45,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: AppTheme.success, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
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

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(
        title: context.translate('landing_step_1_title'),
        description: context.translate('landing_step_1_desc'),
      ),
      _StepData(
        title: context.translate('landing_step_2_title'),
        description: context.translate('landing_step_2_desc'),
      ),
      _StepData(
        title: context.translate('landing_step_3_title'),
        description: context.translate('landing_step_3_desc'),
      ),
      _StepData(
        title: context.translate('landing_step_4_title'),
        description: context.translate('landing_step_4_desc'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker: context.translate('landing_how_kicker'),
          title: context.translate('landing_how_title'),
          description: context.translate('landing_how_desc'),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    Expanded(
                      child: _StepCard(index: i + 1, data: steps[i]),
                    ),
                    if (i != steps.length - 1) const SizedBox(width: 14),
                  ],
                ],
              );
            }

            return Column(
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _StepCard(index: i + 1, data: steps[i]),
                  if (i != steps.length - 1) const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StepData {
  const _StepData({required this.title, required this.description});

  final String title;
  final String description;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.data});

  final int index;
  final _StepData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.18 : 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: secondaryPulseGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.48,
            ),
          ),
        ],
      ),
    );
  }
}

class _TechStackSection extends StatelessWidget {
  const _TechStackSection();

  @override
  Widget build(BuildContext context) {
    final stack = [
      _TechItem(
        icon: Icons.flutter_dash_rounded,
        title: 'Flutter',
        description: context.translate('landing_tech_flutter_desc'),
      ),
      _TechItem(
        icon: Icons.lock_rounded,
        title: 'Supabase Auth',
        description: context.translate('landing_tech_supabase_desc'),
      ),
      _TechItem(
        icon: Icons.storage_rounded,
        title: 'PostgreSQL',
        description: context.translate('landing_tech_postgres_desc'),
      ),
      _TechItem(
        icon: Icons.psychology_rounded,
        title: 'OpenRouter / Gemini',
        description: context.translate('landing_tech_ai_desc'),
      ),
      _TechItem(
        icon: Icons.sync_rounded,
        title: 'Strava API',
        description: context.translate('landing_tech_strava_desc'),
      ),
      _TechItem(
        icon: Icons.cloud_rounded,
        title: 'OpenWeather API',
        description: context.translate('landing_tech_weather_desc'),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            kicker: context.translate('landing_tech_kicker'),
            title: context.translate('landing_tech_title'),
            description: context.translate('landing_tech_desc'),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                itemCount: stack.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: constraints.maxWidth < 520 ? 520 : 360,
                  mainAxisExtent: 124,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemBuilder: (context, index) => _TechTile(item: stack[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TechItem {
  const _TechItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _TechTile extends StatelessWidget {
  const _TechTile({required this.item});

  final _TechItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppTheme.secondary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123C33), Color(0xFF0D2C4A)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 740;
          final text = Column(
            crossAxisAlignment: isWide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                context.translate('landing_cta_title'),
                textAlign: isWide ? TextAlign.start : TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.translate('landing_cta_desc'),
                textAlign: isWide ? TextAlign.start : TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ],
          );

          final button = GradientButton.icon(
            onPressed: onGetStarted,
            width: 190,
            icon: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: Text(context.translate('get_started')),
          );

          if (!isWide) {
            return Column(children: [text, const SizedBox(height: 24), button]);
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final links = [
      context.translate('landing_nav_features'),
      context.translate('landing_chip_ai_coach'),
      context.translate('landing_footer_analytics'),
      context.translate('landing_chip_community'),
    ];
    return Column(
      children: [
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final brand = Column(
              crossAxisAlignment: isWide
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                const RunnyLogo(fontSize: 22),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Text(
                    context.translate('landing_footer_desc'),
                    textAlign: isWide ? TextAlign.start : TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            );
            final footerLinks = Wrap(
              alignment: isWide ? WrapAlignment.end : WrapAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final link in links)
                  Text(
                    link,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
              ],
            );

            if (!isWide) {
              return Column(
                children: [brand, const SizedBox(height: 22), footerLinks],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: brand),
                const SizedBox(width: 24),
                Expanded(child: footerLinks),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Text(
          context.translate('landing_footer_copyright'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.kicker,
    required this.title,
    required this.description,
  });

  final String kicker;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.success,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.18,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(Icons.check_circle_rounded, color: color, size: 16),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
