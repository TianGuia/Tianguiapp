import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';

/// RF-01 / RF-40: entrar SIN iniciar sesión. Solo se elige un nombre público.
class AccesoScreen extends StatefulWidget {
  final VoidCallback onVolver;
  final VoidCallback onTengoCuenta;
  const AccesoScreen({super.key, required this.onVolver, required this.onTengoCuenta});
  @override
  State<AccesoScreen> createState() => _AccesoScreenState();
}

class _AccesoScreenState extends State<AccesoScreen> {
  final _auth = AuthService();
  final _nombre = TextEditingController();
  bool _acepta = false, _cargando = false;
  String? _errorNombre;

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _entrar() async {
    final n = _nombre.text.trim();
    if (n.isEmpty) return _msg('Elige un nombre de usuario');
    if (!_acepta) return _msg('Debes aceptar las condiciones de uso y el aviso de privacidad');
    setState(() {
      _cargando = true;
      _errorNombre = null;
    });
    try {
      await _auth.entrarAnonimo(n);
      // AuthGate detecta la sesión y muestra el Home.
    } on NombreEnUsoException {
      if (mounted) setState(() => _errorNombre = 'Este nombre de usuario ya existe, elige otro');
    } catch (e) {
      _msg('No se pudo entrar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset('assets/images/logo.png', width: 150, height: 150),
                  ),
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.05,
                    child: Text('COMIDA, ANTOJITOS Y MÁS…', style: Tg.marcador(15)),
                  ),
                  const SizedBox(height: 26),
                  const Text('¿Cómo quieres que te llamemos?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nombre,
                    maxLength: 30,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _entrar(),
                    style: const TextStyle(color: Colors.black),
                    onChanged: (_) {
                      if (_errorNombre != null) setState(() => _errorNombre = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'Nombre de usuario',
                      counterText: '',
                      errorText: _errorNombre,
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
                  const Text(
                    'Tu cuenta se guarda en este teléfono. Si borras la app perderás tus '
                    'favoritos y mensajes, salvo que verifiques tu correo en el Perfil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  BotonPincel(texto: 'ENTRAR', cargando: _cargando, onPressed: _cargando ? null : _entrar),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _cargando ? null : widget.onTengoCuenta,
                    child: const Text('Ya tengo cuenta con correo'),
                  ),
                ]),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, size: 28),
                onPressed: widget.onVolver,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
