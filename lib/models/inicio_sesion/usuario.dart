import '../../services/auth_service.dart';

// la cuenta de una persona, tabla usuarios
// de aqui salen los roles de comprador y vendedor, y una cuenta puede tener los dos
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
        estadoCuenta = m['estado_cuenta'].toString(),
        fechaRegistro = DateTime.parse(m['creado_en']).toLocal();

  // rf-32 se cumple aqui: la persona crea su cuenta escribiendo solo un nombre
  static Future<void> registrar(String nombre) => AuthService().registrar(nombre);

  // rf-34 se cumple aqui: quien ya tiene cuenta entra con un codigo que le llega al correo
  static Future<void> iniciarSesion(String correo, String codigo) =>
      AuthService().iniciarSesion(correo, codigo);

  // rf-36 se cumple aqui: la persona puede ver y cambiar su nombre y su foto
  Future<void> actualizarPerfil({String? nombre, String? telefono, String? fotoUrl}) =>
      AuthService().actualizarPerfil(nombre: nombre, telefono: telefono, fotoUrl: fotoUrl);
}
