import 'package:flutter/foundation.dart';

/// Aviso global: cuando se guarda o quita un favorito en cualquier pantalla,
/// los corazones que ya están abiertos se vuelven a consultar y se actualizan.
class FavoritosCambios {
  static final version = ValueNotifier<int>(0);
  static void avisar() => version.value++;
}
