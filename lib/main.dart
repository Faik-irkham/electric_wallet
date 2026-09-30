import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme.dart';
import 'wallet_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bg,
    ),
  );
  final controller = WalletController()..init();

  if (const bool.fromEnvironment('AUTO_SIM')) {
    Future.delayed(const Duration(seconds: 2), controller.startSimulation);
  }
  runApp(ElectricWalletApp(controller: controller));
}

class ElectricWalletApp extends StatelessWidget {
  const ElectricWalletApp({super.key, required this.controller});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electric Wallet',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(controller: controller),
    );
  }
}
