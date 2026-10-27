import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../models/modelos.dart';

/// RF-09 / RF-10: mapa de los puestos abiertos con su última ubicación
/// registrada (no es rastreo continuo). Usa teselas de OpenStreetMap.
class MapaPuestos extends StatelessWidget {
  final List<Puesto> puestos;
  final List<Tianguis> tianguis;
  final String? idTianguis;
  const MapaPuestos({
    super.key,
    required this.puestos,
    required this.tianguis,
    this.idTianguis,
  });

  /// Centro: el tianguis elegido; si no, el primer puesto con ubicación;
  /// si no, el primer tianguis con coordenadas; si no, Guadalajara.
  LatLng _centro(List<Puesto> conUbicacion) {
    final t = tianguis.where((t) => t.id == idTianguis && t.lat != null).firstOrNull;
    if (t != null) return LatLng(t.lat!, t.lng!);
    if (conUbicacion.isNotEmpty) return LatLng(conUbicacion.first.lat!, conUbicacion.first.lng!);
    final cualquiera = tianguis.where((t) => t.lat != null).firstOrNull;
    if (cualquiera != null) return LatLng(cualquiera.lat!, cualquiera.lng!);
    return const LatLng(20.6597, -103.3496);
  }

  void _detalle(BuildContext context, Puesto p) {
    final nombreTianguis = tianguis.where((t) => t.id == p.idTianguis).firstOrNull?.nombre;
    final hora = p.fechaApertura;
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nombre, style: Tg.marcador(22)),
          const SizedBox(height: 6),
          if (nombreTianguis != null) Text(nombreTianguis),
          Text(p.textoEstado, style: const TextStyle(color: Tg.verde, fontWeight: FontWeight.w800)),
          if (hora != null)
            Text('Ubicación registrada a las '
                '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}'),
          if ((p.descripcion ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(p.descripcion!),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conUbicacion = puestos.where((p) => p.lat != null && p.lng != null).toList();
    return Stack(children: [
      FlutterMap(
        options: MapOptions(initialCenter: _centro(conUbicacion), initialZoom: 17),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'mx.udg.alumnos.tianguia',
          ),
          MarkerLayer(markers: [
            for (final p in conUbicacion)
              Marker(
                point: LatLng(p.lat!, p.lng!),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () => _detalle(context, p),
                  child: const Icon(Icons.location_on, size: 44, color: Tg.rosa),
                ),
              ),
          ]),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ]),
        ],
      ),
      if (conUbicacion.isEmpty)
        const Align(
          alignment: Alignment.topCenter,
          child: Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Ningún puesto abierto con ubicación registrada'),
            ),
          ),
        ),
    ]);
  }
}
