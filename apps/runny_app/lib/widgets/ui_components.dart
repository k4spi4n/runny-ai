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
        children: [icon, const SizedBox(width: 8), label],
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
  String? suffixText,
}) {
  final theme = Theme.of(context);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffixText,
    prefixIcon: icon != null
        ? Icon(
            icon,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          )
        : null,
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
        Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.15,
              child: Container(
                width: fontSize * 1.4,
                height: fontSize * 1.4,
                decoration: BoxDecoration(
                  gradient: accentPulseGradient,
                  borderRadius: BorderRadius.circular(fontSize * 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFA6B27).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Icon(Icons.bolt_rounded, color: Colors.white, size: fontSize * 1.1),
          ],
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
