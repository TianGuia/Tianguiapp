import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';

/// Acceso de administrador: una clave y la respuesta a una pregunta secreta.
/// La validación la hace el servidor (admin_entrar); la app no guarda ninguna.
class AdminEntradaScreen extends StatefulWidget {
  const AdminEntradaScreen({super.key});
  @override
  State<AdminEntradaScreen> createState() => _AdminEntradaScreenState();
}

class _AdminEntradaScreenState extends State<AdminEntradaScreen> {
  final _auth = AuthService();
  final _nombre = TextEditingController();
  final _clave = TextEditingController();
  final _respuesta = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _clave.dispose();
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_nombre.text.trim().isEmpty || _clave.text.isEmpty || _respuesta.text.trim().isEmpty) {
      return setState(() => _error = 'Escribe tu nombre, la clave y la respuesta');
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _auth.entrarAdministrador(_nombre.text, _clave.text, _respuesta.text);
      // AuthGate detecta la sesión de administrador y muestra el panel.
      if (mounted) Navigator.pop(context);
    } on AdminAccesoException {
      if (mounted) setState(() => _error = 'Nombre, clave o respuesta incorrectos');
    } catch (e) {
      final m = '$e';
      if (mounted) {
        setState(() => _error = m.contains('Demasiados intentos')
            ? 'Demasiados intentos. Espera unos minutos.'
            : 'No se pudo entrar: $e');
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const negro = TextStyle(color: Colors.black);
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Administrador')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.admin_panel_settings, size: 64),
                const SizedBox(height: 20),
                TextField(
                  controller: _nombre,
                  style: negro,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: 'Tu nombre de administrador'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clave,
                  obscureText: true,
                  style: negro,
                  decoration: const InputDecoration(hintText: 'Clave'),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('¿Cuál es la comida más padre de México?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _respuesta,
                  style: negro,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _cargando ? null : _entrar(),
                  decoration: InputDecoration(hintText: 'Respuesta', errorText: _error),
                ),
                const SizedBox(height: 20),
                BotonPincel(
                    texto: 'ENTRAR', cargando: _cargando, onPressed: _cargando ? null : _entrar),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
