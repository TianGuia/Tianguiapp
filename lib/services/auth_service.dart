import 'package:supabase_flutter/supabase_flutter.dart';

/// RF-01 a RF-05, RF-40. Login con código de un solo uso (OTP) por correo.
class AuthService {
  AuthService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;

  /// RF-01/RF-03: envía el código al correo (crea la cuenta si no existe).
  Future<void> enviarCodigo(String correo, {String? nombre}) =>
      _db.auth.signInWithOtp(
        email: correo.trim(),
        shouldCreateUser: true,
        data: nombre == null ? null : {'nombre_publico': nombre.trim()},
      );

  /// RF-02/RF-03: valida el código recibido.
  Future<void> verificarCodigo(String correo, String codigo) =>
      _db.auth.verifyOTP(
        email: correo.trim(),
        token: codigo.trim(),
        type: OtpType.email,
      );

  // ---------------- Términos (RF-40 / RF-53) ----------------

  /// Acepta las versiones pendientes; admite respuestas de versiones anteriores
  /// del backend además de la lista de documentos vigente en Toldo.
  /// RF-40 / RF-53: acepta todas las versiones pendientes.
  /// Usa la función existente terminos_pendientes() (devuelve filas de
  /// versiones_documento) y registra cada aceptación.
  Future<void> aceptarTerminosVigentes() async {
    final uid = usuario?.id;
    if (uid == null) return;
    final pendientes = await _db.rpc('terminos_pendientes') as List;
    if (pendientes.isEmpty) return;
    await _db.from('aceptaciones_terminos').insert([
      for (final v in pendientes) {'id_usuario': uid, 'id_version': v['id']}
    ]);
  }

  /// RF-53: ¿hay una versión nueva pendiente de aceptar?
  Future<bool> hayTerminosPendientes() async =>
      (await _db.rpc('terminos_pendientes') as List).isNotEmpty;

  /// SOLO DESARROLLO: acceso con contraseña para probar sin SMTP.
  /// Requiere desactivar "Confirm email" en Authentication > Providers > Email.
  Future<void> entrarConContrasena(String correo, String clave) =>
      _db.auth.signInWithPassword(email: correo.trim(), password: clave);

  Future<void> registrarConContrasena(String correo, String clave, String nombre) =>
      _db.auth.signUp(
        email: correo.trim(),
        password: clave,
        data: {'nombre_publico': nombre.trim()},
      );

  /// RF-04
  Future<void> cerrarSesion() => _db.auth.signOut();

  /// RF-05
  Future<Map<String, dynamic>?> miPerfil() =>
      _db.from('usuarios').select().eq('id', usuario!.id).maybeSingle();

  Future<void> actualizarPerfil(
          {String? nombre, String? telefono, String? fotoUrl}) =>
      _db.from('usuarios').update({
        if (nombre != null) 'nombre_publico': nombre,
        if (telefono != null) 'telefono': telefono,
        if (fotoUrl != null) 'foto_url': fotoUrl,
      }).eq('id', usuario!.id);
}
