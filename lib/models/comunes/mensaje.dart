import '../../services/chat_service.dart';

// un mensaje dentro de una conversacion, tabla mensajes
class Mensaje {
  final String idMensaje, idConversacion, idRemitente, contenido;
  final String? estado;
  final DateTime fechaEnvio;

  Mensaje.fromMap(Map<String, dynamic> m)
      : idMensaje = m['id'],
        idConversacion = m['id_conversacion'],
        idRemitente = m['id_remitente'],
        contenido = m['contenido'],
        estado = m['estado'],
        fechaEnvio = DateTime.parse(m['enviado_en']).toLocal();

  // rf-37 se cumple aqui: las dos personas del chat mandan y reciben mensajes
  static Future<void> enviarMensaje(String idConversacion, String texto) =>
      ChatService().enviarMensaje(idConversacion, texto);
}
