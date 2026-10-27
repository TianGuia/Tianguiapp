import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/identidad.dart';
import '../models/operaciones.dart';

/// RF-01 a RF-05, RF-40.
///
///  - Todos entran SIN iniciar sesión: signInAnonymously (RF-01).
///  - Para ser vendedor se verifica el correo con un código de un solo uso y
///    se LIGA a la misma cuenta, sin perder favoritos ni chats (RF-02, RF-19).
///  - Quien ya verificó su correo puede volver a entrar con código (RF-03).
class AuthService implements OperacionesUsuario {
  AuthService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;

  /// true si la cuenta aún no tiene correo verificado.
  bool get esAnonimo => usuario?.isAnonymous ?? false;

  // ---------------- Entrada anónima (RF-01) ----------------

  @override
  Future<void> entrarAnonimo(String nombre) async {
    final n = nombre.trim();
    await _db.auth.signInAnonymously(data: {'nombre_publico': n});
    try {
      await aceptarTerminosVigentes(); // RF-40
    } catch (_) {}
    try {
      await actualizarPerfil(
          nombre: n); // respaldo si el trigger no tomó el nombre
    } catch (_) {}
  }

  // ---------------- Vincular correo a la cuenta anónima (RF-02) ----------------

  /// Envía el código al correo y lo asocia a la cuenta actual.
  Future<void> enviarCodigoVinculacion(String correo) =>
      _db.auth.updateUser(UserAttributes(email: correo.trim()));

  /// Confirma el código: la cuenta deja de ser anónima y conserva su id.
  Future<void> confirmarVinculacion(String correo, String codigo) async {
    await _db.auth.verifyOTP(
      email: correo.trim(),
      token: codigo.trim(),
      type: OtpType.emailChange,
    );
    await _db.auth.refreshSession();
  }

  // ---------------- Volver a entrar con correo (RF-03) ----------------

  /// Envía el código al correo (para quien ya verificó antes, p. ej. otro celular).
  Future<void> enviarCodigo(String correo, {String? nombre}) =>
      _db.auth.signInWithOtp(
        email: correo.trim(),
        shouldCreateUser: true,
        data: nombre == null ? null : {'nombre_publico': nombre.trim()},
      );

  @override
  Future<void> verificarCodigo(String correo, String codigo) =>
      _db.auth.verifyOTP(
        email: correo.trim(),
        token: codigo.trim(),
        type: OtpType.email,
      );

  // ---------------- Términos (RF-40 / RF-53) ----------------

  Future<void> aceptarTerminosVigentes() async {
    final uid = usuario?.id;
    if (uid == null) return;
    final pendientes = await _db.rpc('terminos_pendientes');
    if (pendientes is List) {
      if (pendientes.isEmpty) return;
      await _db.from('aceptaciones_terminos').insert([
        for (final v in pendientes) {'id_usuario': uid, 'id_version': v['id']}
      ]);
    } else if (pendientes == true) {
      await _db.rpc('aceptar_terminos_vigentes');
    }
  }

  Future<bool> hayTerminosPendientes() async {
    final pendientes = await _db.rpc('terminos_pendientes');
    return pendientes is List ? pendientes.isNotEmpty : pendientes == true;
  }

  /// SOLO DESARROLLO: acceso con contraseña para probar sin SMTP.
  Future<void> entrarConContrasena(String correo, String clave) =>
      _db.auth.signInWithPassword(email: correo.trim(), password: clave);

  Future<void> registrarConContrasena(
          String correo, String clave, String nombre) =>
      _db.auth.signUp(
        email: correo.trim(),
        password: clave,
        data: {'nombre_publico': nombre.trim()},
      );

  /// RF-04
  Future<void> cerrarSesion() => _db.auth.signOut();

  /// RF-05
  @override
  Future<Usuario?> miPerfil() async {
    final r =
        await _db.from('usuarios').select().eq('id', usuario!.id).maybeSingle();
    return r == null ? null : Usuario.fromMap(r);
  }

  Future<Comprador> miComprador() async => Comprador.fromMap(await _db
      .from('compradores')
      .select('*, usuarios!compradores_id_usuario_fkey(*)')
      .eq('id_usuario', usuario!.id)
      .single());

  @override
  Future<void> actualizarPerfil(
          {String? nombre, String? telefono, String? fotoUrl}) =>
      _db.from('usuarios').update({
        if (nombre != null) 'nombre_publico': nombre,
        if (telefono != null) 'telefono': telefono,
        if (fotoUrl != null) 'foto_url': fotoUrl,
      }).eq('id', usuario!.id);
}
