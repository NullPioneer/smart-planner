import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smart_reminder/core/theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
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
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final innerRadius = BorderRadius.circular(
      (borderRadius - 1).clamp(0, borderRadius).toDouble(),
    );
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .68 : .24),
            blurRadius: isDark ? 36 : 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? .16 : .10,
            ),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.secondary.withValues(alpha: .52),
                        theme.colorScheme.primary.withValues(alpha: .30),
                        theme.colorScheme.outline.withValues(alpha: .22),
                      ]
                    : [
                        theme.colorScheme.primary.withValues(alpha: .58),
                        theme.colorScheme.secondary.withValues(alpha: .42),
                        theme.colorScheme.outline.withValues(alpha: .48),
                      ],
                stops: const [0, .42, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: innerRadius,
                  gradient:
                      gradient ??
                      LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                AppColors.surfaceHighest.withValues(alpha: .94),
                                AppColors.surfaceHigh.withValues(alpha: .96),
                                AppColors.surface.withValues(alpha: .96),
                              ]
                            : [
                                theme.colorScheme.surface.withValues(
                                  alpha: .97,
                                ),
                                AppColors.lightSurfaceHigh.withValues(
                                  alpha: .94,
                                ),
                                theme.colorScheme.secondaryContainer.withValues(
                                  alpha: .90,
                                ),
                              ],
                      ),
                ),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: isDark ? AppColors.background : AppColors.lightBackground,
          ),
        ),
        Positioned(
          left: -140,
          top: -170,
          child: _Glow(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? .19 : .15,
            ),
          ),
        ),
        Positioned(
          right: -180,
          bottom: -220,
          child: _Glow(
            color: theme.colorScheme.secondary.withValues(
              alpha: isDark ? .14 : .12,
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _RibbonPainter(isDark))),
        Positioned.fill(child: CustomPaint(painter: _GridPainter(isDark))),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 430,
      height: 430,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 50)],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.isDark);

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = (isDark ? AppColors.secondary : AppColors.lightOutline)
          .withValues(alpha: isDark ? .09 : .16)
      ..strokeWidth = .7;
    final major = Paint()
      ..color = (isDark ? AppColors.primary : AppColors.lightPrimary)
          .withValues(alpha: isDark ? .18 : .20)
      ..strokeWidth = 1;
    const step = 32.0;
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
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter(this.isDark);

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final upper = Path()
      ..moveTo(size.width * .20, -50)
      ..cubicTo(
        size.width * .96,
        size.height * .02,
        size.width * .42,
        size.height * .32,
        size.width * 1.08,
        size.height * .42,
      );
    final lower = Path()
      ..moveTo(-70, size.height * .72)
      ..cubicTo(
        size.width * .42,
        size.height * .48,
        size.width * .58,
        size.height * 1.06,
        size.width * 1.12,
        size.height * .82,
      );

    _drawRibbon(canvas, upper, 84);
    _drawRibbon(canvas, lower, 104);
  }

  void _drawRibbon(Canvas canvas, Path path, double width) {
    final body = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..color = (isDark ? AppColors.primary : AppColors.lightPrimary)
          .withValues(alpha: isDark ? .12 : .085)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = (isDark ? AppColors.secondary : AppColors.lightSecondary)
          .withValues(alpha: isDark ? .30 : .22);
    canvas.drawPath(path, body);
    canvas.drawPath(path, rim);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
