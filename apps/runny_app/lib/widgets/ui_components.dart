import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import '../l10n/language_provider.dart';
import '../l10n/app_localizations.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: HoverZoomIcon(
          key: ValueKey(isDark),
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
      onPressed: () => themeProvider.toggleTheme(),
      tooltip: context.translate('theme_mode'),
    );
  }
}

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final currentLocale = languageProvider.locale;

    return PopupMenuButton<Locale>(
      icon: const HoverZoomIcon(icon: Icons.language_rounded),
      tooltip: context.translate('language'),
      onSelected: (locale) => languageProvider.setLocale(locale),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('en'),
          child: Row(
            children: [
              Text('🇺🇸', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Text(context.translate('english')),
              if (currentLocale.languageCode == 'en') ...[
                const Spacer(),
                Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: const Locale('vi'),
          child: Row(
            children: [
              Text('🇻🇳', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Text(context.translate('vietnamese')),
              if (currentLocale.languageCode == 'vi') ...[
                const Spacer(),
                Icon(
                  Icons.check_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Updated Gradients
LinearGradient sportPlatformGradient(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
        ? [
            const Color(0xFF050814),
            const Color(0xFF101233),
            const Color(0xFF1C1452),
          ]
        : [
            const Color(0xFFF8FAFC),
            const Color(0xFFF1F5F9),
            const Color(0xFFE2E8F0),
          ],
  );
}

const accentPulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF85F2B), Color(0xFFFFC66A)],
);

const secondaryPulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3CABFF), Color(0xFF5E5BFF)],
);

BoxDecoration glassDecoration(
  BuildContext context, {
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.7),
    borderRadius: borderRadius,
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.black.withValues(alpha: 0.08),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
        blurRadius: 24,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

Widget glassCard({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
}) {
  return ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: glassDecoration(context, borderRadius: borderRadius),
        child: Material(
          color: Colors.transparent,
          child: Padding(padding: padding, child: child),
        ),
      ),
    ),
  );
}

ButtonStyle primaryActionButton(
  BuildContext context, {
  Color? backgroundColor,
}) => ElevatedButton.styleFrom(
  backgroundColor: backgroundColor ?? const Color(0xFFFA6B27),
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  elevation: 8,
  shadowColor: Colors.black.withValues(alpha: 0.28),
  textStyle: const TextStyle(fontWeight: FontWeight.w700),
);

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final Gradient gradient;
  final double elevation;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 54,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.gradient = accentPulseGradient,
    this.elevation = 8,
  });

  factory GradientButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    double? width,
    double height = 54,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    Gradient gradient = accentPulseGradient,
    double elevation = 8,
  }) {
    return GradientButton(
      key: key,
      onPressed: onPressed,
      width: width,
      height: height,
      borderRadius: borderRadius,
      gradient: gradient,
      elevation: elevation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(child: label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled ? gradient : null,
        color: isEnabled ? null : theme.disabledColor.withValues(alpha: 0.12),
        borderRadius: borderRadius,
        boxShadow: isEnabled && elevation > 0
            ? [
                BoxShadow(
                  color: const Color(0xFFFA6B27).withValues(alpha: 0.35),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation / 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: DefaultTextStyle(
                style:
                    theme.textTheme.labelLarge?.copyWith(
                      color: isEnabled ? Colors.white : theme.disabledColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ) ??
                    const TextStyle(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle secondaryActionButton(BuildContext context) =>
    OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      side: BorderSide(
        color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
        width: 1.3,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

InputDecoration themedInputDecoration(
  BuildContext context,
  String label, {
  String? hint,
  IconData? icon,
  Widget? prefixIcon,
  String? suffixText,
  bool isRequired = false,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    label: isRequired
        ? Text.rich(
            TextSpan(
              text: label,
              children: const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          )
        : null,
    labelText: isRequired ? null : label,
    hintText: hint,
    suffixText: suffixText,
    prefixIcon: prefixIcon ??
        (icon != null
            ? Icon(
                icon,
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              )
            : null),
    filled: true,
    fillColor: theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: theme.dividerColor.withValues(alpha: 0.18),
        width: 1.2,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
    ),
    labelStyle: TextStyle(
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.4),
    ),
  );
}

/// Bộ chọn giới tính dùng chung cho Onboarding & trang Cá nhân. Lưu giá trị
/// chuẩn 'male' | 'female' | 'other'; [value] có thể null khi chưa chọn.
class GenderSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String> onChanged;

  const GenderSelector({super.key, required this.value, required this.onChanged});

  static const List<(String, IconData, String)> _options = [
    ('male', Icons.male, 'gender_male'),
    ('female', Icons.female, 'gender_female'),
    ('other', Icons.transgender, 'gender_other'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.translate('gender'),
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (key, icon, labelKey) in _options) ...[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onChanged(key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: value == key
                          ? colorScheme.primary.withValues(alpha: 0.15)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: value == key
                            ? colorScheme.primary
                            : theme.dividerColor.withValues(alpha: 0.18),
                        width: value == key ? 1.6 : 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          icon,
                          size: 22,
                          color: value == key
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.translate(labelKey),
                          style: TextStyle(
                            color: value == key
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: value == key
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (key != _options.last.$1) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

Widget badgeLabel(BuildContext context, String text, {Color? background}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color:
          background ??
          (isDark ? const Color(0xFF262F57) : const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class ProBadge extends StatelessWidget {
  final double fontSize;
  final double iconSize;

  const ProBadge({
    super.key,
    this.fontSize = 10,
    this.iconSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // Pure Gold
            Color(0xFFFFA500), // Orange
            Color(0xFFFF4500), // OrangeRed (creates rich golden fire gradient)
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFF8DC).withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: iconSize,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              height: 1.1,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RunnyLogo extends StatelessWidget {
  final double fontSize;
  final bool showText;
  final Color? textColor;

  const RunnyLogo({
    super.key,
    this.fontSize = 24,
    this.showText = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveTextColor =
        textColor ?? (isDark ? Colors.white : Colors.black);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(fontSize * 0.35),
          child: Image.asset(
            'assets/images/runny-ai-logo.png',
            width: fontSize * 1.4,
            height: fontSize * 1.4,
            fit: BoxFit.cover,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RUNNY',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: effectiveTextColor,
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                  Text(
                    'AI',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w300,
                      color: effectiveTextColor.withValues(alpha: 0.7),
                      letterSpacing: 0,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Container(
                height: 2,
                width: fontSize * 1.5,
                decoration: BoxDecoration(
                  gradient: accentPulseGradient,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class HoverZoomIcon extends StatefulWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const HoverZoomIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 24,
  });

  @override
  State<HoverZoomIcon> createState() => _HoverZoomIconState();
}

class _HoverZoomIconState extends State<HoverZoomIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );
  }
}

class HoverSync extends ValueNotifier<bool> {
  HoverSync() : super(false);
}

class HoverSyncWidget extends StatelessWidget {
  final HoverSync sync;
  final Widget Function(BuildContext context, bool isHovered) builder;

  const HoverSyncWidget({super.key, required this.sync, required this.builder});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => sync.value = true,
      onExit: (_) => sync.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: sync,
        builder: (context, isHovered, _) => builder(context, isHovered),
      ),
    );
  }
}

/// Chiều rộng tối đa thoải mái cho nội dung trên màn hình lớn (web/desktop).
const double kContentMaxWidth = 1100;

/// Giới hạn chiều rộng nội dung và canh giữa trên màn hình lớn, trong khi vẫn
/// để vùng cuộn/nền chiếm toàn bộ chiều ngang. Bọc phần con của
/// `SingleChildScrollView`/`ListView` để tránh nội dung bị kéo giãn trên web.
///
/// Theo workflow "Optimizing for Large Screens" của Flutter responsive layout.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Văn bản 1 dòng: nếu nội dung dài hơn vùng chứa thì tự cuộn ngang liên tục
/// một chiều (vô hạn, kiểu marquee) để người dùng đọc hết mà không bị cắt cụt.
/// Nếu vừa đủ thì hiển thị tĩnh bình thường.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  /// Tốc độ cuộn (pixel mỗi giây).
  final double velocity;

  /// Khoảng trống giữa hai lần lặp của văn bản khi cuộn.
  final double gap;

  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.velocity = 35,
    this.gap = 48,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Khởi động (hoặc cập nhật) vòng lặp cuộn vô hạn với [duration] cho một chu
  /// kỳ. Lên lịch sau frame để không đổi trạng thái animation trong lúc build.
  void _ensureRunning(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.isAnimating && _controller.duration == duration) return;
      _controller
        ..duration = duration
        ..repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: effectiveStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        final textWidth = painter.size.width;
        final maxWidth = constraints.maxWidth;

        // Vừa vặn (hoặc chưa đo được) → hiển thị tĩnh, dừng animation.
        if (!textWidth.isFinite || textWidth <= maxWidth + 0.5) {
          if (_controller.isAnimating) _controller.stop();
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          );
        }

        final scrollDistance = textWidth + widget.gap;
        _ensureRunning(
          Duration(
            milliseconds: (scrollDistance / widget.velocity * 1000).round(),
          ),
        );

        final label = Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
        );
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(-_controller.value * scrollDistance, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    label,
                    SizedBox(width: widget.gap),
                    // Bản sao thứ hai để khi bản đầu cuộn hết thì tiếp nối liền
                    // mạch, tạo hiệu ứng cuộn vô hạn không giật.
                    label,
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
