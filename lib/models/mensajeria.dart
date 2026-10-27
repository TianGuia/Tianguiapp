import 'operaciones.dart';

class Participante {
  final String idConversacion, idUsuario;
  Participante.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id_conversacion'],
        idUsuario = m['id_usuario'];
}

class Conversacion {
  final String idConversacion, estado;
  final String? idProducto, productoNombre;
  final DateTime fechaCreacion;
  final DateTime? ultimoMensajeEn;
  final List<Participante> participantes;
  Conversacion.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id'],
        estado = m['estado'],
        idProducto = m['id_producto'],
        productoNombre = (m['productos'] as Map?)?['nombre'],
        fechaCreacion = DateTime.parse(m['creada_en']),
        ultimoMensajeEn = m['ultimo_mensaje_en'] == null
            ? null
            : DateTime.parse(m['ultimo_mensaje_en']),
        participantes = List.unmodifiable([
          for (final p in (m['participantes'] as List? ?? []))
            Participante.fromMap(p),
        ]);
  static Future<Conversacion> iniciarConversacion(
    OperacionesChat operaciones, {
    String? idProducto,
    String? idReceptor,
  }) =>
      operaciones.iniciarConversacion(
        idProducto: idProducto,
        idReceptor: idReceptor,
      );
}

class Mensaje {
  final String idMensaje, idConversacion, idRemitente, contenido, estado;
  final DateTime fechaEnvio;
  Mensaje.fromMap(Map<String, dynamic> m)
      : idMensaje = m['id'],
        idConversacion = m['id_conversacion'],
        idRemitente = m['id_remitente'],
        contenido = m['contenido'],
        estado = m['estado'],
        fechaEnvio = DateTime.parse(m['enviado_en']);
  static Future<Mensaje> enviarMensaje(
    OperacionesChat operaciones,
    String idConversacion,
    String contenido,
  ) =>
      operaciones.enviar(idConversacion, contenido);
}
