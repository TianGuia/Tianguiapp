import '../../services/auth_service.dart';

/// La CUENTA de una persona en TianGuía.
///
/// Quien abre la app todavía no es un Usuario: lo es cuando se registra y el
/// sistema crea su cuenta (nombre, correo, teléfono, foto). Por eso esta clase
/// es la base de todo: de aquí salen los roles de Comprador y Vendedor.
///
/// Una misma cuenta puede ser comprador y vendedor a la vez (por eso en el
/// diagrama la especialización se llama «solapada»). En la base de datos es la
/// tabla `usuarios`.
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

  /// RF-01 · Crear la cuenta (solo pide un nombre para empezar).
  static Future<void> registrar(String nombre) => AuthService().registrar(nombre);

  /// RF-03 · Volver a entrar con el código que llega al correo.
  static Future<void> iniciarSesion(String correo, String codigo) =>
      AuthService().iniciarSesion(correo, codigo);

  /// RF-05 · Cambiar nombre, teléfono o foto del perfil.
  Future<void> actualizarPerfil({String? nombre, String? telefono, String? fotoUrl}) =>
      AuthService().actualizarPerfil(nombre: nombre, telefono: telefono, fotoUrl: fotoUrl);
}
