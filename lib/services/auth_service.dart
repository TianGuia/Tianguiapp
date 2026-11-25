import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'push_service.dart';

// cuenta y sesion, aqui se cumplen rf-32 a rf-36 y rf-40
// el comprador entra sin correo y su cuenta vive en el telefono
// para vender se verifica el correo y se une a esa misma cuenta
// ya existe otro usuario con ese nombre
class NombreEnUsoException implements Exception {
  const NombreEnUsoException();
  @override
  String toString() => 'Este nombre de usuario ya existe, elige otro';
}

// clave o respuesta incorrectas del administrador
class AdminAccesoException implements Exception {
  const AdminAccesoException();
  @override
  String toString() => 'Nombre, clave o respuesta incorrectos';
}

class AuthService {
  // true mientras se valida al admin, AuthGate espera para no mostrar la app de comprador
  static final entrandoAdmin = ValueNotifier<bool>(false);

  static final cambioRol = ValueNotifier<int>(0);

  // nombre de la cuenta anonima que cerro sesion en este telefono
  // la sesion sigue guardada, con ese nombre se vuelve a entrar
  static final sesionOculta = ValueNotifier<String?>(null);
  static const _esperaDocumentos = Duration(seconds: 12);
  static const _kOculta = 'sesion_anonima_oculta';

  static Future<void> cargarSesionOculta() async {
    try {
      final p = await SharedPreferences.getInstance();
      sesionOculta.value = p.getString(_kOculta);
    } catch (_) {} // sin preferencias no hay sesion oculta
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
    } catch (_) {} // no pasa nada si no se guarda
  }

  // Solo para sesiones ocultas guardadas por versiones anteriores.
  Future<void> descartarSesionOculta() async {
    if (usuario != null) await cerrarSesion();
    await _guardarOculta(null);
  }

  Future<void> _reanudarSesion() async {
    await _guardarOculta(null);
    try {
      await _db.auth.refreshSession();
    } catch (_) {} // si no refresca se queda con la sesion actual
  }

  AuthService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  User? get usuario => _db.auth.currentUser;

  bool get esAnonimo => usuario?.isAnonymous ?? false;

  // entrada anonima
  // rf-32 se cumple aqui: la persona crea su cuenta escribiendo solo un nombre

  Future<void> registrar(String nombre) async {
    final n = nombre.trim();
    final oculta = sesionOculta.value;
    if (oculta != null) {
      // mismo nombre y misma sesion: vuelve a entrar
      if (oculta.toLowerCase() == n.toLowerCase() && usuario != null) {
        await _reanudarSesion();
        return;
      }
      // otro nombre: se cierra la cuenta anterior
      await descartarSesionOculta();
    }
    if (!await nombreDisponible(n)) throw const NombreEnUsoException();
    await _db.auth.signInAnonymously(data: {'nombre_publico': n});
    try {
      await actualizarPerfil(
          nombre: n); // respaldo si el trigger no tomo el nombre
    } catch (_) {} // si falla se deja asi
  }

  // vincular correo a la cuenta anonima
  // rf-33 se cumple aqui: el correo se verifica con un codigo que llega a ese mismo correo

  // manda el codigo al correo y lo une a la cuenta
  Future<void> enviarCodigoVinculacion(String correo) =>
      _db.auth.updateUser(UserAttributes(email: correo.trim()));

  // confirma el codigo, la cuenta deja de ser anonima y conserva su id
  Future<void> confirmarVinculacion(String correo, String codigo) async {
    await _db.auth.verifyOTP(
      email: correo.trim(),
      token: codigo.trim(),
      type: OtpType.emailChange,
    );
    await _db.auth.refreshSession();
  }

  // volver a entrar con correo
  // rf-34 se cumple aqui: quien ya tiene cuenta entra con un codigo que le llega al correo

  // manda el codigo, sirve para entrar desde otro celular
  Future<void> enviarCodigo(String correo, {String? nombre}) =>
      _db.auth.signInWithOtp(
        email: correo.trim(),
        shouldCreateUser: true,
        data: nombre == null ? null : {'nombre_publico': nombre.trim()},
      );

  Future<void> iniciarSesion(String correo, String codigo) async {
    await _db.auth.verifyOTP(
      email: correo.trim(),
      token: codigo.trim(),
      type: OtpType.email,
    );
    await _guardarOculta(null);
  }

  // terminos
  // rf-40 se cumple aqui: la persona acepta las condiciones de uso antes de entrar
  // rf-53 se cumple aqui: si hay condiciones nuevas se pide aceptarlas antes de seguir

  Future<void> aceptarTerminosVigentes(List<Map<String, dynamic>> documentos) =>
      _db.rpc<void>('aceptar_terminos_vigentes', params: {
        'p_versiones': [for (final documento in documentos) documento['id']],
      }).timeout(_esperaDocumentos);

  // si nombre_disponible no existe en el backend no se bloquea la entrada
  Future<bool> nombreDisponible(String nombre) async {
    try {
      final r = await _db.rpc('nombre_disponible', params: {'p_nombre': nombre.trim()});
      return r != false;
    } catch (_) {
      return true;
    }
  }

  // rf-36 se cumple aqui: la persona puede ver y cambiar su nombre y su foto
  Future<String> subirFotoPerfil(File archivo) async {
    final ruta = '${usuario!.id}/perfil/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bucket = _db.storage.from(SupabaseConfig.bucketProductos);
    await bucket.upload(ruta, archivo);
    return bucket.getPublicUrl(ruta);
  }

  Future<List<Map<String, dynamic>>> terminosPendientes() async {
    final r = await _db.rpc('terminos_pendientes').timeout(_esperaDocumentos);
    return [
      for (final v in r as List) Map<String, dynamic>.from(v as Map)
    ];
  }

  // administrador

  // acceso de admin sin correo: nombre, clave y respuesta secreta
  // se valida en el servidor antes de crear la sesion, asi un intento fallido no deja cuentas sueltas
  // maximo 4 admins y la sesion dura 12 h
  Future<void> entrarAdministrador(String nombre, String clave, String respuesta) async {
    final params = {'p_nombre': nombre.trim(), 'p_clave': clave, 'p_respuesta': respuesta};
    // primero se comprueba sin sesion
    final valido = await _db.rpc('admin_verificar', params: params);
    if (valido != true) throw const AdminAccesoException();

    // luego sesion anonima y se abre la de admin
    entrandoAdmin.value = true;
    try {
      if (sesionOculta.value != null) await descartarSesionOculta();
      await _db.auth.signInAnonymously(
          data: {'nombre_publico': 'Admin ${nombre.trim()}'});
      final ok = await _db.rpc('admin_entrar', params: params);
      if (ok != true) throw const AdminAccesoException();
    } catch (e) {
      try {
        await _db.auth.signOut();
      } catch (_) {} // no importa si falla
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

  // cierra la sesion de admin
  Future<void> salirAdmin() async {
    await PushService.quitarDispositivo();
    try {
      // sin red no debe quedarse colgado
      await _db.rpc('admin_salir').timeout(const Duration(seconds: 6));
    } catch (_) {} // sin red se sigue con el cierre local
    await _cerrarAuth();
    cambioRol.value++;
  }

  // rf-35 se cumple aqui: la persona puede salir de su cuenta en este telefono
  Future<void> cerrarSesion() async {
    await PushService.quitarDispositivo();
    await _cerrarAuth();
  }

  Future<void> _cerrarAuth() async {
    try {
      await _db.auth.signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // El SDK limpia la sesión local antes de solicitar la revocación.
      if (_db.auth.currentSession != null) rethrow;
    }
  }

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
