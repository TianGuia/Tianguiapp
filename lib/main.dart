import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(SupabaseConfig.url.isNotEmpty && SupabaseConfig.key.isNotEmpty,
      'Faltan --dart-define=SUPABASE_URL y SUPABASE_KEY');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.key,
  );
  await AuthService.cargarSesionOculta();
  runApp(const TianGuiaApp());
  // despues de pintar: el permiso de notificaciones no debe retrasar el arranque
  PushService.iniciar(AuthService.sesionOculta);
}

SupabaseClient get db => Supabase.instance.client;
