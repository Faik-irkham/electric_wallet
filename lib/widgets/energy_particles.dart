import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Percikan listrik yang naik di sekitar dompet saat sedang dicas.
class EnergyParticles extends StatefulWidget {
  const EnergyParticles({super.key, required this.active, this.count = 28});

  final bool active;
  final int count;

  @override
  State<EnergyParticles> createState() => _EnergyParticlesState();
}

class _EnergyParticlesState extends State<EnergyParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.active ? 1 : 0,
        duration: const Duration(milliseconds: 600),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _ParticlePainter(_c.value, widget.count),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.t, this.count);

  final double t;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    for (var i = 0; i < count; i++) {
      final seed = rnd.nextDouble();
      final speed = 0.6 + rnd.nextDouble() * 0.9;
      final xBase = rnd.nextDouble();
      final radius = 1.0 + rnd.nextDouble() * 2.4;
      final color = i % 3 == 0 ? AppColors.cyan : AppColors.lime;

      final p = (t * speed + seed) % 1.0;
      final x = size.width * (0.1 + xBase * 0.8) +
          math.sin((p * 4 + seed * 10) * math.pi) * 14;
      final y = size.height * (0.95 - p * 0.9);
      final alpha = math.sin(p * math.pi).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x, y),
        radius * 3,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );

      // Beberapa partikel jadi kilatan zig-zag kecil.
      if (i % 7 == 0 && alpha > 0.6) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 5, y + 6)
          ..lineTo(x - 2, y + 9)
          ..lineTo(x + 4, y + 16);
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}
