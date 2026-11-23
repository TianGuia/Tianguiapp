import '../../services/puestos_service.dart';

// confirma que el comprador si estuvo en el puesto, tabla visitas
// sin visita confirmada no se puede calificar, asi no hay opiniones falsas
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

  // rf-41 se cumple aqui: el comprador escribe el codigo que le da el vendedor para confirmar que si fue al puesto
  static Future<String> verificarVisita(String codigo) => PuestosService().verificarVisita(codigo);
}
