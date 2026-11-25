import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tianguia/models/modelos.dart';
import 'package:tianguia/services/catalogo_service.dart';

void main() {
  late SupabaseClient client;
  late CatalogoService service;
  late List<http.Request> requests;

  setUp(() {
    requests = [];
    client = SupabaseClient(
      'https://catalogo.example.test',
      'synthetic-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'}, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    service = CatalogoService(client: client);
  });

  tearDown(() async => client.dispose());

  test('envía el día y el tianguis juntos y conserva los demás filtros',
      () async {
    await service.filtrarProductos(
      texto: 'libros',
      idTianguis: '24000000-0000-0000-0000-000000000021',
      diaSemana: 1,
      idCategoria: 'libros',
      precioMin: 10,
      precioMax: 50,
    );
    final request = requests.single;
    expect(request.url.path, '/rest/v1/rpc/productos_catalogo');
    expect(jsonDecode(request.body), {
      'p_tianguis': '24000000-0000-0000-0000-000000000021',
      'p_dia': 1,
    });
    expect(request.url.queryParameters['id_categoria'], 'eq.libros');
    expect(request.url.queryParametersAll['precio_referencia'],
        containsAll(['gte.10', 'lte.50']));
    expect(request.url.queryParameters['busqueda'], contains('libros'));
    expect(
        request.url.queryParameters['select'], contains('perfiles_vendedor'));
  });

  test('consulta únicamente ofertas que ya comenzaron y aún no vencen',
      () async {
    expect(await service.ofertaVigente('producto', 50), isNull);
    final params = requests.single.url.queryParameters;
    expect(params['id_producto'], 'eq.producto');
    expect(params['estado'], 'eq.activa');
    expect(params['fecha_inicio'], startsWith('lte.'));
    expect(params['fecha_fin'], 'gt.${params['fecha_inicio']!.substring(4)}');
  });

  test('la disponibilidad admite inventario sin conteo, pero no cero piezas',
      () {
    Producto producto(int? cantidad, {bool disponible = true, bool? manual}) =>
        Producto.fromMap({
          'id': 'producto',
          'id_vendedor': 'vendedor',
          'nombre': 'Producto',
          'estado_articulo': 'nuevo',
          'disponible': disponible,
          'disponibilidad_manual': manual,
          'cantidad_disponible': cantidad,
          'perfiles_vendedor': {'nombre_negocio': 'Mi negocio'},
        });

    expect(producto(null).sePuedeApartar, isTrue);
    expect(producto(0).sePuedeApartar, isFalse);
    expect(producto(2, disponible: false).sePuedeApartar, isFalse);
    expect(producto(2).vendedorNombre, 'Mi negocio');
    final agotado = producto(0, disponible: false, manual: true);
    expect(agotado.sePuedeApartar, isFalse);
    expect(agotado.disponibilidadManual, isTrue);
  });
}
