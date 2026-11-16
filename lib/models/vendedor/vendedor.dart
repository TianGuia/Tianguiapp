import '../../services/vendedor_service.dart';

/// El ROL de quien opera un puesto.
///
/// Un Usuario se vuelve Vendedor al «habilitar su perfil» (verifica su correo).
/// Desde ahí puede registrar horarios, ausencias, puestos y productos. En la
/// base de datos es la tabla `perfiles_vendedor`.
class Vendedor {
  final String idVendedor, idUsuario, estado;
  final String? nombreNegocio, descripcion;
  final DateTime fechaHabilitacion;

  Vendedor.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id'],
        idUsuario = m['id_usuario'],
        nombreNegocio = m['nombre_negocio'],
        descripcion = m['descripcion'],
        estado = m['estado'].toString(),
        fechaHabilitacion = DateTime.parse(m['fecha_habilitacion']).toLocal();

  /// RF-19 · Activar el perfil de vendedor de la cuenta actual.
  static Future<String> habilitarPerfil({String? nombreNegocio, String? descripcion}) =>
      VendedorService().habilitarPerfil(nombreNegocio: nombreNegocio, descripcion: descripcion);

  /// RF-21 · Guardar el horario habitual en un tianguis (día, hora de inicio y fin).
  Future<void> registrarHorario(String idTianguis, int dia, String inicio, String fin) =>
      VendedorService().registrarHorario(idVendedor, idTianguis, dia, inicio, fin);

  /// RF-22 · Avisar con tiempo que ese día no va a llegar.
  Future<void> registrarAusencia(String idTianguis, DateTime fecha, {String? motivo}) =>
      VendedorService().registrarAusencia(idVendedor, idTianguis, fecha, motivo: motivo);
}
