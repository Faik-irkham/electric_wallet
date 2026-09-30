import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../wallet_controller.dart';
import '../widgets/energy_particles.dart';
import '../widgets/wallet_3d.dart';
import 'charging_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final WalletController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WalletController get c => widget.controller;

  StreamSubscription<double>? _gainSub;
  StreamSubscription<double>? _doneSub;
  final List<_Gain> _gains = [];
  int _gainId = 0;
  bool _wasCharging = false;
  bool _overlayOpen = false;
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onWalletChanged);
    _gainSub = c.gains.stream.listen((amount) {
      if (!mounted || _overlayOpen) return;
      setState(() {
        if (_gains.length > 5) _gains.removeAt(0);
        _gains.add(_Gain(_gainId++, amount));
      });
    });
    _doneSub = c.topUpCompleted.stream.listen(_showTopUpSuccess);
  }

  void _onWalletChanged() {
    final charging = c.charging;
    if (charging && !_wasCharging && c.ready && !_overlayOpen && mounted) {
      _overlayOpen = true;
      HapticFeedback.heavyImpact();
      ChargingOverlay.show(context, c).then((_) => _overlayOpen = false);
    }
    _wasCharging = charging;
  }

  void _showTopUpSuccess(double amount) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.bg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Top Up Berhasil',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${formatRupiah(amount)} telah masuk ke saldo $appName',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  void dispose() {
    c.removeListener(_onWalletChanged);
    _gainSub?.cancel();
    _doneSub?.cancel();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final walletSize = math.min(MediaQuery.sizeOf(context).width * 0.6, 250.0);

    return Scaffold(
      extendBody: true,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Stack(
          children: [
            Positioned.fill(child: _AmbientBackground(charging: c.charging)),
            SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                children: [
                  _Header(
                    onBell: () => _toast('Belum ada notifikasi baru'),
                    // Tahan avatar untuk reset saldo (take ulang konten).
                    onReset: () {
                      HapticFeedback.heavyImpact();
                      c.resetDemo();
                    },
                  ),
                  SizedBox(
                    height: walletSize * 0.66 * 1.85,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: EnergyParticles(active: c.charging),
                        ),
                        Wallet3D(
                          fill: c.fill,
                          charging: c.charging,
                          size: walletSize,
                        ),
                        for (final g in _gains)
                          _FloatingGain(
                            key: ValueKey(g.id),
                            gain: g,
                            onDone: () => setState(() => _gains.remove(g)),
                          ),
                      ],
                    ),
                  ),
                  _BalanceCard(
                    controller: c,
                    hidden: _hideBalance,
                    onToggleHidden: () =>
                        setState(() => _hideBalance = !_hideBalance),
                    // Pemicu tersembunyi: tahan kartu saldo untuk
                    // simulasi charging tanpa charger sungguhan.
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      c.toggleSimulation();
                    },
                    onAction: (label) => _toast(switch (label) {
                      'Isi Saldo' => 'Pilih metode isi saldo',
                      'Transfer' => 'Pilih kontak tujuan transfer',
                      'Tarik Tunai' => 'Tarik tunai di minimarket terdekat',
                      _ => 'Membuka riwayat transaksi',
                    }),
                  ),
                  const SizedBox(height: 20),
                  _ServiceGrid(onTap: (label) => _toast('Membuka $label')),
                  const SizedBox(height: 20),
                  const _PromoBanner(),
                  const SizedBox(height: 26),
                  _TransactionList(controller: c),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 16),
                child: _BottomNav(
                  glow: c.charging,
                  onPay: () => _toast('Arahkan kamera ke kode QRIS'),
                  onOther: () => _toast('Halaman ini segera hadir'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Background ─────────────────────────

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground({required this.charging});

  final bool charging;

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          return Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
              _blob(
                Alignment(-0.9 + math.sin(t) * 0.2, -0.85 + math.cos(t) * 0.1),
                AppColors.violet.withValues(alpha: 0.45),
                420,
              ),
              _blob(
                Alignment(0.9 + math.cos(t) * 0.15, -0.35 + math.sin(t) * 0.1),
                (widget.charging ? AppColors.lime : AppColors.cyan)
                    .withValues(alpha: widget.charging ? 0.28 : 0.18),
                340,
              ),
              _blob(
                Alignment(-0.6, 0.6 + math.sin(t * 2) * 0.05),
                AppColors.pink.withValues(alpha: 0.10),
                360,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _blob(Alignment a, Color color, double size) {
    return Align(
      alignment: a,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

// ───────────────────────── Glass card ─────────────────────────

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            border: Border.all(color: AppColors.stroke),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onBell, required this.onReset});

  final VoidCallback onBell;
  final VoidCallback onReset;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onLongPress: onReset,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.lime, AppColors.cyan],
              ),
            ),
            child: Text(
              userName[0],
              style: const TextStyle(
                color: AppColors.bg,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                userName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onBell,
          child: _Glass(
            padding: const EdgeInsets.all(11),
            radius: 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, size: 22),
                Positioned(
                  right: 1,
                  top: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.pink,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Floating +Rp ─────────────────────────

class _Gain {
  _Gain(this.id, this.amount) : dx = (math.Random().nextDouble() - 0.5) * 160;

  final int id;
  final double amount;
  final double dx;
}

class _FloatingGain extends StatefulWidget {
  const _FloatingGain({super.key, required this.gain, required this.onDone});

  final _Gain gain;
  final VoidCallback onDone;

  @override
  State<_FloatingGain> createState() => _FloatingGainState();
}

class _FloatingGainState extends State<_FloatingGain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        final opacity = _c.value < 0.7 ? 1.0 : (1 - (_c.value - 0.7) / 0.3);
        return Transform.translate(
          offset: Offset(widget.gain.dx, 20 - v * 130),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.7 + v * 0.3, child: child),
          ),
        );
      },
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.lime.withValues(alpha: 0.6),
                blurRadius: 16,
              ),
            ],
          ),
          child: Text(
            '+${formatRupiah(widget.gain.amount)}',
            style: const TextStyle(
              color: AppColors.bg,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Balance card ─────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.controller,
    required this.hidden,
    required this.onToggleHidden,
    required this.onLongPress,
    required this.onAction,
  });

  final WalletController controller;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onLongPress;
  final ValueChanged<String> onAction;

  static const _actions = [
    (Icons.add_rounded, 'Isi Saldo'),
    (Icons.north_east_rounded, 'Transfer'),
    (Icons.south_west_rounded, 'Tarik Tunai'),
    (Icons.receipt_long_rounded, 'Riwayat'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6F55FF), Color(0xFF4A2FD8), Color(0xFF26187A)],
          ),
          boxShadow: [
            BoxShadow(
              color: (c.charging ? AppColors.lime : AppColors.violet)
                  .withValues(alpha: c.charging ? 0.35 : 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Saldo $appName',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PLUS',
                    style: TextStyle(
                      color: AppColors.bg,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onToggleHidden,
                  child: Icon(
                    hidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(end: c.balance),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  hidden ? 'Rp •••••••' : formatRupiah(v),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: c.charging
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _ChargingChip(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (icon, label) in _actions)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onAction(label),
                      child: Column(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargingChip extends StatefulWidget {
  const _ChargingChip();

  @override
  State<_ChargingChip> createState() => _ChargingChipState();
}

class _ChargingChipState extends State<_ChargingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.lime.withValues(alpha: 0.15 + _pulse.value * 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: AppColors.lime),
            SizedBox(width: 4),
            Text(
              'Saldo bertambah',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Services ─────────────────────────

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = [
    (Icons.phone_android_rounded, 'Pulsa', Color(0xFF38E1FF)),
    (Icons.wifi_rounded, 'Paket Data', Color(0xFF7B61FF)),
    (Icons.lightbulb_rounded, 'Listrik', Color(0xFFFFC53D)),
    (Icons.receipt_rounded, 'Tagihan', Color(0xFFFF8A4C)),
    (Icons.sports_esports_rounded, 'Voucher Game', Color(0xFFFF4D8D)),
    (Icons.credit_card_rounded, 'E-Money', Color(0xFF3DDC97)),
    (Icons.health_and_safety_rounded, 'Asuransi', Color(0xFF5B8CFF)),
    (Icons.grid_view_rounded, 'Lainnya', Color(0xFF8E97B5)),
  ];

  @override
  Widget build(BuildContext context) {
    Widget tile((IconData, String, Color) item) {
      final (icon, label, color) = item;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(label),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _Glass(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 16),
      child: Column(
        children: [
          Row(children: [for (final i in _items.take(4)) tile(i)]),
          const SizedBox(height: 18),
          Row(children: [for (final i in _items.skip(4)) tile(i)]),
        ],
      ),
    );
  }
}

// ───────────────────────── Promo ─────────────────────────

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.lime, AppColors.cyan],
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashback 30%',
                  style: TextStyle(
                    color: AppColors.bg,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Bayar pakai QRIS di merchant favoritmu. Maks Rp 15.000.',
                  style: TextStyle(color: Color(0xCC05070F), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                color: AppColors.bg, size: 30),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Transactions ─────────────────────────

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.transactions.take(7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              'Transaksi Terakhir',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Spacer(),
            Text(
              'Lihat semua',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Glass(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _TxnTile(txn: items[i]),
                  if (i != items.length - 1)
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (txn.type) {
      TxnType.topUp => (Icons.add_card_rounded, AppColors.lime),
      TxnType.transferIn => (Icons.south_west_rounded, AppColors.lime),
      TxnType.transferOut => (Icons.north_east_rounded, AppColors.pink),
      TxnType.payment => (Icons.qr_code_2_rounded, AppColors.cyan),
      TxnType.bill => (Icons.receipt_long_rounded, const Color(0xFFFFB443)),
      TxnType.cashback => (Icons.redeem_rounded, AppColors.lime),
    };
    final positive = txn.amount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${txn.subtitle} • ${formatTime(txn.time)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${positive ? '+' : '−'}${formatRupiah(txn.amount.abs())}',
            style: TextStyle(
              color: positive ? AppColors.lime : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Bottom nav ─────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.glow,
    required this.onPay,
    required this.onOther,
  });

  final bool glow;
  final VoidCallback onPay;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, {bool selected = false}) {
      final color = selected ? Colors.white : AppColors.textSecondary;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selected ? null : onOther,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            top: 8,
            child: _Glass(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              radius: 30,
              child: Row(
                children: [
                  item(Icons.home_rounded, 'Beranda', selected: true),
                  item(Icons.history_rounded, 'Riwayat'),
                  const Expanded(
                    child: Align(
                      alignment: Alignment(0, 0.85),
                      child: Text(
                        'Bayar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  item(Icons.local_offer_rounded, 'Promo'),
                  item(Icons.person_rounded, 'Akun'),
                ],
              ),
            ),
          ),
          Positioned(
            top: -16,
            child: GestureDetector(
              onTap: onPay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.violet, AppColors.violetDeep],
                  ),
                  border: Border.all(color: AppColors.bg, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: (glow ? AppColors.lime : AppColors.violet)
                          .withValues(alpha: 0.55),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
