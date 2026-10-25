import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/puestos_service.dart';

/// RF-09, RF-10: puestos abiertos + última ubicación registrada.
/// (El mapa visual con Google Maps / flutter_map se agrega después sobre esta lista.)
class PuestosTab extends StatefulWidget {
  const PuestosTab({super.key});
  @override
  State<PuestosTab> createState() => _PuestosTabState();
}

class _PuestosTabState extends State<PuestosTab> {
  final _catalogo = CatalogoService();
  final _puestos = PuestosService();
  List<Tianguis> _tianguis = [];
  String? _filtro;
  late Future<List<Puesto>> _futuro = _puestos.abiertos();

  @override
  void initState() {
    super.initState();
    _catalogo.tianguis().then((t) => setState(() => _tianguis = t));
  }

  void _filtrar(String? id) => setState(() {
        _filtro = id;
        _futuro = _puestos.abiertos(idTianguis: id);
      });

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final t in _tianguis) t.id: t.nombre};
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: const Text('Todos'), selected: _filtro == null, onSelected: (_) => _filtrar(null)),
          ),
          for (final t in _tianguis)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: Text(t.nombre), selected: _filtro == t.id, onSelected: (_) => _filtrar(t.id)),
            ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => _filtrar(_filtro),
          child: FutureBuilder<List<Puesto>>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return Center(child: Text('Error: ${s.error}'));
              final l = s.data!;
              if (l.isEmpty) return const Center(child: Text('Ningún puesto abierto por ahora'));
              return ListView.builder(
                itemCount: l.length,
                itemBuilder: (_, i) {
                  final p = l[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.circle, color: Tg.verde, size: 14),
                      title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${nombres[p.idTianguis] ?? ''}'
                          '${p.lat != null ? '\n📍 ${p.lat!.toStringAsFixed(5)}, ${p.lng!.toStringAsFixed(5)}' : ''}'),
                      isThreeLine: p.lat != null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ]);
  }
}
