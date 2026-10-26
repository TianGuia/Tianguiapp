import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// RF-04: cierra sesión. Si la cuenta es anónima, advierte que se pierde.
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
          'Tu cuenta no tiene correo verificado. Si cierras sesión perderás '
          'tus favoritos, mensajes y apartados, y no podrás recuperarlos.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CERRAR SESIÓN')),
      ],
    ),
  );
  if (ok == true) await auth.cerrarSesion();
}
