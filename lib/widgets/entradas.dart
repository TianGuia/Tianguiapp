import 'package:flutter/services.dart';

// validaciones de lo que se escribe, se usan en todas las pantallas
// los formato... bloquean al escribir o pegar, pero keyboardType solo cambia el teclado
// los leer... se usan al guardar y no confian en que el formato ya filtro todo
class Entradas {
  Entradas._();

  // formateadores

  // acepta el texto nuevo solo si cumple el patron, si no deja el anterior
  static TextInputFormatter _patron(RegExp patron) =>
      TextInputFormatter.withFunction(
        (anterior, nuevo) => patron.hasMatch(nuevo.text) ? nuevo : anterior,
      );

  // dinero: hasta 7 enteros y 2 decimales, con punto o coma. sin signo.
  static final List<TextInputFormatter> formatoDinero = [
    _patron(RegExp(r'^\d{0,7}([.,]\d{0,2})?$')),
  ];

  // porcentaje: hasta 3 enteros y 2 decimales. sin signo.
  static final List<TextInputFormatter> formatoPorcentaje = [
    _patron(RegExp(r'^\d{0,3}([.,]\d{0,2})?$')),
  ];

  static List<TextInputFormatter> formatoEntero(int digitos) =>
      [_patron(RegExp('^\\d{0,$digitos}\$'))];

  static final List<TextInputFormatter> formatoCoordenada = [
    _patron(RegExp(r'^-?\d{0,3}([.,]\d{0,7})?$')),
  ];

  // codigo de un solo uso, otp del correo: solo digitos.
  static final List<TextInputFormatter> formatoCodigoOtp = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  // codigo de visita que muestra el vendedor: solo letras y digitos.
  static final List<TextInputFormatter> formatoCodigoVisita = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(12),
  ];

  // telefono: digitos, mas, guion, parentesis y espacio
  static final List<TextInputFormatter> formatoTelefono = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-() ]')),
    LengthLimitingTextInputFormatter(20),
  ];

  static final List<TextInputFormatter> formatoCorreo = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(254),
  ];

  // nombre publico: letras con acentos, numeros, espacio y . _ ' -
  static final List<TextInputFormatter> formatoNombre = [
    FilteringTextInputFormatter.allow(
        RegExp(r"[\p{L}\p{M}\p{N} ._'\-]", unicode: true)),
    LengthLimitingTextInputFormatter(30),
  ];

  static List<TextInputFormatter> texto(int maximo) =>
      [LengthLimitingTextInputFormatter(maximo)];

  // lectores y validadores

  // convierte 150, 150.5, 150,50 o .5 en numero, null si no es un monto valido
  // acepta 0, quien llama decide si sirve
  static num? leerDinero(String texto) {
    var s = texto.trim().replaceAll(',', '.');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.startsWith('.')) s = '0$s';
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(s)) return null;
    return num.parse(s);
  }

  // porcentaje de 0 a 999.99, el rango de 1 a 100 lo valida quien llama
  static num? leerPorcentaje(String texto) {
    var s = texto.trim().replaceAll(',', '.');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    if (s.startsWith('.')) s = '0$s';
    if (!RegExp(r'^\d{1,3}(\.\d{1,2})?$').hasMatch(s)) return null;
    return num.parse(s);
  }

  static int? leerEntero(String texto, {int maxDigitos = 5}) {
    final s = texto.trim();
    if (!RegExp('^\\d{1,$maxDigitos}\$').hasMatch(s)) return null;
    return int.parse(s);
  }

  static double? leerCoordenada(String texto, {required double max}) {
    final s = texto.trim().replaceAll(',', '.');
    // al leer se aceptan hasta 15 decimales porque en la base pueden venir asi
    // el formateador solo limita lo que se teclea
    if (!RegExp(r'^-?\d{1,3}(\.\d{1,15})?$').hasMatch(s)) return null;
    final v = double.parse(s);
    return v.abs() <= max ? v : null;
  }

  static final _correo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool correoValido(String texto) => _correo.hasMatch(texto.trim());

  static bool telefonoValido(String texto) {
    final digitos = texto.replaceAll(RegExp(r'\D'), '').length;
    return digitos >= 10 && digitos <= 15;
  }

  // mensaje de error para un nombre publico, o null si es aceptable.
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
