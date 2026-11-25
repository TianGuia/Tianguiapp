import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../screens/puestos_tab.dart';
import '../services/catalogo_service.dart';
import '../services/inicio_service.dart';
import '../services/datos_en_vivo.dart';
import 'aviso_sincronizacion.dart';

// RF-10 se cumple aqui: se ve si el puesto esta abierto o cerrado y donde estaba la ultima vez
class UbicacionProducto extends StatefulWidget {
  final String? idPuesto;
  const UbicacionProducto({super.key, required this.idPuesto});
  @override
  State<UbicacionProducto> createState() => _UbicacionProductoState();
}

class _UbicacionProductoState extends State<UbicacionProducto> {
  late final DatosEnVivo<(Puesto?, List<Tianguis>)>? _datos;

  @override
  void initState() {
    super.initState();
    final id = widget.idPuesto;
    _datos = id == null
        ? null
        : DatosEnVivo(
            () => (InicioService().puestoPorId(id), CatalogoService().tianguis()).wait,
            tablas: {
              'puestos': PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: id,
              ),
              'tianguis': null,
            },
          );
  }

  @override
  void dispose() {
    _datos?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = _datos;
    if (estado == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Este producto no está asociado a un puesto todavía.'),
        ),
      );
    }
    return ListenableBuilder(
      listenable: estado,
      builder: (_, __) {
        final aviso = estado.desactualizado
            ? AvisoSincronizacion(hayDatos: estado.hayDatos, onReintentar: estado.recargar)
            : const SizedBox.shrink();
        final datos = estado.datos;
        final p = datos?.$1;
        if (p == null) return aviso;
        final tianguis = datos!.$2.where((t) => t.id == p.idTianguis).firstOrNull;
        final conUbicacion = p.abierto && p.tieneUbicacion;
        final hora = p.fechaApertura;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              aviso,
              Text('¿Dónde lo encuentro?', style: Tg.marcador(17)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.storefront, color: p.abierto ? Tg.verde : Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                Text(
                    'Ubicación registrada a las '
                    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (p.abierto && !conUbicacion)
                const Text('Sin ubicación registrada en esta jornada.',
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
                        body: PuestosTab(
                          iniciaEnMapa: true,
                          tianguisInicial: p.idTianguis,
                          puestoEnMapa: p.id,
                        ),
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
