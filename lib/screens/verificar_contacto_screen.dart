import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/fondo.dart';

/// RF-02 / RF-19: verifica el correo y lo liga a la cuenta anónima actual.
/// Hace pop(true) cuando la cuenta quedó verificada.
class VerificarContactoScreen extends StatefulWidget {
  const VerificarContactoScreen({super.key});
  @override
  State<VerificarContactoScreen> createState() => _VerificarContactoScreenState();
}

class _VerificarContactoScreenState extends State<VerificarContactoScreen> {
  final _auth = AuthService();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  bool _enviado = false, _cargando = false;

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _enviar() async {
    final c = _correo.text.trim();
    if (!c.contains('@')) return _msg('Escribe un correo válido');
    setState(() => _cargando = true);
    try {
      await _auth.enviarCodigoVinculacion(c);
      setState(() => _enviado = true);
    } catch (e) {
      final t = '$e';
      _msg(t.contains('already') || t.contains('registered')
          ? 'Ese correo ya tiene cuenta. Cierra sesión y entra con "Ya tengo cuenta con correo".'
          : 'No se pudo enviar el código: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmar() async {
    setState(() => _cargando = true);
    try {
      await _auth.confirmarVinculacion(_correo.text, _codigo.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg('Código incorrecto o vencido');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Verifica tu correo'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (!_enviado) ...[
                  const Text(
                    'Para vender necesitamos verificar tu correo. '
                    'Conservas tu cuenta, tus favoritos y tus mensajes.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _correo,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(hintText: 'Correo electrónico'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _cargando ? null : _enviar,
                    child: const Text('ENVIAR CÓDIGO'),
                  ),
                ] else ...[
                  Text('Enviamos un código a ${_correo.text.trim()}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black, fontSize: 24, letterSpacing: 6),
                    decoration: const InputDecoration(hintText: '000000'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _cargando ? null : _confirmar,
                    child: const Text('VERIFICAR'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _enviado = false),
                    child: const Text('Cambiar correo'),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
