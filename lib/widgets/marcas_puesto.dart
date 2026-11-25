import 'package:flutter/material.dart';
import '../config/theme.dart';

// Marcas de un puesto: NUEVO y VETERANO. Las calcula la base de datos
// (v_puestos_resumen), aqui solo se dibujan. Al tocarlas en la ficha se explica
// que hay que hacer para tenerlas.
class MarcasPuesto extends StatelessWidget {
  final bool esNuevo, esVeterano;
  // true en tarjetas chicas: sin explicacion al tocar y con letra mas pequeña
  final bool compacta;
  const MarcasPuesto({
    super.key,
    required this.esNuevo,
    required this.esVeterano,
    this.compacta = false,
  });

  static const _verde = Color(0xFF1E8E3E);

  @override
  Widget build(BuildContext context) {
    if (!esNuevo && !esVeterano) return const SizedBox.shrink();
    final marcas = Wrap(spacing: 6, runSpacing: 6, children: [
      if (esNuevo)
        _chip('NUEVO', Icons.auto_awesome, Tg.amarillo, Tg.azulOscuro),
      if (esVeterano)
        _chip('VETERANO', Icons.military_tech, Tg.rosa, Colors.white),
    ]);
    if (compacta) return marcas;
    return GestureDetector(onTap: () => explicar(context), child: marcas);
  }

  Widget _chip(String texto, IconData icono, Color fondo, Color letra) => Container(
        padding: EdgeInsets.symmetric(horizontal: compacta ? 7 : 10, vertical: compacta ? 2 : 4),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: compacta ? 13 : 17, color: letra),
          SizedBox(width: compacta ? 3 : 5),
          Text(texto,
              style: TextStyle(
                  color: letra, fontWeight: FontWeight.w900, fontSize: compacta ? 11 : 14)),
        ]),
      );

  static void explicar(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Tg.azulOscuro,
        title: const Text('¿Qué son estas marcas?'),
        content: const SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NUEVO', style: TextStyle(fontWeight: FontWeight.w900, color: Tg.amarillo)),
            SizedBox(height: 2),
            Text('Tiene menos de 30 días desde la primera vez que abrió. '
                'Se quita sola cuando se cumple el mes.'),
            SizedBox(height: 14),
            Text('VETERANO', style: TextStyle(fontWeight: FontWeight.w900, color: Tg.rosa)),
            SizedBox(height: 2),
            Text('Lleva más de 1 año, abrió al menos 12 veces y sigue abriendo, '
                'y 10 personas distintas lo calificaron con promedio de 4 o más. '
                'Se gana con el tiempo y con buen trato; si baja el promedio, se pierde.'),
            SizedBox(height: 14),
            Text('Solo cuentan calificaciones de personas que de verdad visitaron el '
                'puesto: el vendedor le da un código al llegar y la persona lo escribe '
                'en la app. Las del propio dueño no cuentan.',
                style: TextStyle(fontSize: 13)),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ),
    );
  }
}
