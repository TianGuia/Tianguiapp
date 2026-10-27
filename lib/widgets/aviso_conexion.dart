import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/supabase_config.dart';

/// RNF-5: avisa cuando no hay conexión con el servidor, para que el usuario
/// sepa que lo que ve puede estar desactualizado (p. ej. el estado de un puesto).
/// Si no se puede determinar (p. ej. en web), no muestra nada.
class AvisoConexion extends StatefulWidget {
  const AvisoConexion({super.key});
  @override
  State<AvisoConexion> createState() => _AvisoConexionState();
}

class _AvisoConexionState extends State<AvisoConexion> {
  Timer? _timer;
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    _revisar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _revisar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _revisar() async {
    var sin = false;
    try {
      final r = await InternetAddress.lookup(Uri.parse(SupabaseConfig.url).host)
          .timeout(const Duration(seconds: 4));
      sin = r.isEmpty;
    } on SocketException {
      sin = true;
    } on TimeoutException {
      sin = true;
    } catch (_) {
      sin = false; // plataforma sin dart:io completo: no se puede saber
    }
    if (mounted && sin != _sinConexion) setState(() => _sinConexion = sin);
  }

  @override
  Widget build(BuildContext context) {
    if (!_sinConexion) return const SizedBox.shrink();
    return const Material(
      color: Color(0xFFFFD21F),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Icon(Icons.wifi_off, size: 20, color: Color(0xFF061A5E)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sin conexión. Lo que ves puede estar desactualizado.',
                style: TextStyle(
                    color: Color(0xFF061A5E),
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
