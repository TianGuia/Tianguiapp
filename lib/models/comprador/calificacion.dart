import '../../services/puestos_service.dart';

// la opinion que deja el comprador despues de una visita confirmada, tabla calificaciones
class Calificacion {
  final String idCalificacion, idComprador, idPuesto, idVendedor;
  final int puntuacion;
  final String? comentario;
  final List<String> etiquetas;
  final DateTime fechaCreacion;

  Calificacion.fromMap(Map<String, dynamic> m)
      : idCalificacion = m['id'],
        idComprador = m['id_usuario'],
        idPuesto = m['id_puesto'],
        idVendedor = m['id_vendedor'],
        puntuacion = (m['puntuacion'] as num).toInt(),
        comentario = m['comentario'],
        etiquetas = [
          for (final e in (m['calificacion_etiquetas'] as List? ?? const []))
            ((e['etiquetas_valoracion'] as Map?)?['nombre'] ?? '').toString()
        ]..removeWhere((e) => e.isEmpty),
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  // RF-42 se cumple aqui: despues de una visita confirmada el comprador deja su calificacion
  static Future<void> registrarCalificacion({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) =>
      PuestosService().registrarCalificacion(
        idVisita: idVisita,
        puntuacion: puntuacion,
        comentario: comentario,
        idEtiquetas: idEtiquetas,
      );
}
