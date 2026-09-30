import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TxnType { topUp, transferIn, transferOut, payment, bill, cashback }

class Txn {
  Txn({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    required this.type,
  });

  final String title;
  final String subtitle;
  double amount;
  final DateTime time;
  final TxnType type;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'time': time.millisecondsSinceEpoch,
        'type': type.name,
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        amount: (j['amount'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch(j['time'] as int),
        type: TxnType.values.byName(j['type'] as String),
      );
}

/// Dompet digital biasa, dengan satu keanehan:
/// selama HP terhubung ke charger, saldo terus bertambah.
class WalletController extends ChangeNotifier {
  static const _startBalance = 1284500.0;
  static const _kBalance = 'balance';
  static const _kTxns = 'transactions';

  final Battery _battery = Battery();
  final _rnd = math.Random();
  SharedPreferences? _prefs;
  StreamSubscription<BatteryState>? _stateSub;
  Timer? _pollTimer;
  Timer? _tickTimer;

  double balance = _startBalance;
  List<Txn> transactions = _seedTransactions();
  bool charging = false;
  bool simulating = false;
  bool ready = false;

  /// Total saldo yang masuk di sesi charging saat ini.
  double sessionTotal = 0;
  Txn? _session;
  bool _plugged = false;

  /// Setiap kali saldo bertambah (untuk animasi "+Rp").
  final gains = StreamController<double>.broadcast();

  /// Saat charger dicabut: total top up sesi itu.
  final topUpCompleted = StreamController<double>.broadcast();

  /// Dipakai untuk seberapa penuh uang di ikon dompet 3D.
  double get fill => (balance / 5000000).clamp(0.12, 1.0);

  double get incomeThisMonth => _sumThisMonth((t) => t.amount > 0);
  double get spendThisMonth => _sumThisMonth((t) => t.amount < 0).abs();

  double _sumThisMonth(bool Function(Txn) test) {
    final now = DateTime.now();
    return transactions
        .where((t) =>
            test(t) && t.time.year == now.year && t.time.month == now.month)
        .fold(0.0, (a, t) => a + t.amount);
  }

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final b = _prefs!.getDouble(_kBalance);
      final raw = _prefs!.getString(_kTxns);
      if (b != null) balance = b;
      if (raw != null) {
        transactions = (jsonDecode(raw) as List)
            .map((e) => Txn.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    try {
      _plugged = _isPlugged(await _battery.batteryState);
      _stateSub = _battery.onBatteryStateChanged.listen((s) {
        _plugged = _isPlugged(s);
        _sync();
      });
    } catch (_) {
      // Platform tanpa info baterai.
    }
    // Cadangan kalau stream status baterai tidak terpicu di beberapa perangkat.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        _plugged = _isPlugged(await _battery.batteryState);
        _sync();
      } catch (_) {}
    });

    ready = true;
    _sync();
    notifyListeners();
  }

  bool _isPlugged(BatteryState s) =>
      s == BatteryState.charging ||
      s == BatteryState.full ||
      s == BatteryState.connectedNotCharging;

  void _sync() => _setCharging(_plugged || simulating);

  void _setCharging(bool value) {
    if (value == charging) return;
    charging = value;
    if (value) {
      _tickTimer = Timer.periodic(const Duration(milliseconds: 900), _tick);
    } else {
      _tickTimer?.cancel();
      if (sessionTotal > 0) topUpCompleted.add(sessionTotal);
      _session = null;
      sessionTotal = 0;
      _save();
    }
    notifyListeners();
  }

  void _tick(Timer _) {
    // Rp 1.000 – Rp 7.500, kelipatan 500 biar terlihat natural.
    final amount = (2 + _rnd.nextInt(14)) * 500.0;
    balance += amount;
    sessionTotal += amount;
    if (_session == null) {
      _session = Txn(
        title: 'Top Up',
        subtitle: 'Charger • Fast Charging',
        amount: 0,
        time: DateTime.now(),
        type: TxnType.topUp,
      );
      transactions.insert(0, _session!);
    }
    _session!.amount += amount;
    gains.add(amount);
    HapticFeedback.selectionClick();
    _save();
    notifyListeners();
  }

  /// Pemicu tersembunyi untuk rekam konten tanpa charger sungguhan.
  void toggleSimulation() {
    simulating = !simulating;
    _sync();
    notifyListeners();
  }

  void startSimulation() {
    if (!simulating) toggleSimulation();
  }

  /// Kembalikan saldo & riwayat ke kondisi awal (untuk take ulang).
  void resetDemo() {
    balance = _startBalance;
    transactions = _seedTransactions();
    _session = null;
    sessionTotal = 0;
    _save();
    notifyListeners();
  }

  void _save() {
    final p = _prefs;
    if (p == null) return;
    p.setDouble(_kBalance, balance);
    p.setString(
      _kTxns,
      jsonEncode(transactions.take(50).map((t) => t.toJson()).toList()),
    );
  }

  static List<Txn> _seedTransactions() {
    final now = DateTime.now();
    DateTime ago(int h, [int m = 0]) =>
        now.subtract(Duration(hours: h, minutes: m));
    return [
      Txn(
        title: 'Kopi Senja',
        subtitle: 'Pembayaran QRIS',
        amount: -38000,
        time: ago(1, 12),
        type: TxnType.payment,
      ),
      Txn(
        title: 'Transfer dari Ayu Lestari',
        subtitle: 'Terima uang',
        amount: 250000,
        time: ago(3, 40),
        type: TxnType.transferIn,
      ),
      Txn(
        title: 'Token Listrik',
        subtitle: 'Tagihan • 100.000',
        amount: -102500,
        time: ago(6, 5),
        type: TxnType.bill,
      ),
      Txn(
        title: 'Cashback QRIS',
        subtitle: 'Promo',
        amount: 5000,
        time: ago(6, 30),
        type: TxnType.cashback,
      ),
      Txn(
        title: 'Transfer ke Dimas Pratama',
        subtitle: 'Kirim uang',
        amount: -150000,
        time: ago(22, 10),
        type: TxnType.transferOut,
      ),
      Txn(
        title: 'Paket Data 25GB',
        subtitle: 'Pulsa & Data',
        amount: -85000,
        time: ago(27),
        type: TxnType.bill,
      ),
      Txn(
        title: 'Isi Saldo',
        subtitle: 'Dari rekening bank',
        amount: 500000,
        time: ago(30),
        type: TxnType.topUp,
      ),
    ];
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    gains.close();
    topUpCompleted.close();
    super.dispose();
  }
}
