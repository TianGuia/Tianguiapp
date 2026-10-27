import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/favoritos_cambios.dart';
import '../services/inicio_service.dart';
import '../services/puestos_service.dart';
import '../widgets/pincel.dart';
import '../widgets/visita_flow.dart';
import 'mapa_puestos_screen.dart';

/// RF-09, RF-10, RF-41, RF-42: puestos abiertos, confirmar visita y calificar.
/// (El mapa visual se agrega después sobre esta lista.)
class PuestosTab extends StatefulWidget {
  /// true = abre directo en la vista de mapa.
  final bool iniciaEnMapa;
  const PuestosTab({super.key, this.iniciaEnMapa = false});
  @override
  State<PuestosTab> createState() => _PuestosTabState();
}

class _PuestosTabState extends State<PuestosTab> {
  final _catalogo = CatalogoService();
  final _puestos = PuestosService();
  List<Tianguis> _tianguis = [];
  String? _filtro;
  late bool _mapa = widget.iniciaEnMapa;
  bool _favTianguis = false;
  final _inicio = InicioService();
  late Future<List<Puesto>> _futuro = _puestos.abiertos();

  void _refrescarFavTianguis() {
    final id = _filtro;
    if (id == null) return;
    _inicio.esFavoritoTianguis(id).then((v) {
      if (mounted && _filtro == id) setState(() => _favTianguis = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    FavoritosCambios.version.removeListener(_refrescarFavTianguis);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    FavoritosCambios.version.addListener(_refrescarFavTianguis);
    _catalogo.tianguis().then((t) {
      if (mounted) setState(() => _tianguis = t);
    }).catchError((_) {});
  }

  void _filtrar(String? id) {
    setState(() {
      _filtro = id;
      _favTianguis = false;
      _futuro = _puestos.abiertos(idTianguis: id);
    });
    if (id != null) {
      _inicio.esFavoritoTianguis(id).then((v) {
        if (mounted && _filtro == id) setState(() => _favTianguis = v);
      }).catchError((_) {});
    }
  }

  Future<void> _alternarFavTianguis() async {
    final id = _filtro;
    if (id == null) return;
    try {
      final v = await _inicio.alternarFavoritoTianguis(id);
      if (mounted) setState(() => _favTianguis = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final t in _tianguis) t.id: t.nombre};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => confirmarVisita(context),
        icon: const Icon(Icons.verified),
        label: const Text('Ya visité un puesto',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipCategoria(
                    texto: 'Todos',
                    icono: Icons.storefront,
                    seleccionado: _filtro == null,
                    onTap: () => _filtrar(null)),
              ),
              if (_filtro != null)
                IconButton(
                  tooltip: _favTianguis ? 'Quitar tianguis de favoritos' : 'Guardar tianguis',
                  icon: Icon(_favTianguis ? Icons.favorite : Icons.favorite_border,
                      color: _favTianguis ? Tg.rosa : Colors.white),
                  onPressed: _alternarFavTianguis,
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipCategoria(
                    texto: _mapa ? 'Ver lista' : 'Ver mapa',
                    icono: _mapa ? Icons.list : Icons.map,
                    seleccionado: _mapa,
                    onTap: () => setState(() => _mapa = !_mapa)),
              ),
              for (final t in _tianguis)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipCategoria(
                      texto: t.nombre,
                      icono: Icons.place,
                      seleccionado: _filtro == t.id,
                      onTap: () => _filtrar(t.id)),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _filtrar(_filtro),
            child: FutureBuilder<List<Puesto>>(
              future: _futuro,
              builder: (_, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
                }
                if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                final l = s.data!;
                if (_mapa) {
                  return MapaPuestos(
                    puestos: l,
                    tianguis: _tianguis,
                    idTianguis: _filtro,
                  );
                }
                if (l.isEmpty) {
                  return ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Ningún puesto abierto por ahora')),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90, top: 4),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final p = l[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Tg.verde,
                          child: Icon(Icons.storefront, color: Colors.white),
                        ),
                        title: Text(p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
      ]),
    );
  }
}
