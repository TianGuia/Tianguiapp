import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/enums.dart';
import 'comprador_id.dart';

/// RF-16, RF-17, RF-18, RF-37, RF-38.
class ChatService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  /// RF-16 / RF-35: abre (o reutiliza) una conversación. Se origina en un
  /// producto ([idProducto]) o en un anuncio de espacio ([idAnuncio]).
  /// [idUsuarioReceptor] = id_usuario del dueño del producto o del anuncio.
  Future<String> iniciarConversacion({
    String? idProducto,
    String? idAnuncio,
    required String idUsuarioReceptor,
  }) async {
    assert((idProducto == null) != (idAnuncio == null),
        'Indica idProducto o idAnuncio, solo uno');
    final esProducto = idProducto != null;
    final columna = esProducto ? 'id_producto' : 'id_anuncio_espacio';
    final origen = (esProducto ? idProducto : idAnuncio)!;
    final ya = await _db
        .from('conversaciones')
        .select('id')
        .eq(columna, origen)
        .eq('id_iniciador', _uid)
        .eq('id_receptor', idUsuarioReceptor)
        .maybeSingle();
    if (ya != null) return ya['id'];
    // El id se genera aquí y el insert NO pide la fila de vuelta: conv_select
    // exige participa_en(id) y el trigger conversaciones_participantes registra
    // a los participantes DESPUÉS del insert, así que insert(...).select()
    // fallaba con 42501.
    final id = _uuidV4();
    await _db.from('conversaciones').insert({
      'id': id,
      'contexto': esProducto ? Enums.contextoProducto : Enums.contextoEspacio,
      columna: origen,
      'id_iniciador': _uid,
      'id_receptor': idUsuarioReceptor,
    });
    return id;
  }

  static String _uuidV4() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-'
        '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }

  /// Conversaciones que no he borrado. Una borrada reaparece sola si llega
  /// un mensaje nuevo después de borrarla.
  Future<List<Map<String, dynamic>>> misConversaciones() async {
    final todas = await _db
        .from('conversaciones')
        .select('*, productos(nombre), anuncios_espacio(titulo)')
        .or('id_iniciador.eq.$_uid,id_receptor.eq.$_uid')
        .order('ultimo_mensaje_en', ascending: false, nullsFirst: false);
    final ocultas = await _ocultas();
    return [
      for (final c in todas)
        if (!_estaOculta(c, ocultas[c['id']])) c
    ];
  }

  Future<Map<String, DateTime>> _ocultas() async {
    final r = await _db
        .from('conversaciones_ocultas')
        .select('id_conversacion, ocultada_en')
        .eq('id_usuario', _uid);
    return {
      for (final o in r)
        o['id_conversacion'] as String: DateTime.parse(o['ocultada_en'] as String)
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
  Stream<List<Map<String, dynamic>>> mensajes(String idConversacion) async* {
    DateTime? desde;
    try {
      desde = (await _ocultas())[idConversacion];
    } catch (_) {}
    yield* _db
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('id_conversacion', idConversacion)
        .order('enviado_en', ascending: false)
        .map((l) => desde == null
            ? l
            : l.where((m) => DateTime.parse(m['enviado_en'] as String).isAfter(desde!)).toList());
  }

  Future<void> enviarMensaje(String idConversacion, String texto) =>
      _db.from('mensajes').insert({
        'id_conversacion': idConversacion,
        'id_remitente': _uid,
        'contenido': texto.trim(),
      });

  /// Id del otro participante de la conversación (para bloquear o reportar).
  Future<String?> otroParticipante(String idConversacion) async {
    final c = await _db
        .from('conversaciones')
        .select('id_iniciador, id_receptor')
        .eq('id', idConversacion)
        .maybeSingle();
    if (c == null) return null;
    return c['id_iniciador'] == _uid ? c['id_receptor'] as String? : c['id_iniciador'] as String?;
  }

  /// RF-38: ¿ya bloqueé a este usuario? (solo cuenta el bloqueo activo)
  Future<bool> estaBloqueado(String idUsuario) async {
    final r = await _db
        .from('bloqueos')
        .select('id')
        .eq('id_bloqueador', _uid)
        .eq('id_bloqueado', idUsuario)
        .eq('activo', true)
        .limit(1);
    return (r as List).isNotEmpty;
  }

  /// RF-38: quita el bloqueo (queda registrado como inactivo).
  Future<void> desbloquear(String idUsuario) => _db
      .from('bloqueos')
      .update({'activo': false})
      .eq('id_bloqueador', _uid)
      .eq('id_bloqueado', idUsuario);

  /// RF-38: bloquea; si ya hubo un bloqueo previo lo reactiva.
  Future<void> bloquear(String idUsuario) async {
    final ya = await _db
        .from('bloqueos')
        .select('id')
        .eq('id_bloqueador', _uid)
        .eq('id_bloqueado', idUsuario)
        .limit(1);
    if ((ya as List).isNotEmpty) {
      await _db.from('bloqueos').update({'activo': true}).eq('id', ya.first['id']);
    } else {
      await _db.from('bloqueos').insert({'id_bloqueador': _uid, 'id_bloqueado': idUsuario});
    }
  }

  /// RF-17
  Future<void> proponerPrecio({
    required String idProducto, required String idVendedor, required num monto,
  }) async {
    await _db.from('propuestas_precio').insert({
      'id_producto': idProducto, 'id_comprador': await miIdComprador(), 'id_vendedor': idVendedor,
      'id_emisor': _uid, 'monto': monto,
    });
  }

  /// RF-18: apartado temporal (24 h por defecto).
  Future<void> solicitarApartado({
    required String idProducto, required String idVendedor, int cantidad = 1,
    Duration vigencia = const Duration(hours: 24),
  }) async {
    await _db.from('apartados').insert({
      'id_producto': idProducto, 'id_comprador': await miIdComprador(), 'id_vendedor': idVendedor,
      'cantidad': cantidad,
      'fecha_expiracion': DateTime.now().add(vigencia).toUtc().toIso8601String(),
    });
  }

  /// RF-44
  Future<void> crearReporte({
    required String tipoObjetivo, required String idObjetivo,
    String? idUsuarioReportado, required String motivo,
  }) => _db.from('reportes').insert({
        'id_reportante': _uid, 'tipo_objetivo': tipoObjetivo, 'id_objetivo': idObjetivo,
        'id_usuario_reportado': idUsuarioReportado, 'motivo': motivo,
      });
}
