import 'package:supabase_flutter/supabase_flutter.dart';

/// RF-01 a RF-05, RF-40.
///
/// Dos formas de entrar:
///  - Comprador: SIN cuenta. Elige un nombre de usuario y Supabase le crea una
///    identidad anónima en su celular (signInAnonymously).
///  - Vendedor / administrador: correo + código de un solo uso (OTP).
class AuthService {
  AuthService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;

  /// true si es un comprador sin cuenta (identidad anónima).
  bool get esAnonimo => usuario?.isAnonymous ?? false;

  // ---------------- Comprador sin cuenta ----------------

  /// Entra como comprador con solo un nombre de usuario.
  Future<void> entrarComoComprador(String nombre) async {
    final n = nombre.trim();
    await _db.auth.signInAnonymously(data: {'nombre_publico': n});
    // RF-40: registra la aceptación de condiciones.
    try {
      await aceptarTerminosVigentes();
    } catch (_) {}
    // Respaldo por si el trigger de alta no tomó el nombre.
    try {
      await actualizarPerfil(nombre: n);
    } catch (_) {}
  }

  // ---------------- Vendedor / administrador (OTP) ----------------

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
  Future<void> aceptarTerminosVigentes() async {
    final uid = usuario?.id;
    if (uid == null) return;
    final r = await _db.rpc('terminos_pendientes');
    if (r is List) {
      if (r.isEmpty) return;
      await _db.from('aceptaciones_terminos').insert([
        for (final v in r) {'id_usuario': uid, 'id_version': v['id']}
      ]);
    } else if (r == true) {
      await _db.rpc('aceptar_terminos_vigentes');
    }
  }

  /// RF-53: ¿hay una versión nueva pendiente de aceptar?
  Future<bool> hayTerminosPendientes() async {
    final r = await _db.rpc('terminos_pendientes');
    return r is List ? r.isNotEmpty : r == true;
  }

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
