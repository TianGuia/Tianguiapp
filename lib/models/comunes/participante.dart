// dice que usuarios estan en cada conversacion, tabla participantes
class Participante {
  final String idConversacion, idUsuario;

  Participante.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id_conversacion'],
        idUsuario = m['id_usuario'];
}
