import 'package:supabase_flutter/supabase_flutter.dart';

/// Petición para que el administrador vuelva a revisar una decisión
/// (una medida aplicada, un reporte o una calificación). Tabla `apelaciones`.
class Apelacion {
  final String idApelacion, idUsuario, motivo, estado;
  final String? idReporte, resolucion;
  final DateTime fechaCreacion;

  Apelacion.fromMap(Map<String, dynamic> m)
      : idApelacion = m['id'],
        idUsuario = m['id_usuario'],
        idReporte = m['id_reporte'],
        motivo = m['motivo'],
        estado = m['estado'].toString(),
        resolucion = m['resolucion']?.toString(),
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  /// RF-46 · Pedir la revisión. Se manda solo UNO de: idMedida, idReporte o idCalificacion.
  static Future<void> solicitarRevision({
    String? idMedida,
    String? idReporte,
    String? idCalificacion,
    required String motivo,
  }) {
    final db = Supabase.instance.client;
    return db.from('apelaciones').insert({
      'id_usuario': db.auth.currentUser!.id,
      'id_medida': idMedida,
      'id_reporte': idReporte,
      'id_calificacion': idCalificacion,
      'motivo': motivo,
    });
  }
}
