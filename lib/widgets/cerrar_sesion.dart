import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// rf-35 se cumple aqui: la persona puede salir de su cuenta en este telefono
// con correo verificado cierra la sesion y se entra con codigo
// cuenta anonima: la sesion queda en el telefono y se entra con el mismo nombre
// si se borra la app se pierde
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
