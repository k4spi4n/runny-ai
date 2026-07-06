import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_components.dart';
import 'login_page.dart';

Widget Function(Color color, double size) _materialIcon(IconData icon) {
  return (color, size) => Icon(icon, color: color, size: size);
}

Widget _hugeChatBotIcon(Color color, double size) {
  return HugeIcon(
    icon: HugeIcons.strokeRoundedChatBot,
    color: color,
    size: size,
  );
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  void _goToAuth(BuildContext context, {bool signUp = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginPage(initialIsSignUp: signUp)),
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
              _LandingNavbar(onLogin: () => _goToAuth(context)),
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
                        ),
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
  const _LandingNavbar({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  if (!isCompact) ...[
                    OutlinedButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: Text(context.translate('landing_login_signup')),
                      style: secondaryActionButton(context).copyWith(
                        foregroundColor: const WidgetStatePropertyAll(
                          Colors.white,
                        ),
                        side: WidgetStatePropertyAll(
                          BorderSide(
                            color: Colors.white.withValues(alpha: 0.36),
                            width: 1.3,
                          ),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                      ),
                    ),
                  ] else
                    IconButton(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login_rounded),
                      color: Colors.white,
                      tooltip: context.translate('landing_login_signup'),
                    ),
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

class _SectionBand extends StatelessWidget {
  const _SectionBand({
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
  const _HeroSection({required this.onGetStarted});

  final VoidCallback onGetStarted;

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
            Text(
              'Runny AI',
              textAlign: isWide ? TextAlign.start : TextAlign.center,
              style: headlineStyle,
            ),
            const SizedBox(height: 14),
            _FixedGradientText(
              text: context.translate('landing_slogan'),
              textAlign: isWide ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
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
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.translate('landing_cta_support'),
              textAlign: isWide ? TextAlign.start : TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
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

class _FixedGradientText extends StatelessWidget {
  final String text;
  final TextAlign textAlign;
  final TextStyle? style;

  const _FixedGradientText({
    required this.text,
    required this.textAlign,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFFC66A), Color(0xFFFFC66A), Color(0xFFF85F2B)],
          stops: [0, 0.75, 1],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: textAlign,
        style: style?.copyWith(color: Colors.white),
      ),
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
  List<List<_AtomicFeatureData>>? _rows;
  String? _rowLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    if (_rows != null && _rowLocale == locale) return;

    final features = _atomicFeatures(context).toList()..shuffle(Random());
    final rows = <List<_AtomicFeatureData>>[[], [], []];
    for (var i = 0; i < features.length; i++) {
      rows[i % rows.length].add(features[i]);
    }

    _rowLocale = locale;
    _rows = rows;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? _balancedAtomicFeatureRows(context);

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
  static const double _chipHorizontalPadding = 24;
  static const double _iconWidth = 18;
  static const double _iconGap = 8;
  static const double _borderPadding = 3;

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
    final textScaler = MediaQuery.textScalerOf(context);
    final chipWidths = [
      for (final feature in features)
        _chipWidthFor(feature.label, textStyle, textDirection, textScaler),
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
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    return (painter.width +
            _chipHorizontalPadding +
            _iconWidth +
            _iconGap +
            _borderPadding)
        .ceilToDouble()
        .clamp(_chipMinWidth, double.infinity);
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
          mainAxisSize: MainAxisSize.min,
          children: [
            feature.icon(feature.color, 18),
            const SizedBox(width: 8),
            Text(
              feature.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: _AtomicFeatureRow._chipTextStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AtomicFeatureData {
  final Widget Function(Color color, double size) icon;
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

List<List<_AtomicFeatureData>> _balancedAtomicFeatureRows(
  BuildContext context,
) {
  final features = _atomicFeatures(context);
  final rows = <List<_AtomicFeatureData>>[[], [], []];
  for (var i = 0; i < features.length; i++) {
    rows[i % rows.length].add(features[i]);
  }
  return rows;
}

List<_AtomicFeatureData> _atomicFeatures(BuildContext context) {
  const orange = Color(0xFFFF8E53);
  const green = Color(0xFF4ADE80);
  const blue = Color(0xFF3CABFF);
  const yellow = Color(0xFFFFC66A);

  return [
    _AtomicFeatureData(
      icon: _hugeChatBotIcon,
      label: _landingFeatureLabel(
        context,
        vi: 'Chat với HLV AI',
        en: 'Chat with AI coach',
      ),
      color: orange,
      isAi: true,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.auto_awesome_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'AI tạo giáo án cá nhân',
        en: 'AI builds personal plans',
      ),
      color: green,
      isAi: true,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.tune_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'AI tinh chỉnh lịch tập',
        en: 'AI tunes training plans',
      ),
      color: blue,
      isAi: true,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.local_fire_department_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Gợi ý khởi động theo buổi',
        en: 'Workout-specific warmups',
      ),
      color: yellow,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.route_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Lịch tập hôm nay',
        en: "Today's workout schedule",
      ),
      color: green,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.history_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Lịch sử giáo án',
        en: 'Training plan history',
      ),
      color: blue,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.upload_file_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Nhập file GPX/FIT/TCX',
        en: 'Import GPX/FIT/TCX files',
      ),
      color: blue,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.edit_note_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Ghi buổi chạy thủ công',
        en: 'Manual run logging',
      ),
      color: yellow,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.link_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Gắn hoạt động vào buổi tập',
        en: 'Link runs to workouts',
      ),
      color: green,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.speed_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Biểu đồ pace theo thời gian',
        en: 'Pace chart over time',
      ),
      color: orange,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.monitor_heart_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Theo dõi vùng nhịp tim',
        en: 'Heart-rate zone tracking',
      ),
      color: green,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.landscape_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Phân tích độ cao tích lũy',
        en: 'Elevation gain analysis',
      ),
      color: blue,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.cloud_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Thời tiết & chất lượng khí',
        en: 'Weather and air quality',
      ),
      color: yellow,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.restaurant_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Nhật ký dinh dưỡng runner',
        en: 'Runner nutrition log',
      ),
      color: green,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.camera_alt_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'AI nhận diện món ăn từ ảnh',
        en: 'AI food photo recognition',
      ),
      color: orange,
      isAi: true,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.lightbulb_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'AI gợi ý thực đơn',
        en: 'AI meal suggestions',
      ),
      color: yellow,
      isAi: true,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.monitor_weight_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Theo dõi cân nặng & mục tiêu',
        en: 'Weight and goal tracking',
      ),
      color: blue,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.groups_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Cộng đồng runner',
        en: 'Runner community',
      ),
      color: green,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.leaderboard_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Bảng xếp hạng cộng đồng',
        en: 'Community leaderboard',
      ),
      color: orange,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.emoji_events_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Huy hiệu thành tích chạy',
        en: 'Running achievement badges',
      ),
      color: yellow,
    ),
    _AtomicFeatureData(
      icon: _materialIcon(Icons.handshake_rounded),
      label: _landingFeatureLabel(
        context,
        vi: 'Ghép bạn chạy cùng pace',
        en: 'Match partners by pace',
      ),
      color: blue,
    ),
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
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedChatBot,
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
