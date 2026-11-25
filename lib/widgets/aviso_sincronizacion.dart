import 'package:flutter/material.dart';

class AvisoSincronizacion extends StatelessWidget {
  const AvisoSincronizacion({
    super.key,
    required this.hayDatos,
    required this.onReintentar,
  });

  final bool hayDatos;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.cloud_off),
          title: Text(hayDatos
              ? 'Mostrando los últimos datos sincronizados'
              : 'No se pudieron actualizar los datos'),
          trailing: TextButton(
              onPressed: onReintentar, child: const Text('Reintentar')),
        ),
      );
}
