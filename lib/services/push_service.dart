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
  static StreamSubscription<AuthState>? _subSesion;
  static const _espera = Duration(seconds: 8);

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> iniciar() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('PushService: Firebase sin configurar: $e');
      return;
    }
    try {
      _activo = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => unawaited(registrar(token: t)));
      _subSesion?.cancel();
      _subSesion = _db.auth.onAuthStateChange.listen((d) {
        if (d.session != null) unawaited(registrar());
      });
      unawaited(registrar());
    } catch (e) {
      debugPrint('PushService.iniciar: $e');
    }
  }

  static Future<void> registrar({String? token}) async {
    if (!_activo || _db.auth.currentSession == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission(); // android 13+ pide permiso
      final t = token ?? await FirebaseMessaging.instance.getToken().timeout(_espera);
      if (t == null || t.isEmpty) return;
      if (token == null && t == _tokenRegistrado) return;
      if (_db.auth.currentSession == null) return;
      await _db.rpc('registrar_token_push', params: {
        'p_token': t,
        'p_plataforma': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      }).timeout(_espera);
      _tokenRegistrado = t;
    } catch (e) {
      debugPrint('PushService.registrar: $e');
    }
  }

  // se llama antes de signOut: sin sesion la base no deja borrar el token
  static Future<void> quitarDispositivo() async {
    if (!_activo) return;
    try {
      final t = _tokenRegistrado ?? await FirebaseMessaging.instance.getToken().timeout(_espera);
      _tokenRegistrado = null;
      if (t == null || t.isEmpty || _db.auth.currentSession == null) return;
      await _db.rpc('quitar_token_push', params: {'p_token': t}).timeout(_espera);
    } catch (e) {
      debugPrint('PushService.quitarDispositivo: $e');
    }
  }
}
