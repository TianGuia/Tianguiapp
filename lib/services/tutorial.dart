import 'package:shared_preferences/shared_preferences.dart';

// recuerda en este telefono si ya se mostro el tutorial de bienvenida
// si no se puede leer o guardar, simplemente no se muestra solo
class Tutorial {
  static const _llave = 'tutorial_visto';

  static Future<bool> debeMostrarse() async {
    try {
      final p = await SharedPreferences.getInstance();
      return !(p.getBool(_llave) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcarVisto() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_llave, true);
    } catch (_) {/* no pasa nada: a lo mucho se vuelve a mostrar */}
  }
}
