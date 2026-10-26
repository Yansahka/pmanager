import 'package:flutter/material.dart';

import 'application/vault_controller.dart';
import 'data/vault_storage.dart';
import 'ui/gate_screen.dart';
import 'ui/vault_screen.dart';

const ink = Color(0xFF173C35);
const accent = Color(0xFFBCEB77);

class SesameApp extends StatefulWidget {
  final VaultController? controller;
  const SesameApp({super.key, this.controller});
  @override
  State<SesameApp> createState() => _SesameAppState();
}

class _SesameAppState extends State<SesameApp> with WidgetsBindingObserver {
  late final VaultController vault;
  final navigator = GlobalKey<NavigatorState>();
  bool wasUnlocked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vault = widget.controller ?? VaultController(AndroidVaultStorage());
    wasUnlocked = vault.unlocked;
    vault.addListener(_changed);
    if (!vault.ready) vault.initialize();
  }

  void _changed() {
    if (wasUnlocked && !vault.unlocked) {
      navigator.currentState?.popUntil((r) => r.isFirst);
    }
    wasUnlocked = vault.unlocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) vault.lock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    vault.removeListener(_changed);
    if (widget.controller == null) vault.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    title: 'Sésame',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Sesame',
      scaffoldBackgroundColor: const Color(0xFFF5F6F1),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        secondary: accent,
        surface: const Color(0xFFF5F6F1),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E5DC)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    ),
    home: ListenableBuilder(
      listenable: vault,
      builder: (context, _) => Listener(
        onPointerDown: (_) => vault.touch(),
        onPointerMove: (_) => vault.touch(),
        child: !vault.ready
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : vault.unlocked
            ? VaultScreen(vault: vault)
            : GateScreen(vault: vault),
      ),
    ),
  );
}
