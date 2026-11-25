import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// RF-04 se cumple aqui: la persona puede salir de su cuenta en este telefono
// Una cuenta anónima necesita un correo verificado para recuperarse tras salir.
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
          'Tu cuenta es anónima. Verifica tu correo en el perfil antes de salir si '
          'quieres volver a acceder a tus favoritos, mensajes y apartados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CERRAR SESIÓN')),
      ],
    ),
  );
  if (ok == true) await auth.cerrarSesion();
}
