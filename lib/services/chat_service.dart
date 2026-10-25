import 'package:supabase_flutter/supabase_flutter.dart';

/// RF-16, RF-17, RF-18, RF-37, RF-38.
class ChatService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  /// RF-16: abre (o reutiliza) la conversación de un producto con su vendedor.
  /// [idUsuarioVendedor] = perfiles_vendedor.id_usuario del dueño del producto.
  Future<String> conversacionDeProducto(String idProducto, String idUsuarioVendedor) async {
    final ya = await _db
        .from('conversaciones')
        .select('id')
        .eq('id_producto', idProducto)
        .eq('id_iniciador', _uid)
        .eq('id_receptor', idUsuarioVendedor)
        .maybeSingle();
    if (ya != null) return ya['id'];
    final r = await _db.from('conversaciones').insert({
      'contexto': 'producto',
      'id_producto': idProducto,
      'id_iniciador': _uid,
      'id_receptor': idUsuarioVendedor,
    }).select('id').single();
    return r['id'];
  }

  Future<List<Map<String, dynamic>>> misConversaciones() => _db
      .from('conversaciones')
      .select('*, productos(nombre)')
      .or('id_iniciador.eq.$_uid,id_receptor.eq.$_uid')
      .order('ultimo_mensaje_en', ascending: false, nullsFirst: false);

  /// Mensajes en tiempo real (Supabase Realtime).
  Stream<List<Map<String, dynamic>>> mensajes(String idConversacion) => _db
      .from('mensajes')
      .stream(primaryKey: ['id'])
      .eq('id_conversacion', idConversacion)
      .order('enviado_en');

  Future<void> enviar(String idConversacion, String texto) =>
      _db.from('mensajes').insert({
        'id_conversacion': idConversacion,
        'id_remitente': _uid,
        'contenido': texto.trim(),
      });

  /// RF-38
  Future<void> bloquear(String idUsuario) => _db.from('bloqueos').insert({
        'id_bloqueador': _uid, 'id_bloqueado': idUsuario,
      });

  /// RF-17
  Future<void> proponerPrecio({
    required String idProducto, required String idVendedor, required num monto,
  }) => _db.from('propuestas_precio').insert({
        'id_producto': idProducto, 'id_comprador': _uid, 'id_vendedor': idVendedor,
        'id_emisor': _uid, 'monto': monto,
      });

  /// RF-18: apartado temporal (24 h por defecto).
  Future<void> solicitarApartado({
    required String idProducto, required String idVendedor, int cantidad = 1,
    Duration vigencia = const Duration(hours: 24),
  }) => _db.from('apartados').insert({
        'id_producto': idProducto, 'id_comprador': _uid, 'id_vendedor': idVendedor,
        'cantidad': cantidad,
        'fecha_expiracion': DateTime.now().add(vigencia).toUtc().toIso8601String(),
      });

  /// RF-44
  Future<void> reportar({
    required String tipoObjetivo, required String idObjetivo,
    String? idUsuarioReportado, required String motivo,
  }) => _db.from('reportes').insert({
        'id_reportante': _uid, 'tipo_objetivo': tipoObjetivo, 'id_objetivo': idObjetivo,
        'id_usuario_reportado': idUsuarioReportado, 'motivo': motivo,
      });
}
