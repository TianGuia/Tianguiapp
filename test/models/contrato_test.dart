import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/models/identidad.dart';
import 'package:tianguia/models/modelos.dart';
import 'package:tianguia/models/tratos.dart';
import 'package:tianguia/models/confianza.dart';
import 'package:tianguia/models/mensajeria.dart';
import '../support/backend_fake.dart';

void main() {
  test(
      'especialización solapada conserva usuario y distingue el perfil vendedor',
      () {
    final c = Comprador.fromMap(
        {'id_comprador': usuarioId, 'usuarios': usuarioFila()});
    final v = Vendedor.fromMap(vendedorFila());
    expect(c, isA<Usuario>());
    expect(v, isA<Usuario>());
    expect(c.idUsuario, v.idUsuario);
    expect(c.idComprador, usuarioId);
    expect(v.idVendedor, isNot(v.idUsuario));
    expect(v.fechaHabilitacion, DateTime.parse(fecha));
    expect(c.correo, isNull);
  });
  test('producto con puesto obligatorio, imágenes ordenadas sin sesión global',
      () {
    final p = Producto.fromMap({
      ...productoFila(),
      'cantidad_disponible': null,
      'producto_imagenes': [
        {'id': 'b', 'ruta_storage': 'persona/foto dos.jpg', 'orden': 2},
        {'id': 'a', 'ruta_storage': 'persona/primera.jpg', 'orden': 0},
      ]
    });
    expect(p.idPuesto, puestoId);
    expect(p.disponibilidad, isNull);
    expect(p.precioReferencia, 100);
    expect(p.imagenes.first, endsWith('/persona/primera.jpg'));
    expect(p.fotos.last.url, endsWith('/persona/foto%20dos.jpg'));
    expect(() => Producto.fromMap({...productoFila(), 'id_puesto': null}),
        throwsA(isA<TypeError>()));
  });
  test('puesto incluye fecha de cierre y ubicación', () {
    final p = Puesto.fromMap({
      ...puestoFila(),
      'latitud': 19.4,
      'longitud': -99.1,
      'fecha_cierre': fecha
    });
    expect(p.idPuesto, puestoId);
    expect(p.fechaCierre, DateTime.parse(fecha));
    expect(p.ubicacion, '19.4,-99.1');
  });
  test('oferta pertenece a un producto y respeta inicio, fin y estado', () {
    expect(Oferta.fromMap(ofertaFila()).vigente, isTrue);
    expect(
        Oferta.fromMap(
            {...ofertaFila(), 'fecha_inicio': '2098-01-01T00:00:00Z'}).vigente,
        isFalse);
    expect(
        Oferta.fromMap({...ofertaFila(), 'fecha_fin': fecha}).vigente, isFalse);
    expect(Oferta.fromMap({...ofertaFila(), 'estado': 'finalizada'}).vigente,
        isFalse);
    expect(Oferta.fromMap(ofertaFila()).item.precioFinal, 80);
  });
  test('apartado conserva fechas y nombre desde comprador → usuario', () {
    final a = Apartado.fromMap(apartadoFila());
    expect(a.compradorNombre, 'Persona');
    expect(a.fechaInicio, DateTime.parse(fecha));
    expect(a.fechaExpiracion, isNotNull);
  });
  test('conversación sin producto y con tres participantes', () {
    final c = Conversacion.fromMap(conversacionFila());
    expect(c.idProducto, isNull);
    expect(c.participantes, hasLength(3));
    expect(c.fechaCreacion, DateTime.parse(fecha));
    expect(() => c.participantes.clear(), throwsUnsupportedError);
    final m = Mensaje.fromMap({
      'id': 'm',
      'id_conversacion': c.idConversacion,
      'id_remitente': usuarioId,
      'contenido': 'Hola',
      'estado': 'leido',
      'enviado_en': fecha
    });
    expect(m.estado, 'leido');
  });
  test('visitas, calificaciones, reportes y apelaciones mapean el contrato',
      () {
    final v = Visita.fromMap({
      'id': 'v',
      'id_usuario': usuarioId,
      'id_puesto': puestoId,
      'fecha_hora': fecha,
      'metodo_verificacion': 'codigo',
      'estado': 'verificada'
    });
    expect(v.idComprador, usuarioId);
    final c = Calificacion.fromMap({
      'id': 'c',
      'id_visita': 'v',
      'id_usuario': usuarioId,
      'id_vendedor': vendedorId,
      'id_puesto': puestoId,
      'puntuacion': 5,
      'creada_en': fecha,
      'calificacion_etiquetas': [
        {
          'etiquetas_valoracion': {'nombre': 'Amable'}
        }
      ]
    });
    expect(c.etiquetas, ['Amable']);
    final r = Reporte.fromMap({
      'id': 'r',
      'id_reportante': usuarioId,
      'tipo_objetivo': 'producto',
      'id_objetivo': productoId,
      'motivo': 'Motivo',
      'estado': 'pendiente',
      'creado_en': fecha
    });
    expect(r.idReferencia, productoId);
    final a = Apelacion.fromMap({
      'id': 'a',
      'id_usuario': usuarioId,
      'id_reporte': null,
      'motivo': 'Revisar',
      'estado': 'pendiente',
      'creada_en': fecha,
      'resolucion': null
    });
    expect(a.idReporte, isNull);
    expect(a.resolucion, isNull);
  });
  test('tianguis conserva horarios normalizados y datos cartográficos', () {
    final t = Tianguis.fromMap({
      'id': 't',
      'nombre': 'Tianguis',
      'activo': true,
      'direccion': 'Centro',
      'tianguis_horarios': [
        {'dia_semana': 1, 'hora_inicio': '08:00', 'hora_fin': '16:00'}
      ]
    });
    expect(t.estado, 'activo');
    expect(t.ubicacion, 'Centro');
    expect(t.diasOperacion, '1');
    expect(t.horarioGeneral, contains('08:00'));
  });
}
