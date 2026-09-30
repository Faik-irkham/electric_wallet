import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../wallet_controller.dart';
import '../widgets/energy_particles.dart';
import '../widgets/wallet_3d.dart';

/// Animasi layar penuh saat charger dicolok, mirip animasi charging iOS.
class ChargingOverlay extends StatefulWidget {
  const ChargingOverlay({super.key, required this.controller});

  final WalletController controller;

  static Future<void> show(BuildContext context, WalletController controller) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => ChargingOverlay(controller: controller),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 1.08, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<ChargingOverlay> createState() => _ChargingOverlayState();
}

class _ChargingOverlayState extends State<ChargingOverlay> {
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 4200), _close);
  }

  void _close() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return GestureDetector(
      onTap: _close,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            color: Colors.black.withValues(alpha: 0.78),
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => Stack(
                children: [
                  Positioned.fill(child: EnergyParticles(active: true, count: 46)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wallet3D(
                          fill: c.fill,
                          charging: true,
                          size: 290,
                          interactive: false,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded,
                                color: AppColors.lime, size: 22),
                            const SizedBox(width: 6),
                            Text(
                              'Charger terhubung',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: c.balance),
                          duration: const Duration(milliseconds: 600),
                          builder: (_, v, _) => ShaderMask(
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Colors.white, AppColors.lime],
                            ).createShader(r),
                            child: Text(
                              formatRupiah(v),
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.sessionTotal > 0
                              ? 'Saldo sedang diisi • +${formatRupiah(c.sessionTotal)}'
                              : 'Saldo sedang diisi…',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
