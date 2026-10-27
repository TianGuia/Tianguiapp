import 'operaciones.dart';

class Visita {
  final String idVisita, idComprador, idPuesto, metodoVerificacion, estado;
  final DateTime fechaHora;
  Visita.fromMap(Map<String, dynamic> m)
      : idVisita = m['id'],
        idComprador = m['id_usuario'],
        idPuesto = m['id_puesto'],
        metodoVerificacion = m['metodo_verificacion'],
        estado = m['estado'],
        fechaHora = DateTime.parse(m['fecha_hora']);
  static Future<Visita> verificarVisita(
    OperacionesVisitas operaciones,
    String codigo,
  ) =>
      operaciones.verificarVisita(codigo);
}

class Calificacion {
  final String idCalificacion, idVisita, idComprador, idVendedor, idPuesto;
  final int puntuacion;
  final List<String> etiquetas;
  final String? comentario;
  final DateTime fechaCreacion;
  Calificacion.fromMap(Map<String, dynamic> m)
      : idCalificacion = m['id'],
        idVisita = m['id_visita'],
        idComprador = m['id_usuario'],
        idVendedor = m['id_vendedor'],
        idPuesto = m['id_puesto'],
        puntuacion = (m['puntuacion'] as num).toInt(),
        comentario = m['comentario'],
        fechaCreacion = DateTime.parse(m['creada_en']),
        etiquetas = List.unmodifiable([
          for (final e in (m['calificacion_etiquetas'] as List? ?? []))
            (e['etiquetas_valoracion'] as Map)['nombre'] as String,
        ]);
  static Future<Calificacion> registrarCalificacion(
    OperacionesVisitas operaciones, {
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) =>
      operaciones.calificar(
        idVisita: idVisita,
        puntuacion: puntuacion,
        comentario: comentario,
        idEtiquetas: idEtiquetas,
      );
}

class Reporte {
  final String idReporte, idUsuario, tipo, idReferencia, motivo, estado;
  final DateTime fechaCreacion;
  Reporte.fromMap(Map<String, dynamic> m)
      : idReporte = m['id'],
        idUsuario = m['id_reportante'],
        tipo = m['tipo_objetivo'],
        idReferencia = m['id_objetivo'],
        motivo = m['motivo'],
        estado = m['estado'],
        fechaCreacion = DateTime.parse(m['creado_en']);
  static Future<Reporte> crearReporte(
    OperacionesConfianza operaciones, {
    required String tipo,
    required String idReferencia,
    required String motivo,
    String? idUsuarioReportado,
  }) =>
      operaciones.reportar(
        tipoObjetivo: tipo,
        idObjetivo: idReferencia,
        motivo: motivo,
        idUsuarioReportado: idUsuarioReportado,
      );
}

class Apelacion {
  final String idApelacion, idUsuario, motivo, estado;
  final String? idReporte, resolucion;
  final DateTime fechaCreacion;
  Apelacion.fromMap(Map<String, dynamic> m)
      : idApelacion = m['id'],
        idReporte = m['id_reporte'],
        idUsuario = m['id_usuario'],
        motivo = m['motivo'],
        estado = m['estado'],
        resolucion = m['resolucion'],
        fechaCreacion = DateTime.parse(m['creada_en']);
  static Future<Apelacion> solicitarRevision(
    OperacionesConfianza operaciones, {
    String? idReporte,
    required String motivo,
  }) =>
      operaciones.solicitarRevision(idReporte: idReporte, motivo: motivo);
}
