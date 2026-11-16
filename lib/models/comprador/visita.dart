import '../../services/puestos_service.dart';

/// La confirmación de que el comprador SÍ estuvo en un puesto.
///
/// El vendedor le muestra un código y el comprador lo escribe. Solo con una
/// visita confirmada se puede dejar una calificación (así se evitan opiniones
/// falsas). Tabla `visitas`.
class Visita {
  final String idVisita, idComprador, idPuesto, metodoVerificacion, estado;
  final String? idJornada;
  final DateTime fechaHora;

  Visita.fromMap(Map<String, dynamic> m)
      : idVisita = m['id'],
        idComprador = m['id_usuario'],
        idPuesto = m['id_puesto'],
        idJornada = m['id_jornada'],
        metodoVerificacion = m['metodo_verificacion'],
        estado = m['estado'],
        fechaHora = DateTime.parse(m['fecha_hora']).toLocal();

  /// RF-41 · Validar el código del vendedor; devuelve el id de la visita creada.
  static Future<String> verificarVisita(String codigo) => PuestosService().verificarVisita(codigo);
}
