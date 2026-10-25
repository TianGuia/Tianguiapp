import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Pantalla inicial. El comprador NO hace login: solo elige un nombre de usuario.
/// Vendedores y administradores entran por el enlace de abajo (correo + código).
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});
  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  final _auth = AuthService();
  final _nombre = TextEditingController();
  bool _acepta = false, _cargando = false;

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _entrar() async {
    final n = _nombre.text.trim();
    if (n.isEmpty) return _msg('Elige un nombre de usuario');
    if (n.length > 30) return _msg('El nombre puede tener máximo 30 caracteres');
    if (!_acepta) {
      return _msg('Debes aceptar las condiciones de uso y el aviso de privacidad');
    }
    setState(() => _cargando = true);
    try {
      await _auth.entrarComoComprador(n);
      // AuthGate detecta la sesión y cambia a Home.
    } catch (e) {
      _msg('No se pudo entrar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              const Text('¿Cómo quieres que te llamemos?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _nombre,
                maxLength: 30,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _entrar(),
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Nombre de usuario',
                  counterText: '',
                ),
              ),
              CheckboxListTile(
                value: _acepta,
                onChanged: (v) => setState(() => _acepta = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Acepto las condiciones de uso y el aviso de privacidad',
                    style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _cargando ? null : _entrar,
                child: _cargando
                    ? const SizedBox(
                        height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Text('ENTRAR'),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _cargando
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        ),
                child: const Text('Soy vendedor o administrador'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
