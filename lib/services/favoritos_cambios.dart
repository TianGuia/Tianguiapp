import 'package:flutter/foundation.dart';

// avisa a los corazones abiertos para que se vuelvan a consultar cuando cambia un favorito
class FavoritosCambios {
  static final version = ValueNotifier<int>(0);
  static void avisar() => version.value++;
}
