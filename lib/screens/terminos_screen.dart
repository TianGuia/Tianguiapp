import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/cerrar_sesion.dart';
import '../widgets/urbano.dart';

// RF-53 se cumple aqui: si hay condiciones nuevas se pide aceptarlas antes de seguir
class TerminosScreen extends StatefulWidget {
  final List<Map<String, dynamic>> pendientes;
  final VoidCallback onAceptado;
  final VoidCallback onRecargar;
  const TerminosScreen({
    super.key,
    required this.pendientes,
    required this.onAceptado,
    required this.onRecargar,
  });
  @override
  State<TerminosScreen> createState() => _TerminosScreenState();
}

class _TerminosScreenState extends State<TerminosScreen> {
  final _auth = AuthService();
  bool _cargando = false;

  String _titulo(Map<String, dynamic> v) {
    final t = '${v['tipo']}'.toLowerCase();
    final nombre =
        t.contains('priv') ? 'Aviso de privacidad' : 'Condiciones de uso';
    return '$nombre · versión ${v['version']}';
  }

  Future<void> _aceptar() async {
    setState(() => _cargando = true);
    try {
      await _auth.aceptarTerminosVigentes(widget.pendientes);
      if (mounted) widget.onAceptado();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'No se pudo registrar tu aceptación. Actualiza los documentos e inténtalo de nuevo.',
        ),
      ));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldTg(
      appBar: AppBar(
          title: const Text('Condiciones de uso y privacidad'),
          automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          CabeceraTg(
            titulo: 'Documentos por aceptar',
            subtitulo:
                'Lee y acepta los documentos vigentes para entrar a TianGuía.',
            icono: Icons.fact_check,
            datos: [
              DatoTg(Icons.description, Tg.amarillo,
                  '${widget.pendientes.length}', 'POR ACEPTAR')
            ],
          ),
          Expanded(
            child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final v in widget.pendientes)
                    CardTg(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        initiallyExpanded: widget.pendientes.length == 1,
                        title: Text(_titulo(v),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                onPressed: _cargando ? null : widget.onRecargar,
                child: const Text('Actualizar documentos'),
              ),
              TextButton(
                onPressed:
                    _cargando ? null : () => confirmarCerrarSesion(context),
                child: const Text('No acepto, cerrar sesión',
                    style: TextStyle(color: Tg.amarillo)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
