import 'package:flutter/material.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 6,
    this.onTap,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(borderRadius);
    final content = Container(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surfaceHigh : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class AtmosphericBackground extends StatelessWidget {
  const AtmosphericBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFF1F2937).withValues(alpha: .2)
      ..strokeWidth = .7;
    final major = Paint()
      ..color = AppColors.primary.withValues(alpha: .065)
      ..strokeWidth = .9;
    const step = 24.0;
    for (var x = 0.0; x <= size.width; x += step) {
      final index = (x / step).round();
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        index % 4 == 0 ? major : minor,
      );
    }
    for (var y = 0.0; y <= size.height; y += step) {
      final index = (y / step).round();
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        index % 4 == 0 ? major : minor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
