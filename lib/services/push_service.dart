import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// avisos push por firebase; el servidor los manda desde la edge function enviar-push
// si falta google-services.json la app sigue funcionando sin push
class PushService {
  PushService._();

  static bool _activo = false;
  static String? _tokenRegistrado;
  static String? _usuarioRegistrado;
  static bool _cerrando = false;
  static Future<void> _operacion = Future.value();
  static late ValueListenable<String?> _sesionOculta;
  static StreamSubscription<AuthState>? _subSesion;
  static const _espera = Duration(seconds: 8);

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> iniciar(ValueListenable<String?> sesionOculta) async {
    _sesionOculta = sesionOculta;
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('PushService: Firebase sin configurar: $e');
      return;
    }
    try {
      _activo = true;
      FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => unawaited(registrar(token: t)));
      _subSesion?.cancel();
      _subSesion = _db.auth.onAuthStateChange.listen((d) {
        if (d.event == AuthChangeEvent.signedOut) _cerrando = false;
        if (d.session != null) unawaited(registrar());
      });
      _sesionOculta.addListener(() {
        if (_sesionOculta.value == null) unawaited(registrar());
      });
      if (_sesionOculta.value == null) {
        unawaited(registrar());
      } else {
        // Retira la suscripción que una versión anterior pudo dejar activa.
        unawaited(_enCola(_quitarToken));
      }
    } catch (e) {
      debugPrint('PushService.iniciar: $e');
    }
  }

  static Future<void> _enCola(Future<void> Function() operacion) =>
      _operacion = _operacion.then((_) => operacion());

  static bool get _puedeRegistrar =>
      _activo && !_cerrando && _sesionOculta.value == null;

  static Future<void> registrar({String? token}) {
    final usuario = _db.auth.currentUser?.id;
    if (!_puedeRegistrar || usuario == null) return Future.value();
    return _enCola(() async {
      if (!_puedeRegistrar || _db.auth.currentUser?.id != usuario) return;
      try {
        await FirebaseMessaging.instance.requestPermission().timeout(_espera);
        final t = token ??
            await FirebaseMessaging.instance.getToken().timeout(_espera);
        if (t == null || t.isEmpty) return;
        if (t == _tokenRegistrado && usuario == _usuarioRegistrado) return;
        if (!_puedeRegistrar || _db.auth.currentUser?.id != usuario) return;
        await _db.rpc('registrar_token_push', params: {
          'p_token': t,
          'p_plataforma':
              defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        }).timeout(_espera);
        _tokenRegistrado = t;
        _usuarioRegistrado = usuario;
      } catch (e) {
        debugPrint('PushService.registrar: $e');
      }
    });
  }

  // Bloquea los registros nuevos y espera a que termine el anterior.
  static Future<void> quitarDispositivo() {
    if (!_activo) return Future.value();
    _cerrando = true;
    return _enCola(_quitarToken);
  }

  static Future<void> _quitarToken() async {
    final registrado = _tokenRegistrado;
    _tokenRegistrado = null;
    _usuarioRegistrado = null;
    try {
      if (_db.auth.currentSession == null) return;
      final token = registrado ??
          await FirebaseMessaging.instance.getToken().timeout(_espera);
      if (token == null) return;
      await _db.rpc('quitar_token_push',
          params: {'p_token': token}).timeout(_espera);
    } catch (e) {
      debugPrint('PushService.quitarDispositivo: $e');
      try {
        await FirebaseMessaging.instance.deleteToken().timeout(_espera);
      } catch (e) {
        debugPrint('PushService.deleteToken: $e');
      }
    }
  }
}
