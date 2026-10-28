import 'package:flutter/services.dart';

/// Reglas de captura compartidas por todas las pantallas.
///
/// Hay dos capas, y conviene usar las dos:
///  1. Formateadores (`formato...`): impiden ESCRIBIR o PEGAR caracteres que
///     no corresponden (por ejemplo, letras en un precio). `keyboardType`
///     solo cambia el teclado en pantalla; no evita pegar texto ni usar
///     teclado físico.
///  2. Lectores/validadores (`leer...`, `...Valido`): se usan al guardar y
///     devuelven null / false si el valor no es aceptable. No confían en que
///     el formateador haya hecho su trabajo.
class Entradas {
  Entradas._();

  // ------------------------------------------------------------------
  // Formateadores
  // ------------------------------------------------------------------

  /// Acepta el nuevo texto solo si cumple [patron]; si no, conserva el anterior.
  /// Así también se rechaza un pegado completo que no cumple.
  static TextInputFormatter _patron(RegExp patron) =>
      TextInputFormatter.withFunction(
        (anterior, nuevo) => patron.hasMatch(nuevo.text) ? nuevo : anterior,
      );

  /// Dinero: hasta 7 enteros y 2 decimales, con punto o coma. Sin signo.
  static final List<TextInputFormatter> formatoDinero = [
    _patron(RegExp(r'^\d{0,7}([.,]\d{0,2})?$')),
  ];

  /// Porcentaje: hasta 3 enteros y 2 decimales. Sin signo.
  static final List<TextInputFormatter> formatoPorcentaje = [
    _patron(RegExp(r'^\d{0,3}([.,]\d{0,2})?$')),
  ];

  /// Entero positivo de hasta [digitos] cifras.
  static List<TextInputFormatter> formatoEntero(int digitos) =>
      [_patron(RegExp('^\\d{0,$digitos}\$'))];

  /// Coordenada con signo: hasta 3 enteros y 7 decimales.
  static final List<TextInputFormatter> formatoCoordenada = [
    _patron(RegExp(r'^-?\d{0,3}([.,]\d{0,7})?$')),
  ];

  /// Código de un solo uso (OTP) del correo: solo dígitos.
  static final List<TextInputFormatter> formatoCodigoOtp = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  /// Código de visita que muestra el vendedor: solo letras y dígitos.
  static final List<TextInputFormatter> formatoCodigoVisita = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(12),
  ];

  /// Teléfono: dígitos y los símbolos habituales (+ - ( ) espacio).
  static final List<TextInputFormatter> formatoTelefono = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
    LengthLimitingTextInputFormatter(20),
  ];

  /// Correo: sin espacios.
  static final List<TextInputFormatter> formatoCorreo = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(254),
  ];

  /// Nombre público: letras (con acentos), números, espacio y . _ ' -
  static final List<TextInputFormatter> formatoNombre = [
    FilteringTextInputFormatter.allow(
        RegExp(r"[\p{L}\p{M}\p{N} ._'\-]", unicode: true)),
    LengthLimitingTextInputFormatter(30),
  ];

  /// Solo limita la longitud (texto libre).
  static List<TextInputFormatter> texto(int maximo) =>
      [LengthLimitingTextInputFormatter(maximo)];

  // ------------------------------------------------------------------
  // Lectores y validadores
  // ------------------------------------------------------------------

  /// Convierte "150", "150.5", "150,50" o ".5" en número. Devuelve null si no
  /// es un monto válido (letras, notación científica, negativos, infinito…).
  /// Acepta 0; quien llama decide si 0 es válido.
  static num? leerDinero(String texto) {
    var s = texto.trim().replaceAll(',', '.');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.startsWith('.')) s = '0$s';
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(s)) return null;
    return num.parse(s);
  }

  /// Porcentaje de 0 a 999.99 con formato válido; el rango (1 a 100) lo valida
  /// quien llama.
  static num? leerPorcentaje(String texto) {
    var s = texto.trim().replaceAll(',', '.');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.startsWith('.')) s = '0$s';
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s)) return null;
    return num.parse(s);
  }

  /// Entero positivo de hasta [maxDigitos] cifras, o null.
  static int? leerEntero(String texto, {int maxDigitos = 5}) {
    final s = texto.trim();
    if (!RegExp('^\\d{1,$maxDigitos}\$').hasMatch(s)) return null;
    return int.parse(s);
  }

  /// Coordenada decimal dentro de [-max, max], o null.
  static double? leerCoordenada(String texto, {required double max}) {
    final s = texto.trim().replaceAll(',', '.');
    // Al leer se aceptan hasta 15 decimales: los valores ya guardados en la
    // base pueden traerlos. El formateador solo limita lo que se teclea.
    if (!RegExp(r'^-?\d{1,3}(\.\d{1,15})?$').hasMatch(s)) return null;
    final v = double.parse(s);
    return v.abs() <= max ? v : null;
  }

  static final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool correoValido(String texto) => _correo.hasMatch(texto.trim());

  /// De 10 a 15 dígitos (admite lada internacional).
  static bool telefonoValido(String texto) {
    final digitos = texto.replaceAll(RegExp(r'\D'), '').length;
    return digitos >= 10 && digitos <= 15;
  }

  /// Mensaje de error para un nombre público, o null si es aceptable.
  static String? errorNombre(String texto) {
    final n = texto.trim();
    if (n.isEmpty) return 'Escribe un nombre';
    if (n.length < 2) return 'El nombre debe tener al menos 2 caracteres';
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(n)) {
      return 'El nombre debe incluir letras o números';
    }
    return null;
  }
}
