import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Tg {
  static const azul = Color(0xFF0B2A8F);
  static const azulOscuro = Color(0xFF061A5E);
  static const azulClaro = Color(0xFF4FC3F7);
  static const amarillo = Color(0xFFFFD21F);
  static const rojo = Color(0xFFE8232F);
  static const verde = Color(0xFF1E8E3E);
  static const rosa = Color(0xFFE91E8C);
  static const naranja = Color(0xFFFF8A00);

  static TextStyle marcador(double size, {Color color = Colors.white}) =>
      GoogleFonts.permanentMarker(fontSize: size, color: color);

  static ThemeData get tema {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    final textos = GoogleFonts.baloo2TextTheme(base.textTheme)
        .apply(bodyColor: Colors.white, displayColor: Colors.white);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: azul,
        brightness: Brightness.dark,
        primary: amarillo,
        onPrimary: azulOscuro,
        secondary: rosa,
        surface: azul,
      ),
      scaffoldBackgroundColor: azul,
      textTheme: textos,
      appBarTheme: AppBarTheme(
        backgroundColor: azulOscuro,
        foregroundColor: Colors.white,
        titleTextStyle: marcador(20),
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: azulOscuro,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      // todas las ventanas emergentes (AlertDialog, SimpleDialog) con el look sticker de la app
      dialogTheme: DialogThemeData(
        backgroundColor: azulOscuro,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: azulClaro.withValues(alpha: 0.6), width: 2),
        ),
        titleTextStyle: marcador(21),
        contentTextStyle: GoogleFonts.baloo2(
            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: azulOscuro,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: azulClaro.withValues(alpha: 0.5), width: 1.5),
        ),
        textStyle: GoogleFonts.baloo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: azulOscuro,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: azulOscuro,
        contentTextStyle: GoogleFonts.baloo2(color: Colors.white, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.black45),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: amarillo,
          foregroundColor: azulOscuro,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: amarillo),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amarillo,
        foregroundColor: azulOscuro,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? amarillo : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(azulOscuro),
        side: const BorderSide(color: Colors.white70, width: 1.6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: azulOscuro,
        indicatorColor: amarillo,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? azulOscuro : Colors.white70)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.baloo2(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? amarillo : Colors.white70)),
      ),
    );
  }
}
