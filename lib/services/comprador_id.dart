import 'package:supabase_flutter/supabase_flutter.dart';

// id del comprador de la sesion, tabla compradores
// propuestas, apartados, visitas y calificaciones apuntan a compradores y no a usuarios
// si no se puede consultar usa el id del usuario, normalmente son el mismo
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
