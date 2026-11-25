import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conserva la última respuesta válida mientras la pantalla sigue abierta.
class DatosEnVivo<T> extends ChangeNotifier with WidgetsBindingObserver {
  DatosEnVivo(
    this._consultar, {
    required Map<String, PostgresChangeFilter?> tablas,
    DateTime? Function(T)? proximoCambio,
  }) : _proximoCambio = proximoCambio {
    WidgetsBinding.instance.addObserver(this);
    _canal = _db.channel('datos-en-vivo-${++_siguienteCanal}');
    for (final tabla in tablas.entries) {
      _canal.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tabla.key,
        filter: tabla.value,
        callback: (_) => recargar(),
      );
    }
    _canal.subscribe((estado, _) {
      if (estado == RealtimeSubscribeStatus.subscribed) unawaited(recargar());
    });
    // Recupera eventos perdidos y actualiza aunque Realtime no esté disponible.
    _sondeo = Timer.periodic(const Duration(seconds: 30), (_) => recargar());
    unawaited(recargar());
  }

  static int _siguienteCanal = 0;
  final _db = Supabase.instance.client;
  final Future<T> Function() _consultar;
  late final RealtimeChannel _canal;
  late final Timer _sondeo;
  final DateTime? Function(T)? _proximoCambio;
  Timer? _limite;
  Future<void>? _pendiente;
  bool _repetir = false;
  bool _cerrado = false;
  bool _enPausa = false;
  bool hayDatos = false;
  bool desactualizado = false;
  T? datos;

  Future<void> recargar() {
    if (_cerrado || _enPausa) return Future.value();
    final pendiente = _pendiente;
    if (pendiente != null) {
      _repetir = true;
      return pendiente;
    }
    return _pendiente = _cargar().whenComplete(() => _pendiente = null);
  }

  Future<void> _cargar() async {
    do {
      _repetir = false;
      try {
        final nuevos = await _consultar().timeout(const Duration(seconds: 10));
        if (_cerrado) return;
        datos = nuevos;
        hayDatos = true;
        desactualizado = false;
        _programarCambio(nuevos);
      } catch (_) {
        if (_cerrado) return;
        desactualizado = true;
      }
      notifyListeners();
    } while (_repetir && !_cerrado && !_enPausa);
  }

  void _programarCambio(T datos) {
    _limite?.cancel();
    final cambio = _proximoCambio?.call(datos);
    final ahora = DateTime.now();
    if (cambio != null && cambio.isAfter(ahora)) {
      _limite = Timer(cambio.difference(ahora), () {
        notifyListeners();
        _programarCambio(datos);
        unawaited(recargar());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPausa = state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    if (state == AppLifecycleState.resumed) unawaited(recargar());
  }

  @override
  void dispose() {
    _cerrado = true;
    _sondeo.cancel();
    _limite?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_db.removeChannel(_canal));
    super.dispose();
  }
}
