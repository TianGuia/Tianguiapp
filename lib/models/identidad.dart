import 'modelos.dart';
import 'operaciones.dart';
import 'tratos.dart';

class Usuario {
  final String idUsuario, nombre, estadoCuenta;
  final String? correo, telefono, fotoPerfil;
  final DateTime fechaRegistro;

  Usuario.fromMap(Map<String, dynamic> m)
      : idUsuario = m['id'],
        nombre = m['nombre_publico'],
        correo = m['correo'],
        telefono = m['telefono'],
        fotoPerfil = m['foto_url'],
        estadoCuenta = m['estado_cuenta'],
        fechaRegistro = DateTime.parse(m['creado_en']);

  static Future<Usuario> registrar(
    OperacionesUsuario operaciones,
    String nombre,
  ) async {
    await operaciones.entrarAnonimo(nombre);
    return await operaciones.miPerfil() ??
        (throw StateError('No existe el perfil de usuario'));
  }

  /// El código se solicita mediante el flujo OTP antes de confirmar el acceso.
  static Future<Usuario> iniciarSesion(
    OperacionesUsuario operaciones,
    String correo,
    String codigo,
  ) async {
    await operaciones.verificarCodigo(correo, codigo);
    return await operaciones.miPerfil() ??
        (throw StateError('No existe el perfil de usuario'));
  }

  Future<Usuario> actualizarPerfil(
    OperacionesUsuario operaciones, {
    String? nombre,
    String? telefono,
    String? fotoPerfil,
  }) async {
    await operaciones.actualizarPerfil(
      nombre: nombre,
      telefono: telefono,
      fotoUrl: fotoPerfil,
    );
    return await operaciones.miPerfil() ??
        (throw StateError('No existe el perfil de usuario'));
  }
}

/// El UUID del comprador coincide con el del usuario, según Toldo.
class Comprador extends Usuario {
  final String idComprador;
  Comprador.fromMap(Map<String, dynamic> m)
      : idComprador = m['id_comprador'],
        super.fromMap(Map<String, dynamic>.from(m['usuarios'] as Map));

  Future<List<Producto>> buscarProductos(
    OperacionesCatalogo operaciones,
    String texto,
  ) =>
      operaciones.buscar(texto: texto);
  Future<List<Producto>> filtrarProductos(
    OperacionesCatalogo operaciones, {
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
  }) =>
      operaciones.buscar(
        texto: texto,
        idCategoria: idCategoria,
        idTianguis: idTianguis,
        precioMin: precioMin,
        precioMax: precioMax,
      );
  Future<Propuesta> proponerPrecio(
    OperacionesChat operaciones, {
    required String idProducto,
    required String idVendedor,
    required num monto,
  }) =>
      operaciones.proponerPrecio(
        idProducto: idProducto,
        idVendedor: idVendedor,
        monto: monto,
      );
}

class Vendedor extends Usuario {
  final String idVendedor, estado;
  final String? descripcion, nombreNegocio;
  final DateTime fechaHabilitacion;
  Vendedor.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id'],
        descripcion = m['descripcion'],
        nombreNegocio = m['nombre_negocio'],
        estado = m['estado'],
        fechaHabilitacion = DateTime.parse(m['fecha_habilitacion']),
        super.fromMap(Map<String, dynamic>.from(m['usuarios'] as Map));

  static Future<Vendedor> habilitarPerfil(
    OperacionesVendedor operaciones, {
    String? nombreNegocio,
    String? descripcion,
  }) =>
      operaciones.habilitarPerfil(
        nombreNegocio: nombreNegocio,
        descripcion: descripcion,
      );
  Future<void> registrarHorario(
    OperacionesVendedor operaciones, {
    required String idTianguis,
    required int dia,
    required String inicio,
    required String fin,
  }) =>
      operaciones.agregarHorario(idVendedor, idTianguis, dia, inicio, fin);
  Future<void> registrarAusencia(
    OperacionesVendedor operaciones, {
    required String idTianguis,
    required DateTime fecha,
    String? motivo,
  }) =>
      operaciones.registrarAusencia(
        idVendedor,
        idTianguis,
        fecha,
        motivo: motivo,
      );
}
