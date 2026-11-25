import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/fondo.dart';
import '../widgets/urbano.dart';
import '../services/auth_service.dart';
import '../widgets/entradas.dart';
import '../widgets/enlaces_legales.dart';
import '../widgets/mensaje.dart';

// RF-01 y RF-03: registro e inicio de sesión por correo con código de un solo uso.
// RF-40: solicita aceptar las condiciones y el aviso de privacidad.
// correo y codigo de un solo uso, es la unica entrada con correo
class LoginScreen extends StatefulWidget {
  final VoidCallback? onVolver;
  const LoginScreen({super.key, this.onVolver});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _codigo = TextEditingController();
  bool _codigoEnviado = false, _acepta = false, _cargando = false;

  static const _negro = TextStyle(color: Colors.black);

  void _msg(String t) => mostrarMensaje(context, t);

  Future<void> _enviar() async {
    if (!Entradas.correoValido(_correo.text)) return _msg('Escribe un correo válido');
    final nombre = _nombre.text.trim();
    if (nombre.isNotEmpty) {
      final errNombre = Entradas.errorNombre(nombre);
      if (errNombre != null) return _msg(errNombre);
    }
    if (!_acepta) return _msg('Debes aceptar las condiciones de uso y el aviso de privacidad');
    setState(() => _cargando = true);
    try {
      await _auth.enviarCodigo(_correo.text, nombre: nombre.isEmpty ? null : nombre);
      if (mounted) setState(() => _codigoEnviado = true);
    } catch (e) {
      _msg('No se pudo enviar el código: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verificar() async {
    if (_codigo.text.trim().length < 6) return _msg('Escribe el código que llegó a tu correo');
    setState(() => _cargando = true);
    try {
      await _auth.iniciarSesion(_correo.text, _codigo.text);
    } catch (e) {
      if (mounted) _msg('Código incorrecto o vencido: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
                    child: Image.asset('assets/images/icono_app.png', width: 150, height: 150),
                  ),
                  const SizedBox(height: 10),
                  Transform.rotate(
                    angle: -0.05,
                    child: Text('VÁMONOS DE TIANGUIS', style: Tg.marcador(15)),
                  ),
                  const SizedBox(height: 26),
              TarjetaTg(
                margen: EdgeInsets.zero,
                acento: Tg.amarillo,
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!_codigoEnviado) ...[
                TextField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: Entradas.formatoCorreo,
                  style: _negro,
                  decoration: const InputDecoration(hintText: 'Correo electrónico'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombre,
                  inputFormatters: Entradas.formatoNombre,
                  style: _negro,
                  decoration: const InputDecoration(hintText: 'Nombre público (solo si eres nuevo)'),
                ),
                CheckboxListTile(
                  value: _acepta,
                  onChanged: (v) => setState(() => _acepta = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Acepto las condiciones de uso y el aviso de privacidad',
                      style: TextStyle(fontSize: 13)),
                ),
                const EnlacesLegales(),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _cargando ? null : _enviar,
                  child: const Text('ENVIAR CÓDIGO'),
                ),
              ] else ...[
                Text('Enviamos un código a ${_correo.text}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                TextField(
                  controller: _codigo,
                  keyboardType: TextInputType.number,
                  inputFormatters: Entradas.formatoCodigoOtp,
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
                ])),
                ]),
              ),
            ),
            if (widget.onVolver != null)
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
