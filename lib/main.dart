import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(SupabaseConfig.url.isNotEmpty && SupabaseConfig.key.isNotEmpty,
      'Faltan --dart-define=SUPABASE_URL y SUPABASE_KEY');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.key,
  );
  runApp(const TianGuiaApp());
}

SupabaseClient get db => Supabase.instance.client;
