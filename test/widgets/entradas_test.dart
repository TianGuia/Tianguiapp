import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/widgets/entradas.dart';

/// Aplica los formateadores como si el usuario escribiera [nuevo] sobre [viejo].
String _escribir(List<TextInputFormatter> f, String viejo, String nuevo) {
  final anterior = TextEditingValue(text: viejo);
  var actual = TextEditingValue(text: nuevo);
  for (final x in f) {
    actual = x.formatEditUpdate(anterior, actual);
  }
  return actual.text;
}

void main() {
  group('leerDinero', () {
    test('acepta montos válidos', () {
      expect(Entradas.leerDinero('150'), 150);
      expect(Entradas.leerDinero('150.5'), 150.5);
      expect(Entradas.leerDinero('150,50'), 150.5);
      expect(Entradas.leerDinero(' 12 '), 12);
      expect(Entradas.leerDinero('.5'), 0.5);
      expect(Entradas.leerDinero('99.'), 99);
      expect(Entradas.leerDinero('0'), 0);
    });
    test('rechaza lo que num.tryParse dejaría pasar', () {
      for (final t in ['', 'abc', '1e9', '-5', 'Infinity', 'NaN', '0x10', '1.234', '12345678', '1 2', '--1']) {
        expect(Entradas.leerDinero(t), isNull, reason: t);
      }
    });
  });

  group('leerPorcentaje y leerEntero', () {
    test('porcentaje', () {
      expect(Entradas.leerPorcentaje('50'), 50);
      expect(Entradas.leerPorcentaje('12,5'), 12.5);
      expect(Entradas.leerPorcentaje('1000'), isNull);
      expect(Entradas.leerPorcentaje('abc'), isNull);
    });
    test('entero', () {
      expect(Entradas.leerEntero('0'), 0);
      expect(Entradas.leerEntero('99999'), 99999);
      expect(Entradas.leerEntero('100000'), isNull);
      expect(Entradas.leerEntero('-1'), isNull);
      expect(Entradas.leerEntero('1.5'), isNull);
      expect(Entradas.leerEntero(''), isNull);
    });
  });

  test('leerCoordenada respeta el rango', () {
    expect(Entradas.leerCoordenada('20.6597', max: 90), 20.6597);
    expect(Entradas.leerCoordenada('-103.3496', max: 180), -103.3496);
    expect(Entradas.leerCoordenada('20.659698100000001', max: 90), isNotNull);
    expect(Entradas.leerCoordenada('91', max: 90), isNull);
    expect(Entradas.leerCoordenada('abc', max: 90), isNull);
  });

  test('correo, teléfono y nombre', () {
    expect(Entradas.correoValido('a@b.com'), isTrue);
    expect(Entradas.correoValido('a@b'), isFalse);
    expect(Entradas.correoValido('a b@c.com'), isFalse);
    expect(Entradas.correoValido('@'), isFalse);
    expect(Entradas.telefonoValido('33 1234 5678'), isTrue);
    expect(Entradas.telefonoValido('123'), isFalse);
    expect(Entradas.errorNombre(''), isNotNull);
    expect(Entradas.errorNombre('A'), isNotNull);
    expect(Entradas.errorNombre('...'), isNotNull);
    expect(Entradas.errorNombre('Tacos El Güero'), isNull);
  });

  group('formateadores', () {
    test('dinero bloquea letras, signos y exceso de decimales', () {
      expect(_escribir(Entradas.formatoDinero, '12', '12a'), '12');
      expect(_escribir(Entradas.formatoDinero, '12', '-12'), '12');
      expect(_escribir(Entradas.formatoDinero, '12.50', '12.505'), '12.50');
      expect(_escribir(Entradas.formatoDinero, '', 'abc123'), '');
      expect(_escribir(Entradas.formatoDinero, '', '150.5'), '150.5');
      expect(_escribir(Entradas.formatoDinero, '', '12345678'), '');
    });
    test('porcentaje y entero', () {
      expect(_escribir(Entradas.formatoPorcentaje, '10', '1000'), '10');
      expect(_escribir(Entradas.formatoEntero(5), '1234', '12345'), '12345');
      expect(_escribir(Entradas.formatoEntero(5), '12345', '123456'), '12345');
      expect(_escribir(Entradas.formatoEntero(5), '1', '1.'), '1');
    });
    test('códigos, teléfono, correo y nombre', () {
      expect(_escribir(Entradas.formatoCodigoOtp, '', '12ab34'), '1234');
      expect(_escribir(Entradas.formatoTelefono, '', '33-12ab'), '33-12');
      expect(_escribir(Entradas.formatoCorreo, '', 'a b@c.com'), 'ab@c.com');
      expect(_escribir(Entradas.formatoNombre, '', 'Ana 😀 López!'), 'Ana  López');
    });
  });
}
