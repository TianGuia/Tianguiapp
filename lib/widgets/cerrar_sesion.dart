import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// RF-04: cierra sesión.
/// - Cuenta con correo verificado: cierra la sesión (se vuelve a entrar con código).
/// - Cuenta anónima: la sesión queda guardada en este teléfono; se vuelve a
///   entrar escribiendo el mismo nombre. Si se borra la app, se pierde.
Future<void> confirmarCerrarSesion(BuildContext context) async {
  final auth = AuthService();
  if (!auth.esAnonimo) {
    await auth.cerrarSesion();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('¿Cerrar sesión?'),
      content: const Text(
          'Tu cuenta no tiene correo verificado. En este teléfono podrás volver a '
          'entrar escribiendo el mismo nombre de usuario. Si borras la app, '
          'perderás tus favoritos, mensajes y apartados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CERRAR SESIÓN')),
      ],
    ),
  );
  if (ok == true) await auth.ocultarSesion();
}
