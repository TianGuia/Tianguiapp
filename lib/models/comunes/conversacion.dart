import '../../services/chat_service.dart';

/// Un chat privado entre dos personas.
///
/// Nace desde un producto (comprador con vendedor) o desde un anuncio de espacio
/// (vendedor con vendedor). Tabla `conversaciones`.
class Conversacion {
  final String idConversacion, estado;
  final String? contexto, idProducto, idAnuncioEspacio;
  final DateTime fechaCreacion;

  Conversacion.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id'],
        estado = m['estado'],
        contexto = m['contexto']?.toString(),
        idProducto = m['id_producto'],
        idAnuncioEspacio = m['id_anuncio_espacio'],
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  /// RF-16 / RF-35 · Abrir el chat; si ya existía uno, devuelve ese mismo.
  static Future<String> iniciarConversacion({
    String? idProducto,
    String? idAnuncio,
    required String idUsuarioReceptor,
  }) =>
      ChatService().iniciarConversacion(
        idProducto: idProducto,
        idAnuncio: idAnuncio,
        idUsuarioReceptor: idUsuarioReceptor,
      );
}
