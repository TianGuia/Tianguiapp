import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// cosas que el usuario quita de su lista, solo en este telefono
// no se borran del servidor, el otro participante las sigue viendo
class Ocultos {
  static String _clave(String tipo) =>
      'ocultos_${tipo}_${Supabase.instance.client.auth.currentUser?.id ?? 'anon'}';

  static Future<Set<String>> cargar(String tipo) async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_clave(tipo)) ?? const <String>[]).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> agregar(String tipo, Iterable<String> ids) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = (p.getStringList(_clave(tipo)) ?? const <String>[]).toSet()..addAll(ids);
      await p.setStringList(_clave(tipo), s.toList());
    } catch (_) {} // si no se guarda, solo vuelve a salir
  }
}
