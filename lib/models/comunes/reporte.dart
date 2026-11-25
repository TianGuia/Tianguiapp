import '../../services/chat_service.dart';

// aviso de que algo rompe las reglas, lo revisa el administrador, tabla reportes
class Reporte {
  final String idReporte, idUsuario, tipo, idReferencia, motivo, estado;
  final DateTime fechaCreacion;

  Reporte.fromMap(Map<String, dynamic> m)
      : idReporte = m['id'],
        idUsuario = m['id_reportante'],
        tipo = m['tipo_objetivo'].toString(),
        idReferencia = m['id_objetivo'],
        motivo = m['motivo'],
        estado = m['estado'].toString(),
        fechaCreacion = DateTime.parse(m['creado_en']).toLocal();

  // RF-44 se cumple aqui: se manda un reporte cuando algo rompe las reglas
  static Future<void> crearReporte({
    required String tipoObjetivo,
    required String idObjetivo,
    String? idUsuarioReportado,
    required String motivo,
  }) =>
      ChatService().crearReporte(
        tipoObjetivo: tipoObjetivo,
        idObjetivo: idObjetivo,
        idUsuarioReportado: idUsuarioReportado,
        motivo: motivo,
      );
}
