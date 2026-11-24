import '../../services/vendedor_service.dart';

// el rol de quien opera un puesto, tabla perfiles_vendedor
// un usuario se vuelve vendedor cuando activa su perfil
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

  // rf-14 se cumple aqui: la persona activa su perfil de vendedor
  static Future<String> habilitarPerfil({String? nombreNegocio, String? descripcion}) =>
      VendedorService().habilitarPerfil(nombreNegocio: nombreNegocio, descripcion: descripcion);

  // rf-16 se cumple aqui: el vendedor guarda que dias y a que hora trabaja
  Future<void> registrarHorario(String idTianguis, int dia, String inicio, String fin) =>
      VendedorService().registrarHorario(idVendedor, idTianguis, dia, inicio, fin);

  // rf-17 se cumple aqui: el vendedor avisa con tiempo que un dia no va a ir
  Future<void> registrarAusencia(String idTianguis, DateTime fecha, {String? motivo}) =>
      VendedorService().registrarAusencia(idVendedor, idTianguis, fecha, motivo: motivo);
}
