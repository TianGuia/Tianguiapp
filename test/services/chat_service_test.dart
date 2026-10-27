import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/models/identidad.dart';
import 'package:tianguia/models/tratos.dart';
import 'package:tianguia/services/chat_service.dart';
import '../support/backend_fake.dart';

void main() {
  late BackendFake backend;
  tearDown(() async => backend.dispose());

  test('comprador crea propuesta y apartado con la identidad de sesión',
      () async {
    backend = BackendFake((r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['id_comprador'], usuarioId);
      if (r.url.path.endsWith('/propuestas_precio')) {
        expect(body['id_emisor'], usuarioId);
        return jsonResponse({
          ...body,
          'id': 'propuesta',
          'estado': 'pendiente',
          'creada_en': fecha
        });
      }
      if (r.url.path.endsWith('/apartados')) {
        return jsonResponse({
          ...body,
          'id': 'apartado',
          'estado': 'pendiente',
          'fecha_inicio': fecha
        });
      }
      return unexpected(r);
    });
    await backend.login();
    final servicio = ChatService(client: backend.client);
    final c = Comprador.fromMap(
        {'id_comprador': usuarioId, 'usuarios': usuarioFila()});
    expect(
        (await c.proponerPrecio(servicio,
                idProducto: productoId, idVendedor: vendedorId, monto: 80))
            .monto,
        80);
    expect(
        (await Apartado.solicitarApartado(servicio,
                idProducto: productoId, idVendedor: vendedorId))
            .pendiente,
        isTrue);
  });

  test('participantes consulta, agrega y retira por clave compuesta', () async {
    backend = BackendFake((r) {
      expect(r.url.path, '/rest/v1/participantes');
      if (r.method == 'GET') {
        return jsonResponse([
          {'id_conversacion': 'conversacion', 'id_usuario': usuarioId}
        ]);
      }
      if (r.method == 'POST') {
        expect(jsonDecode(r.body),
            {'id_conversacion': 'conversacion', 'id_usuario': 'persona'});
      } else {
        expect(r.url.queryParameters['id_conversacion'], 'eq.conversacion');
        expect(r.url.queryParameters['id_usuario'], 'eq.persona');
      }
      return jsonResponse(null, status: 204);
    });
    final servicio = ChatService(client: backend.client);
    expect((await servicio.participantes('conversacion')).single.idUsuario,
        usuarioId);
    await servicio.agregarParticipante('conversacion', 'persona');
    await servicio.retirarParticipante('conversacion', 'persona');
  });
  test('chat de anuncio inserta sin RETURNING y consulta después', () async {
    var creado = false;
    backend = BackendFake((r) {
      expect(r.url.path, '/rest/v1/conversaciones');
      if (r.method == 'POST') {
        expect(r.url.queryParameters.containsKey('select'), isFalse);
        expect(jsonDecode(r.body), {
          'contexto': 'anuncio_espacio',
          'id_anuncio_espacio': 'anuncio',
          'id_iniciador': usuarioId,
          'id_receptor': 'dueno',
        });
        creado = true;
        return jsonResponse(null, status: 201);
      }
      return jsonResponse(creado ? {'id': 'chat-anuncio'} : null);
    });
    await backend.login();
    expect(
        await ChatService(client: backend.client)
            .conversacionDeAnuncio('anuncio', 'dueno'),
        'chat-anuncio');
    expect(creado, isTrue);
  });

  test('moderación de una persona no elige arbitrariamente en grupos',
      () async {
    backend = BackendFake((r) => jsonResponse([
          {'id_conversacion': 'grupo', 'id_usuario': usuarioId},
          {'id_conversacion': 'grupo', 'id_usuario': 'uno'},
          {'id_conversacion': 'grupo', 'id_usuario': 'dos'},
        ]));
    await backend.login();
    expect(await ChatService(client: backend.client).otroParticipante('grupo'),
        isNull);
  });
}
