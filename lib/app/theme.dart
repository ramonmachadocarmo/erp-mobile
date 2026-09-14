import 'package:flutter/material.dart';

const erpBg = Color(0xFF0F1419);
const erpPanel = Color(0xFF1A2332);
const erpPanel2 = Color(0xFF243044);
const erpLine = Color(0xFF2E3D52);
const erpText = Color(0xFFE8EEF6);
const erpMuted = Color(0xFF8EA0B5);
const erpAccent = Color(0xFF3D8BFD);
const erpDanger = Color(0xFFE85D5D);

ThemeData erpTheme() {
  final scheme = const ColorScheme.dark(
    primary: erpAccent,
    onPrimary: Colors.white,
    surface: erpBg,
    onSurface: erpText,
    error: erpDanger,
    onError: Colors.white,
    outline: erpLine,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: erpBg,
    canvasColor: const Color(0xFF0C1118),
    appBarTheme: const AppBarTheme(
      backgroundColor: erpBg,
      foregroundColor: erpText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF0C1118)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: erpPanel2,
      labelStyle: const TextStyle(color: erpMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: erpLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: erpLine),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: erpAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: erpPanel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: erpLine),
      ),
    ),
  );
}
