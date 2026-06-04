import 'dart:ui';

import 'package:flutter/material.dart';

const sportPlatformGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFF050814),
    Color(0xFF101233),
    Color(0xFF1C1452),
  ],
);

const accentPulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF85F2B),
    Color(0xFFFFC66A),
  ],
);

const secondaryPulseGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF3CABFF),
    Color(0xFF5E5BFF),
  ],
);

BoxDecoration glassDecoration({BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24))}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: borderRadius,
    border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 24,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

Widget glassCard({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(24),
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
}) {
  return ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: glassDecoration(borderRadius: borderRadius),
        child: child,
      ),
    ),
  );
}

ButtonStyle primaryActionButton({Color? backgroundColor}) => ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? const Color(0xFFFA6B27),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );

ButtonStyle secondaryActionButton() => OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );

InputDecoration themedInputDecoration(String label,
    {String? hint, IconData? icon, String? suffixText}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffixText,
    prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.08),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFFA6B27), width: 1.6),
    ),
    labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
    hintStyle: const TextStyle(color: Colors.white38),
  );
}

Widget badgeLabel(String text, {Color background = const Color(0xFF262F57)}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
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
            Icon(
              Icons.bolt_rounded,
              color: Colors.white,
              size: fontSize * 1.1,
            ),
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
                      color: textColor ?? Colors.white,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  Text(
                    'AI',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w300,
                      color: (textColor ?? Colors.white).withValues(alpha: 0.7),
                      letterSpacing: -0.5,
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
