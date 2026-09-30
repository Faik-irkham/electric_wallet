import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AppColors {
  static const bg = Color(0xFF05070F);
  static const surface = Color(0xFF0D1222);
  static const surfaceHigh = Color(0xFF151C33);
  static const stroke = Color(0x1FFFFFFF);

  static const lime = Color(0xFFB8FF3B);
  static const cyan = Color(0xFF38E1FF);
  static const violet = Color(0xFF7B61FF);
  static const violetDeep = Color(0xFF2A1B78);
  static const pink = Color(0xFFFF4D8D);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8E97B5);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
      primary: AppColors.lime,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

/// Nama brand & pengguna yang tampil di aplikasi. Ganti sesuai kebutuhan konten.
const appName = 'VoltPay';
const userName = 'Andika';

final _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

String formatRupiah(double value) => _rupiah.format(value);

String formatRupiahShort(double value) {
  final v = value.abs();
  if (v >= 1000000) {
    final jt = v / 1000000;
    return 'Rp ${jt.toStringAsFixed(jt % 1 == 0 ? 0 : 1).replaceAll('.', ',')}jt';
  }
  if (v >= 1000) return 'Rp ${(v / 1000).round()}rb';
  return 'Rp ${v.round()}';
}

String formatTime(DateTime t) {
  final now = DateTime.now();
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hari ini, $hm';
  if (diff == 1) return 'Kemarin, $hm';
  return '${t.day}/${t.month}, $hm';
}
