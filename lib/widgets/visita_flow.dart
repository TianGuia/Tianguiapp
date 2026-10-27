import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/puestos_service.dart';

const _negro = TextStyle(color: Colors.black);

void _msg(BuildContext c, String t) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

/// RF-41 + RF-42: el comprador escribe el código que le muestra el vendedor
/// y después puede calificar su visita.
Future<void> confirmarVisita(BuildContext context) async {
  final svc = PuestosService();
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Código de visita'),
      content: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        style: _negro,
        decoration: const InputDecoration(
            hintText: 'Código que te muestra el vendedor'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar')),
      ],
    ),
  );
  if (ok != true || c.text.trim().isEmpty || !context.mounted) return;
  try {
    final visita = await svc.verificarVisita(c.text);
    if (!context.mounted) return;
    _msg(context, '¡Visita confirmada!');
    await _calificar(context, svc, visita.idVisita);
  } catch (e) {
    if (context.mounted) _msg(context, '$e');
  }
}

Future<void> _calificar(
    BuildContext context, PuestosService svc, String idVisita) async {
  int estrellas = 5;
  final com = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Califica tu visita'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(i <= estrellas ? Icons.star : Icons.star_border,
                    color: Tg.amarillo, size: 32),
                onPressed: () => set(() => estrellas = i),
              ),
          ]),
          TextField(
              controller: com,
              style: _negro,
              decoration:
                  const InputDecoration(hintText: 'Comentario (opcional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Después')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await svc.calificar(
      idVisita: idVisita,
      puntuacion: estrellas,
      comentario: com.text.trim().isEmpty ? null : com.text.trim(),
    );
    if (context.mounted) _msg(context, 'Gracias por calificar');
  } catch (e) {
    if (context.mounted) _msg(context, '$e');
  }
}
