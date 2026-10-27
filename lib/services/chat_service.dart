import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mensajeria.dart';
import '../models/tratos.dart';
import '../models/operaciones.dart';
import '../models/confianza.dart';
import 'confianza_service.dart';

/// RF-16, RF-17, RF-18, RF-37, RF-38.
class ChatService implements OperacionesChat {
  ChatService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;
  String get _uid => _db.auth.currentUser!.id;

  static const _select =
      '*, productos(nombre), participantes(id_conversacion, id_usuario)';

  @override
  Future<Conversacion> iniciarConversacion(
      {String? idProducto, String? idReceptor}) async {
    if (idReceptor == _uid) {
      throw ArgumentError('No puedes iniciar un chat contigo mismo');
    }
    final id = await _db.rpc('iniciar_conversacion', params: {
      'p_id_producto': idProducto,
      'p_id_receptor': idReceptor,
    }) as String;
    final r =
        await _db.from('conversaciones').select(_select).eq('id', id).single();
    return Conversacion.fromMap(r);
  }

  Future<List<Participante>> participantes(String idConversacion) async =>
      (await _db
              .from('participantes')
              .select()
              .eq('id_conversacion', idConversacion))
          .map(Participante.fromMap)
          .toList();

  Future<void> agregarParticipante(String idConversacion, String idUsuario) =>
      _db
          .from('participantes')
          .insert({'id_conversacion': idConversacion, 'id_usuario': idUsuario});

  Future<void> retirarParticipante(String idConversacion, String idUsuario) =>
      _db
          .from('participantes')
          .delete()
          .eq('id_conversacion', idConversacion)
          .eq('id_usuario', idUsuario);

  /// RF-16: abre (o reutiliza) la conversación de un producto con su vendedor.
  /// [idUsuarioVendedor] = perfiles_vendedor.id_usuario del dueño del producto.
  Future<String> conversacionDeProducto(
      String idProducto, String idUsuarioVendedor) async {
    final membresias = await _db
        .from('participantes')
        .select('id_conversacion')
        .eq('id_usuario', _uid);
    final ids = membresias.map((p) => p['id_conversacion'] as String).toList();
    if (ids.isNotEmpty) {
      final ya = await _db
          .from('conversaciones')
          .select(_select)
          .eq('id_producto', idProducto)
          .eq('estado', 'activa')
          .inFilter('id', ids)
          .order('creada_en', ascending: true);
      for (final fila in ya) {
        final c = Conversacion.fromMap(fila);
        if (c.participantes.length == 2 &&
            c.participantes.any((p) => p.idUsuario == idUsuarioVendedor)) {
          return c.idConversacion;
        }
      }
    }
    return (await iniciarConversacion(
            idProducto: idProducto, idReceptor: idUsuarioVendedor))
        .idConversacion;
  }

  /// Conversaciones que no he borrado. Una borrada reaparece sola si llega
  /// un mensaje nuevo después de borrarla.
  Future<List<Conversacion>> misConversaciones() async {
    final membresias = await _db
        .from('participantes')
        .select('id_conversacion')
        .eq('id_usuario', _uid);
    final ids = membresias.map((p) => p['id_conversacion'] as String).toList();
    if (ids.isEmpty) return [];
    final todas = await _db
        .from('conversaciones')
        .select(_select)
        .inFilter('id', ids)
        .order('ultimo_mensaje_en', ascending: false, nullsFirst: false);
    final ocultas = await _ocultas();
    return [
      for (final c in todas)
        if (!_estaOculta(c, ocultas[c['id']])) Conversacion.fromMap(c)
    ];
  }

  Future<Map<String, DateTime>> _ocultas() async {
    final r = await _db
        .from('conversaciones_ocultas')
        .select('id_conversacion, ocultada_en')
        .eq('id_usuario', _uid);
    return {
      for (final o in r)
        o['id_conversacion'] as String:
            DateTime.parse(o['ocultada_en'] as String)
    };
  }

  bool _estaOculta(Map<String, dynamic> c, DateTime? ocultadaEn) {
    if (ocultadaEn == null) return false;
    final ultimo = c['ultimo_mensaje_en'] as String?;
    return ultimo == null || !DateTime.parse(ultimo).isAfter(ocultadaEn);
  }

  /// Borra la conversación SOLO para mí (la otra persona la sigue viendo y
  /// el historial queda disponible para moderación).
  Future<void> borrarConversacion(String idConversacion) =>
      _db.rpc('ocultar_conversacion', params: {'p_id': idConversacion});

  /// Mensajes en tiempo real (Supabase Realtime).
  /// Llegan del más nuevo al más viejo; la pantalla usa ListView(reverse: true)
  /// para que el más nuevo quede abajo. Si borré la conversación antes,
  /// solo se muestran los mensajes posteriores al borrado.
  Stream<List<Mensaje>> mensajes(String idConversacion) async* {
    DateTime? desde;
    desde = (await _ocultas())[idConversacion];
    yield* _db
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('id_conversacion', idConversacion)
        .order('enviado_en', ascending: false)
        .map((l) => (desde == null
                ? l
                : l
                    .where((m) => DateTime.parse(m['enviado_en'] as String)
                        .isAfter(desde!))
                    .toList())
            .map(Mensaje.fromMap)
            .toList());
  }

  @override
  Future<Mensaje> enviar(String idConversacion, String texto) async {
    if (texto.trim().isEmpty) throw ArgumentError('Escribe un mensaje');
    return Mensaje.fromMap(await _db
        .from('mensajes')
        .insert({
          'id_conversacion': idConversacion,
          'id_remitente': _uid,
          'contenido': texto.trim(),
        })
        .select()
        .single());
  }

  /// RF-38
  Future<void> bloquear(String idUsuario) => _db.from('bloqueos').insert({
        'id_bloqueador': _uid,
        'id_bloqueado': idUsuario,
      });

  /// RF-17
  @override
  Future<Propuesta> proponerPrecio({
    required String idProducto,
    required String idVendedor,
    required num monto,
  }) async =>
      Propuesta.fromMap(await _db
          .from('propuestas_precio')
          .insert({
            'id_producto': idProducto,
            'id_comprador': _uid,
            'id_vendedor': idVendedor,
            'id_emisor': _uid,
            'monto': monto,
          })
          .select()
          .single());

  /// RF-18: apartado temporal (24 h por defecto).
  @override
  Future<Apartado> solicitarApartado({
    required String idProducto,
    required String idVendedor,
    int cantidad = 1,
    Duration vigencia = const Duration(hours: 24),
  }) async =>
      Apartado.fromMap(await _db
          .from('apartados')
          .insert({
            'id_producto': idProducto,
            'id_comprador': _uid,
            'id_vendedor': idVendedor,
            'cantidad': cantidad,
            'fecha_expiracion':
                DateTime.now().add(vigencia).toUtc().toIso8601String(),
          })
          .select()
          .single());

  /// RF-44
  Future<Reporte> reportar({
    required String tipoObjetivo,
    required String idObjetivo,
    String? idUsuarioReportado,
    required String motivo,
  }) =>
      ConfianzaService(client: _db).reportar(
          tipoObjetivo: tipoObjetivo,
          idObjetivo: idObjetivo,
          idUsuarioReportado: idUsuarioReportado,
          motivo: motivo);
}
