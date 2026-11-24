import 'package:supabase_flutter/supabase_flutter.dart';

// pide al administrador que revise otra vez una decision, tabla apelaciones
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

  // rf-46 se cumple aqui: la persona pide que el administrador revise otra vez una decision
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
