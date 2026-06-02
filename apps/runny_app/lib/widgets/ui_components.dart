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
    color: Colors.white.withOpacity(0.08),
    borderRadius: borderRadius,
    border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.28),
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
      shadowColor: Colors.black.withOpacity(0.28),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );

ButtonStyle secondaryActionButton() => OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withOpacity(0.18), width: 1.3),
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
    fillColor: Colors.white.withOpacity(0.08),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.18), width: 1.2),
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
