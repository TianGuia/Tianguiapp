import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/puestos_service.dart';
import 'entradas.dart';
import 'urbano.dart';
import 'mensaje.dart';

const _negro = TextStyle(color: Colors.black);

void _msg(BuildContext c, String t) => mostrarMensaje(c, t);

// RF-41 se cumple aqui: el comprador escribe el codigo que le da el vendedor para confirmar que si fue al puesto
// RF-42 se cumple aqui: despues de una visita confirmada el comprador deja su calificacion
Future<void> confirmarVisita(BuildContext context) async {
  final svc = PuestosService();
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => DialogoTg(
      icono: Icons.verified,
      titulo: 'Código de visita',
      acciones: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('CONFIRMAR')),
      ],
      child: Column(children: [
        const Text('Pídele al vendedor el código que ve en su celular y escríbelo aquí.',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 12),
        TextField(
          controller: c,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: Entradas.formatoCodigoVisita,
          style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 6),
          decoration: const InputDecoration(hintText: '········'),
        ),
      ]),
    ),
  );
  if (ok != true || c.text.trim().isEmpty || !context.mounted) return;
  try {
    final idVisita = await svc.verificarVisita(c.text);
    if (!context.mounted) return;
    _msg(context, '¡Visita confirmada!');
    await _calificar(context, svc, idVisita);
  } catch (e) {
    if (context.mounted) _msg(context, '$e');
  }
}

Future<void> _calificar(BuildContext context, PuestosService svc, String idVisita) async {
  int estrellas = 5;
  final com = TextEditingController();
  final etiquetas = await svc.etiquetasValoracion();
  if (!context.mounted) return;
  final elegidas = <String>{};
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => DialogoTg(
        icono: Icons.star_rounded,
        titulo: 'Califica tu visita',
        acciones: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('DESPUÉS')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ENVIAR')),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(i <= estrellas ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Tg.amarillo, size: 38),
                onPressed: () => set(() => estrellas = i),
              ),
          ]),
          if (etiquetas.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('¿Cómo fue? (opcional)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const Text('Las etiquetas las verá todo el mundo en el puesto.',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in etiquetas)
                FichaTg(
                  texto: '${e['nombre']}',
                  elegida: elegidas.contains(e['id']),
                  onCambio: (v) => set(() {
                    v ? elegidas.add(e['id'] as String) : elegidas.remove(e['id']);
                  }),
                ),
            ]),
            const SizedBox(height: 14),
          ],
          const Text('Comentario (opcional)',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const Text('Solo lo lee el vendedor, no se muestra al público.',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
              controller: com,
              maxLines: 3,
              minLines: 2,
              style: _negro,
              inputFormatters: Entradas.texto(300),
              decoration: const InputDecoration(hintText: 'Cuéntale al vendedor cómo te fue')),
        ]),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await svc.registrarCalificacion(
      idVisita: idVisita,
      puntuacion: estrellas,
      comentario: com.text.trim().isEmpty ? null : com.text.trim(),
      idEtiquetas: elegidas.toList(),
    );
    if (context.mounted) _msg(context, 'Gracias por calificar');
  } catch (e) {
    if (context.mounted) _msg(context, '$e');
  }
}
