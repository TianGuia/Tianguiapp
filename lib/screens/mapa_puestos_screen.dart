import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/puestos_service.dart';
import '../widgets/zonas_mapa.dart';
import '../widgets/urbano.dart';

// rf-04 se cumple aqui: se ven en un mapa los puestos que estan abiertos
// rf-05 se cumple aqui: se ve si el puesto esta abierto o cerrado y donde estaba la ultima vez
// la ubicacion es la ultima que registro el vendedor, no se le sigue en tiempo real
class MapaPuestos extends StatefulWidget {
  final List<Puesto> puestos;
  final List<Tianguis> tianguis;
  final String? idTianguis;
  const MapaPuestos({
    super.key,
    required this.puestos,
    required this.tianguis,
    this.idTianguis,
  });

  @override
  State<MapaPuestos> createState() => _MapaPuestosState();
}

class _MapaPuestosState extends State<MapaPuestos> {
  CapasZonas _zonas = CapasZonas();
  String _clave = '';

  List<Puesto> get puestos => widget.puestos;
  List<Tianguis> get tianguis => widget.tianguis;
  String? get idTianguis => widget.idTianguis;

  @override
  void initState() {
    super.initState();
    _cargarZonas();
  }

  @override
  void didUpdateWidget(MapaPuestos old) {
    super.didUpdateWidget(old);
    _cargarZonas();
  }

  // zonas del tianguis elegido, o de los tianguis de los puestos que se estan viendo
  Future<void> _cargarZonas() async {
    final ids = idTianguis != null
        ? [idTianguis!]
        : (puestos.map((p) => p.idTianguis).toSet().toList()..sort());
    final clave = ids.join(',');
    if (clave == _clave) return;
    _clave = clave;
    try {
      final z = await PuestosService().zonasDeTianguis(ids);
      if (mounted) setState(() => _zonas = capasDeZonas(z));
    } catch (_) {
      // sin zonas el mapa se ve igual, solo con los puestos
    }
  }

  // centro: el tianguis elegido; si no, el primer puesto con ubicacion;
  // si no, el primer tianguis con coordenadas; si no, guadalajara.
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
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Tg.azulOscuro,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CintaTricolor(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SelloTg(
                    icono: Icons.storefront,
                    color: p.abierto ? Tg.verde : Colors.grey.shade600,
                    colorIcono: Colors.white,
                    tam: 50),
                const SizedBox(width: 12),
                Expanded(child: Text(p.nombre, style: Tg.marcador(24))),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                PildoraTg(p.textoEstado,
                    color: p.abierto ? Tg.verde : Colors.grey.shade700,
                    colorTexto: Colors.white,
                    icono: p.abierto ? Icons.check_circle : Icons.schedule),
                if (nombreTianguis != null)
                  PildoraTg(nombreTianguis, color: Tg.rosa, colorTexto: Colors.white, icono: Icons.place),
                if (hora != null)
                  PildoraTg(
                      'Ubicación a las '
                      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
                      icono: Icons.my_location),
              ]),
              if ((p.descripcion ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.descripcion!, style: const TextStyle(fontSize: 16)),
              ],
            ]),
          ),
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
          PolygonLayer(polygons: _zonas.poligonos),
          PolylineLayer(polylines: _zonas.lineas),
          MarkerLayer(markers: _zonas.etiquetas),
          MarkerLayer(markers: [
            for (final p in conUbicacion)
              Marker(
                point: LatLng(p.lat!, p.lng!),
                width: 48,
                height: 48,
                child: GestureDetector(
                  onTap: () => _detalle(context, p),
                  child: Icon(Icons.location_on,
                      size: 44, color: p.abierto ? Tg.rosa : Colors.grey.shade600),
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
          child: TarjetaTg(
            margen: EdgeInsets.all(12),
            acento: Tg.amarillo,
            child: Row(children: [
              Icon(Icons.location_off, color: Tg.amarillo),
              SizedBox(width: 10),
              Expanded(
                child: Text('Ningún puesto abierto con ubicación registrada',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
    ]);
  }
}
