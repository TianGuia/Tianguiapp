import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/fondo.dart';

/// RF-53: cuando se publica una versión nueva de las condiciones de uso o del
/// aviso de privacidad, se pide aceptarla antes de seguir usando la app.
class TerminosScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pendientes;
  final VoidCallback onAceptado;
  const TerminosScreen({super.key, required this.pendientes, required this.onAceptado});
  @override
  State<TerminosScreen> createState() => _TerminosScreenState();
}

class _TerminosScreenState extends State<TerminosScreen> {
  final _auth = AuthService();
  bool _cargando = false;

  String _titulo(Map<String, dynamic> v) {
    final t = '${v['tipo']}'.toLowerCase();
    final nombre = t.contains('priv') ? 'Aviso de privacidad' : 'Condiciones de uso';
    return '$nombre · versión ${v['version']}';
  }

  Future<void> _aceptar() async {
    setState(() => _cargando = true);
    try {
      await _auth.aceptarTerminosVigentes();
      widget.onAceptado();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo registrar tu aceptación: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Condiciones actualizadas'), automaticallyImplyLeading: false),
        body: SafeArea(
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                  'Publicamos una nueva versión. Para seguir usando TianGuía necesitas aceptarla.',
                  style: TextStyle(fontSize: 16)),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                for (final v in widget.pendientes)
                  Card(
                    child: ExpansionTile(
                      initiallyExpanded: widget.pendientes.length == 1,
                      title: Text(_titulo(v), style: const TextStyle(fontWeight: FontWeight.w700)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [Text('${v['contenido'] ?? ''}')],
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                FilledButton(
                  onPressed: _cargando ? null : _aceptar,
                  child: Text(_cargando ? 'ESPERA…' : 'ACEPTO'),
                ),
                TextButton(
                  onPressed: _cargando ? null : () => _auth.cerrarSesion(),
                  child: const Text('No acepto, cerrar sesión',
                      style: TextStyle(color: Tg.amarillo)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
