import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/theme.dart';

// rf-49 se cumple aqui: las zonas, pasillos y espacios que registra el administrador
// se dibujan sobre el mapa del comprador. La geometria es GeoJSON ([longitud, latitud]):
// Polygon para zonas y espacios, LineString para pasillos y Point para un espacio puntual.
class CapasZonas {
  final List<Polygon> poligonos = [];
  final List<Polyline> lineas = [];
  final List<Marker> etiquetas = [];
  bool get vacia => poligonos.isEmpty && lineas.isEmpty && etiquetas.isEmpty;
}

Color _color(String? tipo) => switch (tipo) {
      'pasillo' => Tg.amarillo,
      'espacio' => Tg.verde,
      _ => Tg.azulClaro,
    };

LatLng? _punto(dynamic c) {
  if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
    return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
  }
  return null;
}

List<LatLng> _puntos(dynamic c) => [
      if (c is List)
        for (final p in c)
          if (_punto(p) != null) _punto(p)!
    ];

CapasZonas capasDeZonas(List<Map<String, dynamic>> zonas) {
  final capas = CapasZonas();
  for (final z in zonas) {
    try {
      var g = z['geometria'];
      if (g is Map && g['type'] == 'Feature') g = g['geometry'];
      if (g is! Map) continue;
      final color = _color(z['tipo'] as String?);
      final nombre = '${z['nombre'] ?? ''}';
      List<LatLng> pts;
      switch (g['type']) {
        case 'Polygon':
          final anillos = g['coordinates'] as List;
          pts = anillos.isEmpty ? [] : _puntos(anillos.first);
          if (pts.length < 3) continue;
          capas.poligonos.add(Polygon(
            points: pts,
            color: color.withValues(alpha: 0.25),
            borderColor: color,
            borderStrokeWidth: 2,
          ));
        case 'LineString':
          pts = _puntos(g['coordinates']);
          if (pts.length < 2) continue;
          capas.lineas.add(Polyline(points: pts, strokeWidth: 5, color: color));
        case 'Point':
          final p = _punto(g['coordinates']);
          if (p == null) continue;
          pts = [p];
        default:
          continue;
      }
      // la etiqueta va en el centro de la figura
      final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      if (nombre.isNotEmpty) {
        capas.etiquetas.add(Marker(
          point: LatLng(lat, lng),
          width: 120,
          height: 28,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Tg.azulOscuro.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Text(nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ));
      }
    } catch (_) {
      // una geometria mal escrita no debe tumbar el mapa, solo se omite esa zona
    }
  }
  return capas;
}
