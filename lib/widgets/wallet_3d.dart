import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Dompet 3D yang dibangun dari lapisan-lapisan bertumpuk di sumbu Z
/// dengan proyeksi perspektif. Bisa diputar dengan swipe horizontal.
///
/// Uang & kartu di dalamnya naik keluar dompet sesuai [fill]
/// (makin banyak saldo, makin penuh dompetnya).
class Wallet3D extends StatefulWidget {
  const Wallet3D({
    super.key,
    required this.fill,
    required this.charging,
    this.size = 260,
    this.interactive = true,
  });

  final double fill;
  final bool charging;
  final double size;
  final bool interactive;

  @override
  State<Wallet3D> createState() => _Wallet3DState();
}

class _Wallet3DState extends State<Wallet3D> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  late final AnimationController _release = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addListener(() {
      setState(() {
        _dragY = ui.lerpDouble(
          _releaseFrom,
          0,
          Curves.elasticOut.transform(_release.value),
        )!;
      });
    });

  double _dragY = 0;
  double _releaseFrom = 0;

  @override
  void dispose() {
    _idle.dispose();
    _release.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * 0.66;

    Widget content = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.fill.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, fill, _) => AnimatedBuilder(
        animation: _idle,
        builder: (context, _) {
          final t = _idle.value * 2 * math.pi;
          final ry = math.sin(t) * 0.38 + _dragY;
          final rx = -0.16 + math.cos(t * 2) * 0.05;
          final floatY = math.sin(t * 2) * 7;

          return SizedBox(
            width: w * 1.35,
            height: h * 2.0,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _GroundShadow(
                  width: w,
                  top: h * 1.68,
                  lift: floatY,
                  charging: widget.charging,
                ),
                Transform.translate(
                  offset: Offset(0, h * 0.16 + floatY),
                  child: _WalletBody(
                    w: w,
                    h: h,
                    rx: rx,
                    ry: ry,
                    fill: fill,
                    charging: widget.charging,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (!widget.interactive) return content;

    return GestureDetector(
      onHorizontalDragStart: (_) => _release.stop(),
      onHorizontalDragUpdate: (d) => setState(() {
        _dragY = (_dragY + d.delta.dx * 0.01).clamp(-0.75, 0.75);
      }),
      onHorizontalDragEnd: (_) {
        _releaseFrom = _dragY;
        _release.forward(from: 0);
      },
      child: content,
    );
  }
}

class _WalletBody extends StatelessWidget {
  const _WalletBody({
    required this.w,
    required this.h,
    required this.rx,
    required this.ry,
    required this.fill,
    required this.charging,
  });

  final double w, h, rx, ry, fill;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final radius = w * 0.1;
    final depth = w * 0.11;
    final base = Matrix4.identity()
      ..setEntry(3, 2, 0.0011)
      ..rotateX(rx)
      ..rotateY(ry);

    Widget layer(double z, Widget child) => Transform(
          alignment: Alignment.center,
          transform: base.clone()..translateByDouble(0, 0, z, 1),
          child: SizedBox(width: w, height: h, child: child),
        );

    Widget slice(double z) {
      final k = (z / depth).clamp(0.0, 1.0);
      return layer(
        z,
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF4630C8), const Color(0xFF1A1052), k)!,
                Color.lerp(const Color(0xFF24177A), const Color(0xFF0B0730), k)!,
              ],
            ),
          ),
        ),
      );
    }

    const step = 2.0;
    final children = <Widget>[
      // Sisi belakang → tengah.
      for (double z = depth; z > depth * 0.55; z -= step) slice(z),
      // Isi dompet: kartu & uang, di tengah ketebalan.
      layer(depth * 0.5, _Contents(w: w, h: h, fill: fill)),
      // Tengah → depan.
      for (double z = depth * 0.45; z > 0.5; z -= step) slice(z),
      // Muka depan.
      layer(0, _FrontFace(w: w, h: h, radius: radius, ry: ry, charging: charging)),
      // Tali pengunci (menonjol ke depan).
      for (final z in [-1.2, -2.6, -4.0]) layer(z, _Strap(w: w, h: h, edge: true)),
      layer(-5, _Strap(w: w, h: h, ry: ry)),
      // Kancing magnet dengan logo petir.
      for (final z in [-6.2, -7.6]) layer(z, _Clasp(w: w, h: h, edge: true)),
      layer(-9, _Clasp(w: w, h: h, charging: charging, ry: ry)),
    ];

    return Stack(clipBehavior: Clip.none, children: children);
  }
}

class _GroundShadow extends StatelessWidget {
  const _GroundShadow({
    required this.width,
    required this.top,
    required this.lift,
    required this.charging,
  });

