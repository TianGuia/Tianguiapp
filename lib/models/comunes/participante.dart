/// Dice qué usuarios están dentro de cada conversación (tabla `participantes`).
///
/// Es una «entidad asociativa»: no tiene datos propios, solo une un Usuario con
/// una Conversación. Su llave son los dos ids juntos.
class Participante {
  final String idConversacion, idUsuario;

  Participante.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id_conversacion'],
        idUsuario = m['id_usuario'];
}
