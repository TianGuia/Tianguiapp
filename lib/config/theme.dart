import 'package:flutter/material.dart';

class Tg {
  static const azul = Color(0xFF0B2A8F);
  static const azulOscuro = Color(0xFF061A5E);
  static const amarillo = Color(0xFFFFD21F);
  static const rojo = Color(0xFFE8232F);
  static const verde = Color(0xFF1E8E3E);
  static const rosa = Color(0xFFE91E8C);

  static ThemeData get tema => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azul,
          brightness: Brightness.dark,
          primary: amarillo,
          onPrimary: azulOscuro,
          surface: azul,
        ),
        scaffoldBackgroundColor: azul,
        appBarTheme: const AppBarTheme(
          backgroundColor: azulOscuro,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: azulOscuro,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.black45),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: amarillo,
            foregroundColor: azulOscuro,
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: azulOscuro,
          indicatorColor: amarillo,
        ),
      );
}
