import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/models/confianza.dart';
import 'package:tianguia/models/identidad.dart';
import 'package:tianguia/models/mensajeria.dart';
import 'package:tianguia/models/modelos.dart';
import 'package:tianguia/models/operaciones.dart';
import 'package:tianguia/models/tratos.dart';
import 'package:tianguia/services/auth_service.dart';
import 'package:tianguia/services/catalogo_service.dart';
import 'package:tianguia/services/chat_service.dart';
import 'package:tianguia/services/confianza_service.dart';
import 'package:tianguia/services/puestos_service.dart';
import 'package:tianguia/services/tratos_service.dart';
import 'package:tianguia/services/vendedor_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/backend_fake.dart';

void main() {
  late BackendFake backend;
  tearDown(() async => backend.dispose());

  test('registro, acceso y actualización devuelven el perfil persistido',
      () async {
    var nombre = 'Persona';
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/terminos_pendientes')) return jsonResponse([]);
      if (r.url.path.endsWith('/usuarios')) {
        if (r.method == 'PATCH') {
          nombre = (jsonDecode(r.body) as Map)['nombre_publico'] as String;
          return jsonResponse(null, status: 204);
        }
        return jsonResponse({...usuarioFila(), 'nombre_publico': nombre});
      }
      return unexpected(r);
    });
    final servicio = AuthService(client: backend.client);
    final registrado = await Usuario.registrar(servicio, 'Registrado');
    expect(registrado.nombre, 'Registrado');
    final acceso =
        await Usuario.iniciarSesion(servicio, 'persona@example.test', '123456');
    expect(acceso.idUsuario, registrado.idUsuario);
    expect(
        (await acceso.actualizarPerfil(servicio, nombre: 'Actualizado')).nombre,
        'Actualizado');
  });

  test('comprador busca y filtra; tianguis consulta sus zonas reales',
      () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/productos')) {
        return jsonResponse([productoFila()]);
      }
      if (r.url.path.endsWith('/tianguis')) {
        return jsonResponse({'id': 't', 'nombre': 'Tianguis', 'activo': true});
      }
      if (r.url.path.endsWith('/tianguis_zonas')) {
        return jsonResponse([
          {
            'id': 'z',
            'nombre': 'Entrada',
            'tipo': 'zona',
            'geometria': {
              'type': 'Point',
              'coordinates': [0, 0]
            }
          }
        ]);
      }
      return unexpected(r);
    });
    final c = Comprador.fromMap(
        {'id_comprador': usuarioId, 'usuarios': usuarioFila()});
    final servicio = CatalogoService(client: backend.client);
    expect(await c.buscarProductos(servicio, 'camisa'), hasLength(1));
    expect(backend.requests.last.url.queryParameters['busqueda'],
        contains('camisa'));
    await c.filtrarProductos(servicio,
        idCategoria: 'categoria', precioMin: 10, precioMax: 200);
    expect(backend.requests.last.url.queryParameters['id_categoria'],
        'eq.categoria');
    expect(backend.requests.last.url.queryParameters['select'],
        contains('puestos!productos_id_puesto_fkey'));
    final t =
        Tianguis.fromMap({'id': 't', 'nombre': 'Tianguis', 'activo': true});
    expect((await t.consultarMapa(servicio)).zonas.single.nombre, 'Entrada');
  });

  test('habilitación, horarios y ausencias usan el identificador del vendedor',
      () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/perfiles_vendedor')) {
        return jsonResponse(vendedorFila());
      }
      if (r.url.path.endsWith('/vendedor_horarios') ||
          r.url.path.endsWith('/ausencias_programadas')) {
        expect(jsonDecode(r.body)['id_vendedor'], vendedorId);
        return jsonResponse(null, status: 201);
      }
      return unexpected(r);
    });
    await backend.login();
    final servicio = VendedorService(client: backend.client);
    final v = await Vendedor.habilitarPerfil(servicio, descripcion: 'Catálogo');
    expect(v.idUsuario, usuarioId);
    await v.registrarHorario(servicio,
        idTianguis: 't', dia: 1, inicio: '08:00', fin: '16:00');
    await v.registrarAusencia(servicio,
        idTianguis: 't', fecha: DateTime(2026, 11, 1));
    expect(jsonDecode(backend.requests.last.body)['fecha'], '2026-11-01');
  });

  test(
      'producto valida puesto, vuelve tipado y actualiza stock sin perder asociación',
      () async {
    var cantidad = 5;
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/puestos')) return jsonResponse(puestoFila());
      if (r.url.path.endsWith('/productos')) {
        if (r.method == 'PATCH') {
          final body = jsonDecode(r.body) as Map;
          expect(body.containsKey('id_puesto'), isFalse);
          cantidad = body['cantidad_disponible'] as int;
          return jsonResponse(null, status: 204);
        }
        return jsonResponse(
            {...productoFila(), 'cantidad_disponible': cantidad});
      }
      return unexpected(r);
    });
    final servicio = VendedorService(client: backend.client);
    final p = await Producto.crearProducto(servicio,
        idVendedor: vendedorId,
        idPuesto: puestoId,
        nombre: 'Producto',
        disponibilidad: 5);
    expect((await p.actualizarStock(servicio, 3)).disponibilidad, 3);
    final anteriores = backend.requests.length;
    await expectLater(
        servicio.crearProducto(
            idVendedor: vendedorId, idPuesto: '', nombre: 'Sin puesto'),
        throwsArgumentError);
    await expectLater(servicio.actualizarProducto(p.id, {'id_puesto': null}),
        throwsArgumentError);
    await expectLater(p.actualizarStock(servicio, -1), throwsArgumentError);
    expect(backend.requests.length, anteriores);
  });

  test('producto rechaza puesto inactivo o de otro vendedor', () async {
    backend = BackendFake((r) => r.url.path.endsWith('/puestos')
        ? jsonResponse({...puestoFila(), 'activo': false})
        : unexpected(r));
    final s = VendedorService(client: backend.client);
    await expectLater(
        s.crearProducto(
            idVendedor: vendedorId, idPuesto: puestoId, nombre: 'Producto'),
        throwsStateError);
    expect(backend.requests.any((r) => r.method == 'POST'), isFalse);
  });

  test('publicación múltiple es un solo INSERT de ofertas individuales',
      () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/ofertas') && r.method == 'POST') {
        final filas = jsonDecode(r.body) as List;
        expect(filas, hasLength(2));
        expect(filas[0]['id_producto'], productoId);
        expect(filas[0]['descuento'], 20);
        expect(filas[1]['precio_promocional'], 50);
        expect(r.url.queryParameters['select'],
            contains('productos!ofertas_id_producto_fkey'));
        return jsonResponse(
            [ofertaFila(), ofertaFila(id: 'oferta2', producto: 'producto2')]);
      }
      return unexpected(r);
    });
    final ofertas = await VendedorService(client: backend.client)
        .publicarOferta(
            idVendedor: vendedorId,
            titulo: 'Ofertas',
            fin: DateTime.now().add(const Duration(hours: 1)),
            productos: [
          (idProducto: productoId, precioPromo: null, descuento: 20),
          (idProducto: 'producto2', precioPromo: 50, descuento: null)
        ]);
    expect(ofertas.map((o) => o.idProducto), [productoId, 'producto2']);
    expect(backend.requests, hasLength(1));
  });

  test('métodos de oferta publican y recuperan el estado finalizado', () async {
    var estado = 'activa';
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/ofertas')) {
        if (r.method == 'PATCH') {
          estado = jsonDecode(r.body)['estado'] as String;
          return jsonResponse(null, status: 204);
        }
        if (r.method == 'POST') return jsonResponse([ofertaFila()]);
        return jsonResponse({...ofertaFila(), 'estado': estado});
      }
      return unexpected(r);
    });
    final servicio = VendedorService(client: backend.client);
    final o = await Oferta.publicarOferta(servicio,
        idVendedor: vendedorId,
        idProducto: productoId,
        titulo: 'Oferta',
        descuento: 20,
        fin: DateTime.now().add(const Duration(days: 1)));
    expect((await o.finalizarOferta(servicio)).estado, 'finalizada');
  });

  test('oferta vigente filtra fechas y elige la que finaliza primero',
      () async {
    backend = BackendFake((r) {
      expect(r.url.path, '/rest/v1/ofertas');
      expect(r.url.queryParameters['estado'], 'eq.activa');
      expect(r.url.queryParameters['fecha_inicio'], startsWith('lte.'));
      expect(r.url.queryParameters['fecha_fin'], startsWith('gt.'));
      expect(r.url.queryParameters['order'], 'fecha_fin.asc.nullslast');
      return jsonResponse([ofertaFila()]);
    });
    final o = await CatalogoService(client: backend.client)
        .ofertaVigente(productoId, 100);
    expect(o!.precio, 80);
  });

  test('retiro usa exclusivamente la RPC transaccional y propaga rechazos',
      () async {
    backend = BackendFake((r) {
      expect(r.url.path, '/rest/v1/rpc/retirar_puesto');
      expect(jsonDecode(r.body), {'p_id_puesto': puestoId});
      return jsonResponse({'code': '42501', 'message': 'No autorizado'},
          status: 403);
    });
    await expectLater(
        VendedorService(client: backend.client).eliminarPuesto(puestoId),
        throwsA(isA<PostgrestException>()));
    expect(backend.requests, hasLength(1));
  });

  test('tratos siguen las FK nuevas y las respuestas permanecen en RPC',
      () async {
    var estado = 'pendiente';
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/responder_apartado')) {
        final accion = jsonDecode(r.body)['p_accion'];
        estado = accion == 'aceptar' ? 'aceptado' : 'rechazado';
        return jsonResponse(null);
      }
      if (r.url.path.endsWith('/apartados')) {
        expect(r.url.queryParameters['select'],
            contains('comprador:compradores!apartados_id_comprador_fkey'));
        final fila = {...apartadoFila(), 'estado': estado};
        return jsonResponse(
            r.url.queryParameters.containsKey('id') ? fila : [fila]);
      }
      if (r.url.path.endsWith('/propuestas_precio')) {
        expect(
            r.url.queryParameters['select'],
            contains(
                'comprador:compradores!propuestas_precio_id_comprador_fkey'));
        return jsonResponse([]);
      }
      return unexpected(r);
    });
    await backend.login();
    final s = TratosService(client: backend.client);
    await s.propuestas();
    final a = (await s.apartados()).single;
    expect(a.compradorNombre, 'Persona');
    expect((await a.aceptarApartado(s)).estado, 'aceptado');
    expect((await a.rechazarApartado(s)).estado, 'rechazado');
  });

  test(
      'chat lista membresías de tres personas, sin limitar a iniciador/receptor',
      () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/participantes')) {
        return jsonResponse([
          {'id_conversacion': 'conversacion'}
        ]);
      }
      if (r.url.path.endsWith('/conversaciones')) {
        expect(r.url.queryParameters.containsKey('or'), isFalse);
        expect(r.url.queryParameters['id'], contains('conversacion'));
        return jsonResponse([conversacionFila()]);
      }
      if (r.url.path.endsWith('/conversaciones_ocultas')) {
        return jsonResponse([]);
      }
      return unexpected(r);
    });
    await backend.login();
    final conversaciones =
        await ChatService(client: backend.client).misConversaciones();
    expect(conversaciones.single.participantes, hasLength(3));
    expect(conversaciones.single.idProducto, isNull);
  });

  test('chat oculto reaparece solo con un mensaje posterior', () async {
    var ultimo = DateTime.parse(fecha);
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/participantes')) {
        return jsonResponse([
          {'id_conversacion': 'conversacion'}
        ]);
      }
      if (r.url.path.endsWith('/conversaciones')) {
        return jsonResponse([conversacionFila(ultimo: ultimo)]);
      }
      if (r.url.path.endsWith('/conversaciones_ocultas')) {
        return jsonResponse([
          {'id_conversacion': 'conversacion', 'ocultada_en': fecha}
        ]);
      }
      return unexpected(r);
    });
    await backend.login();
    final s = ChatService(client: backend.client);
    expect(await s.misConversaciones(), isEmpty);
    ultimo = ultimo.add(const Duration(seconds: 1));
    expect(await s.misConversaciones(), hasLength(1));
  });

  test('creación de chat sin contexto y envío devuelven entidades', () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/iniciar_conversacion')) {
        expect(
            jsonDecode(r.body), {'p_id_producto': null, 'p_id_receptor': null});
        return jsonResponse('conversacion');
      }
      if (r.url.path.endsWith('/conversaciones')) {
        expect(r.method, 'GET');
        return jsonResponse(conversacionFila());
      }
      if (r.url.path.endsWith('/mensajes')) {
        expect(jsonDecode(r.body)['contenido'], 'Hola');
        return jsonResponse({
          'id': 'm',
          'id_conversacion': 'conversacion',
          'id_remitente': usuarioId,
          'contenido': 'Hola',
          'estado': 'enviado',
          'enviado_en': fecha
        });
      }
      return unexpected(r);
    });
    await backend.login();
    final s = ChatService(client: backend.client);
    final c = await Conversacion.iniciarConversacion(s);
    expect(
        (await Mensaje.enviarMensaje(s, c.idConversacion, '  Hola  ')).estado,
        'enviado');
    await expectLater(
        Mensaje.enviarMensaje(s, c.idConversacion, '  '), throwsArgumentError);
  });

  test(
      'reportes y apelaciones envían solo campos del usuario y aceptan reporte nulo',
      () async {
    backend = BackendFake((r) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body.containsKey('estado'), isFalse);
      expect(body.containsKey('resolucion'), isFalse);
      if (r.url.path.endsWith('/reportes')) {
        return jsonResponse(
            {...body, 'id': 'r', 'estado': 'pendiente', 'creado_en': fecha});
      }
      if (r.url.path.endsWith('/apelaciones')) {
        return jsonResponse(
            {...body, 'id': 'a', 'estado': 'pendiente', 'creada_en': fecha});
      }
      return unexpected(r);
    });
    await backend.login();
    final s = ConfianzaService(client: backend.client);
    expect(
        (await Reporte.crearReporte(s,
                tipo: 'producto',
                idReferencia: productoId,
                motivo: ' Revisar '))
            .motivo,
        'Revisar');
    expect((await Apelacion.solicitarRevision(s, motivo: 'Revisión')).idReporte,
        isNull);
  });

  test('visita y calificación recuperan estados y etiquetas de Toldo',
      () async {
    backend = BackendFake((r) {
      if (r.url.path.endsWith('/confirmar_visita')) {
        return jsonResponse('visita');
      }
      if (r.url.path.endsWith('/visitas')) {
        return jsonResponse({
          'id': 'visita',
          'id_usuario': usuarioId,
          'id_puesto': puestoId,
          'metodo_verificacion': 'codigo',
          'estado': 'verificada',
          'fecha_hora': fecha
        });
      }
      if (r.url.path.endsWith('/calificaciones')) {
        if (r.method == 'POST') return jsonResponse({'id': 'calificacion'});
        return jsonResponse({
          'id': 'calificacion',
          'id_visita': 'visita',
          'id_usuario': usuarioId,
          'id_puesto': puestoId,
          'id_vendedor': vendedorId,
          'puntuacion': 5,
          'creada_en': fecha,
          'calificacion_etiquetas': [
            {
              'etiquetas_valoracion': {'nombre': 'Amable'}
            }
          ]
        });
      }
      if (r.url.path.endsWith('/calificacion_etiquetas')) {
        return jsonResponse(null, status: 201);
      }
      return unexpected(r);
    });
    await backend.login();
    final s = PuestosService(client: backend.client);
    final v = await Visita.verificarVisita(s, '123456');
    expect(v.estado, 'verificada');
    final c = await Calificacion.registrarCalificacion(s,
        idVisita: v.idVisita, puntuacion: 5, idEtiquetas: ['etiqueta']);
    expect(c.etiquetas, ['Amable']);
    await expectLater(
        s.calificar(idVisita: v.idVisita, puntuacion: 6), throwsArgumentError);
  });

  test('puesto delega apertura/cierre y recupera el estado persistido',
      () async {
    backend = BackendFake(unexpected);
    final puerto = _PuestosFake();
    final puesto = Puesto.fromMap(puestoFila());
    expect((await puesto.marcarAbierto(puerto)).abierto, isTrue);
    expect((await puesto.marcarCerrado(puerto)).abierto, isFalse);
  });
}

class _PuestosFake implements OperacionesVendedor {
  String estado = 'cerrado';
  @override
  Future<String> abrirPuesto(String idPuesto) async {
    estado = 'abierto';
    return 'jornada';
  }

  @override
  Future<void> cerrarPuesto(String idPuesto) async {
    estado = 'cerrado';
  }

  @override
  Future<Puesto> puestoPorId(String idPuesto) async =>
      Puesto.fromMap({...puestoFila(), 'estado': estado});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
