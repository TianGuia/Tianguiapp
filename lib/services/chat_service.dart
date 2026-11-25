import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/enums.dart';
import 'comprador_id.dart';

// rf-38 se cumple aqui: se revisa si ya bloquee a esta persona
class ChatService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  // rf-11 se cumple aqui: el comprador abre un chat privado con el vendedor desde un producto
  // rf-30 se cumple aqui: el vendedor abre un chat con otro vendedor desde un anuncio
  // idUsuarioReceptor es el dueño del producto o del anuncio
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
    // el id se genera aqui y el insert no pide la fila de vuelta
    // porque conv_select exige participa_en y el trigger agrega a los participantes
    // despues del insert. antes con select fallaba con 42501
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

  // conversaciones que no he borrado, una borrada vuelve a salir si llega mensaje nuevo
  // cada una trae otro_nombre (la otra persona), producto_nombre o anuncio_titulo,
  // ultimo_texto y no_leidos. Sale de la funcion mis_conversaciones de Toldo;
  // si todavia no existe en la base se usa la consulta basica (sin nombre de la persona)
  Future<List<Map<String, dynamic>>> misConversaciones() async {
    List<Map<String, dynamic>> todas;
    try {
      final r = await _db.rpc('mis_conversaciones');
      todas = [for (final c in (r as List)) Map<String, dynamic>.from(c as Map)];
    } catch (_) {
      todas = await _conversacionesBasicas();
    }
    final ocultas = await _ocultas();
    return [
      for (final c in todas)
        if (!_estaOculta(c, ocultas[c['id']])) c
    ];
  }

  // total de mensajes sin leer, para la insignia de la barra inferior
  Future<int> totalNoLeidos() async {
    final todas = await misConversaciones();
    return todas.fold<int>(0, (t, c) => t + ((c['no_leidos'] as num?)?.toInt() ?? 0));
  }

  Future<List<Map<String, dynamic>>> _conversacionesBasicas() async {
    final r = await _db
        .from('conversaciones')
        .select('*, productos(nombre), anuncios_espacio(titulo)')
        .or('id_iniciador.eq.$_uid,id_receptor.eq.$_uid')
        .order('ultimo_mensaje_en', ascending: false, nullsFirst: false);
    return [
      for (final c in r)
        {
          ...Map<String, dynamic>.from(c),
          'producto_nombre': (c['productos'] as Map?)?['nombre'],
          'anuncio_titulo': (c['anuncios_espacio'] as Map?)?['titulo'],
          'no_leidos': 0,
        }
    ];
  }

  // datos de una conversacion (nombre de la otra persona y de que trata)
  Future<Map<String, dynamic>?> infoConversacion(String id) async {
    try {
      final r = await _db.rpc('mis_conversaciones');
      for (final c in (r as List)) {
        if (c['id'] == id) return Map<String, dynamic>.from(c as Map);
      }
    } catch (_) {} // sin la funcion se queda el titulo que ya traia la pantalla
    return null;
  }

  // nombre que se muestra de una conversacion: la persona; si no se sabe, el producto o anuncio
  static String tituloDe(Map<String, dynamic> c) {
    final otro = (c['otro_nombre'] as String?)?.trim();
    if (otro != null && otro.isNotEmpty) return otro;
    return '${c['producto_nombre'] ?? c['anuncio_titulo'] ?? 'Conversación'}';
  }

  // de que trata la conversacion, solo cuando arriba se muestra a la persona
  static String? asuntoDe(Map<String, dynamic> c) {
    final otro = (c['otro_nombre'] as String?)?.trim();
    if (otro == null || otro.isEmpty) return null;
    final a = c['producto_nombre'] ?? c['anuncio_titulo'];
    return a == null ? null : '$a';
  }

  // marca como leidos los mensajes que me mandaron en esta conversacion
  Future<void> marcarLeidos(String idConversacion) async {
    try {
      await _db
          .from('mensajes')
          .update({'leido_en': DateTime.now().toUtc().toIso8601String()})
          .eq('id_conversacion', idConversacion)
          .neq('id_remitente', _uid)
          .isFilter('leido_en', null);
    } catch (_) {} // si falla solo no baja el contador
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

  // borra la conversacion solo para mi, la otra persona la sigue viendo
  Future<void> borrarConversacion(String idConversacion) =>
      _db.rpc('ocultar_conversacion', params: {'p_id': idConversacion});

  // mensajes en tiempo real con supabase realtime
  // llegan del mas nuevo al mas viejo y la pantalla usa reverse
  // si borre la conversacion solo salen los posteriores
  Stream<List<Map<String, dynamic>>> mensajes(String idConversacion) async* {
    DateTime? desde;
    try {
      desde = (await _ocultas())[idConversacion];
    } catch (_) {} // sin esto se muestran todos los mensajes
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

  Future<String?> otroParticipante(String idConversacion) async {
    final c = await _db
        .from('conversaciones')
        .select('id_iniciador, id_receptor')
        .eq('id', idConversacion)
        .maybeSingle();
    if (c == null) return null;
    return c['id_iniciador'] == _uid ? c['id_receptor'] as String? : c['id_iniciador'] as String?;
  }

  // rf-38 se cumple aqui: se quita el bloqueo
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

  // rf-38 se cumple aqui: se bloquea a la persona y ya no se pueden mandar mensajes
  Future<void> desbloquear(String idUsuario) => _db
      .from('bloqueos')
      .update({'activo': false})
      .eq('id_bloqueador', _uid)
      .eq('id_bloqueado', idUsuario);

  // rf-38 se cumple aqui: se puede bloquear a alguien y ya no se pueden mandar mensajes
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

  // rf-12 se cumple aqui: el comprador manda el precio que propone por un producto
  Future<void> proponerPrecio({
    required String idProducto, required String idVendedor, required num monto,
  }) async {
    await _db.from('propuestas_precio').insert({
      'id_producto': idProducto, 'id_comprador': await miIdComprador(), 'id_vendedor': idVendedor,
      'id_emisor': _uid, 'monto': monto,
    });
  }

  // rf-13 se cumple aqui: el comprador pide apartar un producto sin pagar dentro de la app
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

  // rf-44 se cumple aqui: se manda un reporte cuando algo rompe las reglas
  Future<void> crearReporte({
    required String tipoObjetivo, required String idObjetivo,
    String? idUsuarioReportado, required String motivo,
  }) => _db.from('reportes').insert({
        'id_reportante': _uid, 'tipo_objetivo': tipoObjetivo, 'id_objetivo': idObjetivo,
        'id_usuario_reportado': idUsuarioReportado, 'motivo': motivo,
      });
}
