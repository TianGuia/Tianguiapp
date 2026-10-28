import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Clave o respuesta incorrectas al entrar como administrador.
class AdminAccesoException implements Exception {
  const AdminAccesoException();
  @override
  String toString() => 'Nombre, clave o respuesta incorrectos';
}

class AuthService {
  /// true mientras se valida el acceso de administrador: AuthGate espera para
  /// no mostrar un instante la app de comprador.
  static final entrandoAdmin = ValueNotifier<bool>(false);

  /// Cambia cuando la sesión pasa a (o deja de) ser de administrador.
  static final cambioRol = ValueNotifier<int>(0);

  /// Nombre de la cuenta anónima en la que se "cerró sesión" en este teléfono.
  /// La sesión sigue guardada en el dispositivo: quien escriba ese mismo nombre
  /// aquí vuelve a entrar a la misma cuenta, con sus favoritos y mensajes.
  static final sesionOculta = ValueNotifier<String?>(null);
  static const _kOculta = 'sesion_anonima_oculta';

  static Future<void> cargarSesionOculta() async {
    try {
      final p = await SharedPreferences.getInstance();
      sesionOculta.value = p.getString(_kOculta);
    } catch (_) {}
  }

  static Future<void> _guardarOculta(String? nombre) async {
    sesionOculta.value = nombre;
    try {
      final p = await SharedPreferences.getInstance();
      if (nombre == null) {
        await p.remove(_kOculta);
      } else {
        await p.setString(_kOculta, nombre);
      }
    } catch (_) {}
  }

  /// "Cerrar sesión" de una cuenta anónima: no se revoca la sesión, solo se
  /// oculta, para poder volver a entrar con el mismo nombre en este teléfono.
  Future<void> ocultarSesion() async {
    String? nombre;
    try {
      nombre = (await miPerfil())?['nombre_publico'] as String?;
    } catch (_) {}
    nombre ??= usuario?.userMetadata?['nombre_publico'] as String?;
    await _guardarOculta((nombre == null || nombre.trim().isEmpty) ? 'Invitado' : nombre.trim());
  }

  /// Cierra de verdad la cuenta oculta (se pierde: nadie más puede recuperarla).
  Future<void> descartarSesionOculta() async {
    await _guardarOculta(null);
    try {
      await _db.auth.signOut();
    } catch (_) {}
  }

  Future<void> _reanudarSesion() async {
    await _guardarOculta(null);
    try {
      await _db.auth.refreshSession();
    } catch (_) {}
  }

  AuthService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;

  /// true si la cuenta aún no tiene correo verificado.
  bool get esAnonimo => usuario?.isAnonymous ?? false;

  // ---------------- Entrada anónima (RF-01) ----------------

  Future<void> entrarAnonimo(String nombre) async {
    final n = nombre.trim();
    final oculta = sesionOculta.value;
    if (oculta != null) {
      // Mismo nombre y misma sesión guardada en este teléfono: vuelve a entrar.
      if (oculta.toLowerCase() == n.toLowerCase() && usuario != null) {
        await _reanudarSesion();
        return;
      }
      // Otro nombre: la cuenta anterior se cierra definitivamente.
      await descartarSesionOculta();
    }
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

  Future<void> verificarCodigo(String correo, String codigo) async {
    await _db.auth.verifyOTP(
      email: correo.trim(),
      token: codigo.trim(),
      type: OtpType.email,
    );
    await _guardarOculta(null);
  }

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
      final r = await _db.rpc('nombre_disponible', params: {'p_nombre': nombre.trim()});
      return r != false;
    } catch (_) {
      return true;
    }
  }

  /// RF-05: sube la foto de perfil y devuelve su URL pública.
  Future<String> subirFotoPerfil(File archivo) async {
    final ruta = '${usuario!.id}/perfil/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bucket = _db.storage.from(SupabaseConfig.bucketProductos);
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

  // ---------------- Administrador ----------------

  /// Acceso de administrador sin correo: nombre + clave + respuesta a la
  /// pregunta secreta. Se valida en el servidor ANTES de crear la sesión
  /// (admin_verificar), así un intento fallido no deja cuentas sueltas. Son
  /// máximo 4 administradores y la sesión dura 12 h.
  Future<void> entrarAdministrador(String nombre, String clave, String respuesta) async {
    final params = {'p_nombre': nombre.trim(), 'p_clave': clave, 'p_respuesta': respuesta};
    // 1) Comprobación sin sesión.
    final valido = await _db.rpc('admin_verificar', params: params);
    if (valido != true) throw const AdminAccesoException();

    // 2) Sesión anónima + apertura de la sesión de administrador.
    entrandoAdmin.value = true;
    try {
      if (sesionOculta.value != null) await descartarSesionOculta();
      await _db.auth.signInAnonymously(
          data: {'nombre_publico': 'Admin ${nombre.trim()}'});
      final ok = await _db.rpc('admin_entrar', params: params);
      if (ok != true) throw const AdminAccesoException();
      try {
        await aceptarTerminosVigentes();
      } catch (_) {}
    } catch (e) {
      try {
        await _db.auth.signOut();
      } catch (_) {}
      rethrow;
    } finally {
      entrandoAdmin.value = false;
      cambioRol.value++;
    }
  }

  Future<bool> esAdmin() async {
    try {
      return (await _db.rpc('es_admin')) == true;
    } catch (_) {
      return false;
    }
  }

  /// Cierra la sesión de administrador (invalida el acceso por clave).
  Future<void> salirAdmin() async {
    try {
      await _db.rpc('admin_salir');
    } catch (_) {}
    await _db.auth.signOut();
    cambioRol.value++;
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
