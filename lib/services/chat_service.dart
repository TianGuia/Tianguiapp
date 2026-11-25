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

  // nombre y foto publicos de otras personas, si la consulta falla regresa vacio
  Future<Map<String, ({String nombre, String? foto})>> perfilesPublicos(Iterable<String> ids) async {
    final l = ids.toSet().toList();
    if (l.isEmpty) return {};
    try {
      final r = await _db
          .from('perfiles_publicos')
          .select('id, nombre_publico, foto_url')
          .inFilter('id', l);
      return {
        for (final u in r)
          u['id'] as String: (
            nombre: (u['nombre_publico'] ?? '') as String,
            foto: u['foto_url'] as String?,
          )
      };
    } catch (_) {
      return {};
    }
  }

  // el ultimo mensaje de cada conversacion para la lista, si falla la lista sale sin vista previa
  Future<Map<String, Map<String, dynamic>>> ultimosMensajes(Iterable<String> ids) async {
    final l = ids.toList();
    if (l.isEmpty) return {};
    try {
      final r = await _db
          .from('mensajes')
          .select('id_conversacion, id_remitente, contenido, enviado_en')
          .inFilter('id_conversacion', l)
          .order('enviado_en', ascending: false)
          .limit(300);
      final salida = <String, Map<String, dynamic>>{};
      for (final m in r) {
        salida.putIfAbsent(m['id_conversacion'] as String, () => Map<String, dynamic>.from(m));
      }
      return salida;
    } catch (_) {
      return {};
    }
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
