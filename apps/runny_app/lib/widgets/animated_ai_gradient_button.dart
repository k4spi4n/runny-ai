import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CTA nổi dành cho các thao tác HLV AI. Gradient xoay chậm để tạo cảm giác
/// đang hoạt động nhưng vẫn giữ nguyên kích thước, tránh làm giao diện rung.
class AnimatedAiGradientButton extends StatefulWidget {
  const AnimatedAiGradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon = Icons.auto_awesome,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;

  @override
  State<AnimatedAiGradientButton> createState() =>
      _AnimatedAiGradientButtonState();
}

class _AnimatedAiGradientButtonState extends State<AnimatedAiGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return DecoratedBox(
          key: const ValueKey('animated_ai_gradient_surface'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFFFF7A00),
                Color(0xFF7C3AED),
                Color(0xFF0EA5E9),
                Color(0xFF2563EB),
                Color(0xFFFF7A00),
              ],
              transform: GradientRotation(_controller.value * math.pi * 2),
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.34),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D4AFF).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('animated_ai_gradient_button'),
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 9),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
