import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/widgets/zonas_mapa.dart';

void main() {
  test('los puntos y los pasillos usan longitud y latitud válidas', () {
    const punto = {
      'type': 'Point',
      'coordinates': [-103.34, 20.67],
    };
    const pasillo = {
      'type': 'LineString',
      'coordinates': [
        [-103.34, 20.67],
        [-103.35, 20.68],
      ],
    };
    expect(esGeometriaZona(punto), isTrue);
    expect(esGeometriaZona(pasillo), isTrue);
    expect(
        esGeometriaZona({
          'type': 'Point',
          'coordinates': [20.67, -103.34]
        }),
        isFalse);

    final capas = capasDeZonas([
      {'tipo': 'espacio', 'nombre': 'Espacio A', 'geometria': punto},
      {'tipo': 'pasillo', 'nombre': 'Pasillo B', 'geometria': pasillo},
    ]);
    expect(capas.lineas, hasLength(1));
    expect(capas.etiquetas, hasLength(2));
    expect(capas.etiquetas.first.point.latitude, 20.67);
  });
}
