import '../../services/chat_service.dart';

/// Aviso de que algo (un perfil, publicación, mensaje o valoración) rompe las
/// reglas. Lo revisa el administrador. Tabla `reportes`.
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

  /// RF-44 · Enviar el reporte con su motivo.
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
