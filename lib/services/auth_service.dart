import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/identidad.dart';
import '../models/operaciones.dart';

import '../config/supabase_config.dart';

/// RF-01 a RF-05, RF-40.
///
///  - Los compradores entran SIN correo: signInAnonymously con un nombre de
///    usuario único (RF-01). Su cuenta vive en el dispositivo: si borran la
///    app sin verificar el correo, pierden favoritos y mensajes.
///  - Para ser vendedor se verifica el correo con un código de un solo uso y
///    se LIGA a la misma cuenta, sin perder favoritos ni chats (RF-02, RF-19).
///  - Quien ya verificó su correo puede volver a entrar con código (RF-03).
/// El nombre de usuario ya lo usa otra persona.
class NombreEnUsoException implements Exception {
  const NombreEnUsoException();
  @override
  String toString() => 'Este nombre de usuario ya existe, elige otro';
}

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
    if (!await nombreDisponible(n)) throw const NombreEnUsoException();
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

  /// RF-01: los nombres de usuario son únicos (sin distinguir mayúsculas).
  /// Si la función SQL `nombre_disponible` aún no existe en el backend, no
  /// bloquea la entrada (ver la migración nombre_publico_unico).
  Future<bool> nombreDisponible(String nombre) async {
    try {
      final r = await _db
          .rpc('nombre_disponible', params: {'p_nombre': nombre.trim()});
      return r != false;
    } catch (_) {
      return true;
    }
  }

  /// RF-05: sube la foto de perfil y devuelve su URL pública.
  Future<String> subirFotoPerfil(File archivo) async {
    final ruta =
        '${usuario!.id}/perfil/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bucket = _db.storage.from(SupabaseConfig.bucketPerfiles);
    await bucket.upload(ruta, archivo);
    return bucket.getPublicUrl(ruta);
  }

  /// RF-53: versiones de términos vigentes que el usuario aún no acepta.
  Future<List<Map<String, dynamic>>> terminosPendientes() async {
    final r = await _db.rpc('terminos_pendientes');
    return r is List
        ? [for (final v in r) Map<String, dynamic>.from(v as Map)]
        : <Map<String, dynamic>>[];
  }

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
