import '../../services/chat_service.dart';

// un chat privado entre dos personas, tabla conversaciones
// nace desde un producto o desde un anuncio de espacio
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

  // rf-16 se cumple aqui: el comprador abre un chat privado con el vendedor desde un producto
  // rf-35 se cumple aqui: el vendedor abre un chat con otro vendedor desde un anuncio
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
