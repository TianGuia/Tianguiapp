import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../screens/mapa_puestos_screen.dart';
import '../services/catalogo_service.dart';
import '../services/inicio_service.dart';

/// RF-08 / RF-10: "¿Dónde lo encuentro?" en la ficha de un producto.
/// Muestra el puesto, si está abierto y su última ubicación registrada,
/// con acceso al mapa. Si está cerrado, indica el motivo y cuándo vuelve.
class UbicacionProducto extends StatefulWidget {
  final String? idPuesto;
  const UbicacionProducto({super.key, required this.idPuesto});
  @override
  State<UbicacionProducto> createState() => _UbicacionProductoState();
}

class _UbicacionProductoState extends State<UbicacionProducto> {
  late final Future<({Puesto? puesto, List<Tianguis> tianguis})> _futuro = _cargar();

  Future<({Puesto? puesto, List<Tianguis> tianguis})> _cargar() async {
    final p = await InicioService().puestoPorId(widget.idPuesto!);
    final t = await CatalogoService().tianguis();
    return (puesto: p, tianguis: t);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idPuesto == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Este producto no está asociado a un puesto todavía.'),
        ),
      );
    }
    return FutureBuilder(
      future: _futuro,
      builder: (_, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final p = s.data!.puesto;
        if (p == null) return const SizedBox.shrink();
        final tianguis = s.data!.tianguis.where((t) => t.id == p.idTianguis).firstOrNull;
        final conUbicacion = p.abierto && p.lat != null && p.lng != null;
        final hora = p.fechaApertura;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('¿Dónde lo encuentro?', style: Tg.marcador(17)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.storefront, color: p.abierto ? Tg.verde : Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ]),
              if (tianguis != null) Text('Tianguis: ${tianguis.nombre}'),
              if ((p.codigo ?? '').isNotEmpty) Text('Puesto ${p.codigo}'),
              const SizedBox(height: 4),
              Text(p.textoEstado,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: p.abierto ? const Color(0xFF2EAD5B) : Tg.rosa)),
              if (p.detalleCierre != null) Text(p.detalleCierre!),
              if (conUbicacion && hora != null)
                Text('Ubicación registrada a las '
                    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (p.abierto && !conUbicacion)
                const Text('Abierto, pero sin ubicación registrada.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (conUbicacion) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('VER EN EL MAPA'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(p.nombre)),
                        body: MapaPuestos(puestos: [p], tianguis: s.data!.tianguis, idTianguis: null),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