  final double width, top, lift;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final scale = 1 - lift * 0.012;
    return Positioned(
      top: top,
      child: Transform.scale(
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: width * 0.72,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: charging
                    ? AppColors.lime.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.8),
                blurRadius: 28,
                spreadRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contents extends StatelessWidget {
  const _Contents({required this.w, required this.h, required this.fill});

  final double w, h, fill;

  @override
  Widget build(BuildContext context) {
    double rise(double min, double max, [double delay = 0]) {
      final f = ((fill - delay) / (1 - delay)).clamp(0.0, 1.0);
      return min + (max - min) * Curves.easeOut.transform(f);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Kartu biru (paling belakang).
        Positioned(
          left: w * 0.08,
          top: -rise(2, h * 0.34),
          child: Transform.rotate(
            angle: -0.07,
            child: _MiniCard(
              width: w * 0.5,
              height: h * 0.8,
              colors: const [AppColors.cyan, Color(0xFF1466FF)],
            ),
          ),
        ),
        // Tumpukan uang.
        for (var i = 0; i < 3; i++)
          Positioned(
            left: w * (0.34 + i * 0.05),
            top: -rise(0, h * (0.5 - i * 0.07), 0.08 + i * 0.1),
            child: Transform.rotate(
              angle: 0.05 - i * 0.06,
              child: _Bill(width: w * 0.46, height: h * 0.72),
            ),
          ),
        // Kartu pink.
        Positioned(
          left: w * 0.56,
          top: -rise(0, h * 0.26, 0.2),
          child: Transform.rotate(
            angle: 0.1,
            child: _MiniCard(
              width: w * 0.36,
              height: h * 0.72,
              colors: const [AppColors.pink, AppColors.violet],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.width,
    required this.height,
    required this.colors,
  });

  final double width, height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.08),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.08),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.topLeft,
      child: Container(
        width: width * 0.2,
        height: width * 0.15,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE08A), Color(0xFFC9A13B)],
          ),
        ),
      ),
    );
  }
}

class _Bill extends StatelessWidget {
  const _Bill({required this.width, required this.height});

  final double width, height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD7FF7A), AppColors.lime, Color(0xFF6BC21A)],
        ),
        border: Border.all(color: const Color(0xFF4E8F12), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.05),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF3F7A0C).withValues(alpha: 0.6),
            ),
          ),
          alignment: const Alignment(0, -0.55),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(Icons.bolt_rounded,
                  size: width * 0.14, color: const Color(0xFF2F5E08)),
              Text(
                'Rp',
                style: TextStyle(
                  fontSize: width * 0.13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2F5E08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  const _FrontFace({
    required this.w,
    required this.h,
    required this.radius,
    required this.ry,
    required this.charging,
  });

  final double w, h, radius, ry;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A70FF), Color(0xFF5236E6), AppColors.violetDeep],
        ),
        boxShadow: [
          if (charging)
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: -2,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Jahitan.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(w * 0.028),
              child: CustomPaint(
                painter: _StitchPainter(radius: radius * 0.75),
              ),
            ),
          ),
          // Kartu yang mengintip dari kantong.
          Positioned(
            left: w * 0.11,
            top: h * 0.11,
            width: w * 0.36,
            height: h * 0.14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFE0A93B)],
                ),
              ),
            ),
          ),
          // Kantong kartu.
          Positioned(
            left: w * 0.07,
            top: h * 0.19,
            width: w * 0.46,
            height: h * 0.4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius * 0.6),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF6448F5), Color(0xFF4127C4)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: CustomPaint(
                painter: _StitchPainter(radius: radius * 0.45),
              ),
            ),
          ),
          // Kilau yang bergeser mengikuti rotasi.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment(-1.2 - ry * 2.2, -1),
                  end: Alignment(0.6 - ry * 2.2, 0.8),
                  colors: [
                    Colors.white.withValues(alpha: 0.28),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                  stops: const [0, 0.45, 0.8, 1],
                ),
              ),
            ),
          ),
          // Logo brand timbul.
          Positioned(
            left: w * 0.08,
            bottom: h * 0.13,
            child: Text(
              appName,
              style: TextStyle(
                fontSize: w * 0.065,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white.withValues(alpha: 0.4),
                shadows: [
                  const Shadow(color: Colors.black45, offset: Offset(0, 1.2)),
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    offset: const Offset(0, -0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Strap extends StatelessWidget {
  const _Strap({required this.w, required this.h, this.edge = false, this.ry = 0});

  final double w, h, ry;
  final bool edge;

  @override
  Widget build(BuildContext context) {
    final r = Radius.circular(h * 0.17);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -w * 0.035,
          top: h * 0.28,
          width: w * 0.42,
          height: h * 0.34,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: r,
                bottomLeft: r,
                topRight: const Radius.circular(8),
                bottomRight: const Radius.circular(8),
              ),
              color: edge ? const Color(0xFF1B1160) : null,
              gradient: edge
                  ? null
                  : LinearGradient(
                      begin: Alignment(-1 - ry, -1),
                      end: Alignment(1 - ry, 1),
                      colors: const [Color(0xFF6E55FF), Color(0xFF3A26B8)],
                    ),
              boxShadow: edge
                  ? const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(-3, 6),
                      ),
                    ]
                  : null,
            ),
            child: edge
                ? null
                : Padding(
                    padding: const EdgeInsets.all(5),
                    child: CustomPaint(
                      painter: _StitchPainter(radius: h * 0.13),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Clasp extends StatelessWidget {
  const _Clasp({
    required this.w,
    required this.h,
    this.edge = false,
    this.charging = false,
    this.ry = 0,
  });

  final double w, h, ry;
  final bool edge, charging;

  @override
  Widget build(BuildContext context) {
    final d = h * 0.25;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: w * 0.075,
          top: h * 0.45 - d / 2,
          width: d,
          height: d,
          child: edge
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6D7390),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment(-1 - ry * 2, -1),
                      end: Alignment(1 - ry * 2, 1),
                      colors: const [
                        Color(0xFFFFFFFF),
                        Color(0xFFB9C0D8),
                        Color(0xFF7C84A3),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.all(d * 0.12),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0822),
                      boxShadow: [
                        if (charging)
                          BoxShadow(
                            color: AppColors.lime.withValues(alpha: 0.8),
                            blurRadius: 14,
                          ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: d * 0.55,
                      color: charging ? AppColors.lime : Colors.white54,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StitchPainter extends CustomPainter {
  _StitchPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StitchPainter old) => old.radius != radius;
}
