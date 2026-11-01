import 'package:supabase_flutter/supabase_flutter.dart';

/// Id del comprador de la sesión actual (tabla `compradores`).
/// Las tablas propuestas_precio, apartados, visitas y calificaciones apuntan a
/// compradores(id_comprador), no a usuarios(id). Si no se puede consultar,
/// se usa el id del usuario (en TianGuía suelen coincidir).
Future<String> miIdComprador() async {
  final db = Supabase.instance.client;
  final uid = db.auth.currentUser!.id;
  try {
    final r = await db
        .from('compradores')
        .select('id_comprador')
        .eq('id_usuario', uid)
        .maybeSingle();
    return (r?['id_comprador'] as String?) ?? uid;
  } catch (_) {
    return uid;
  }
}
