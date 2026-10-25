import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

/// Solo para vendedores y administradores (RF-01, RF-02, RF-03, RF-40):
/// correo -> código de 6 dígitos -> sesión. Los compradores no pasan por aquí.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  bool _codigoEnviado = false, _acepta = false, _cargando = false;

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _enviar() async {
    if (_correo.text.trim().isEmpty) return _msg('Escribe tu correo');
    if (!_acepta) return _msg('Debes aceptar las condiciones de uso y el aviso de privacidad');
    setState(() => _cargando = true);
    try {
      await _auth.enviarCodigo(_correo.text, nombre: _nombre.text.isEmpty ? null : _nombre.text);
      setState(() => _codigoEnviado = true);
    } catch (e) {
      _msg('No se pudo enviar el código: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificar() async {
    setState(() => _cargando = true);
    try {
      await _auth.verificarCodigo(_correo.text, _codigo.text);
      try {
        await _auth.aceptarTerminosVigentes(); // RF-40
      } catch (_) {}
      // Cierra esta pantalla; AuthGate ya muestra el Home con la sesión nueva.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      _msg('Código incorrecto o vencido');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Acceso para vendedores'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('TIANGUÍA',
                  style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Colors.white)),
              const Text('Comida, antojitos y más…',
                  style: TextStyle(color: Tg.amarillo, fontStyle: FontStyle.italic)),
              const SizedBox(height: 32),
              if (!_codigoEnviado) ...[
                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(hintText: 'Correo electrónico'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombre,
                  style: const TextStyle(color: Colors.black),
                  decoration: const InputDecoration(hintText: 'Nombre público (solo si eres nuevo)'),
                ),
                CheckboxListTile(
                  value: _acepta,
                  onChanged: (v) => setState(() => _acepta = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Acepto las condiciones de uso y el aviso de privacidad',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: _cargando ? null : _enviar, child: const Text('ENVIAR CÓDIGO')),
              ] else ...[
                Text('Enviamos un código a ${_correo.text}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: _codigo,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black, fontSize: 24, letterSpacing: 6),
                  decoration: const InputDecoration(hintText: '000000'),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _cargando ? null : _verificar, child: const Text('ENTRAR')),
                TextButton(
                  onPressed: () => setState(() => _codigoEnviado = false),
                  child: const Text('Cambiar correo'),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
