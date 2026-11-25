import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/favoritos_cambios.dart';
import '../services/inicio_service.dart';
import '../services/puestos_service.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';
import '../widgets/visita_flow.dart';
import 'mapa_puestos_screen.dart';
import 'puesto_screen.dart';

// aqui se cumplen rf-04, rf-05, rf-41, rf-42, cada parte de abajo dice cual cumple
class PuestosTab extends StatefulWidget {
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
  late Future<List<Puesto>> _futuro = _puestos.consultarMapa();

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
      _futuro = _puestos.consultarMapa(idTianguis: id);
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

  // abre la ficha del puesto con los datos que ya tenemos, la ficha trae lo demas
  void _abrir(Puesto p, String? tianguis) {
    final r = PuestoResumen.fromMap({
      'id': p.id,
      'nombre': p.nombre,
      'id_tianguis': p.idTianguis,
      'tianguis_nombre': tianguis,
      'descripcion': p.descripcion,
      'abierto': p.abierto,
    });
    Navigator.push(context, MaterialPageRoute(builder: (_) => PuestoScreen(puesto: r)));
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
                if (s.connectionState != ConnectionState.done) return const CargandoTg();
                if (s.hasError) {
                  return ListView(children: [
                    SizedBox(
                      height: 420,
                      child: EstadoVacio(
                        icono: Icons.cloud_off,
                        color: Tg.rosa,
                        titulo: 'No se pudo cargar',
                        mensaje: 'Revisa tu conexión y jala para intentar otra vez.\n${s.error}',
                        accionTexto: 'Reintentar',
                        accionIcono: Icons.refresh,
                        onAccion: () => _filtrar(_filtro),
                      ),
                    ),
                  ]);
                }
                final l = s.data!;
                if (_mapa) {
                  return MapaPuestos(
                    puestos: l,
                    tianguis: _tianguis,
                    idTianguis: _filtro,
                  );
                }
                final abiertos = l.where((p) => p.abierto).length;
                final cabecera = CabeceraTg(
                  titulo: _filtro == null ? 'Explora los puestos' : (nombres[_filtro] ?? 'Tianguis'),
                  subtitulo: 'Quién se puso hoy y dónde',
                  icono: Icons.explore,
                  color: Tg.verde,
                  datos: [
                    DatoTg(Icons.storefront, Tg.verde, '$abiertos', 'ABIERTOS'),
                    DatoTg(Icons.list_alt, Tg.amarillo, '${l.length}', 'PUESTOS'),
                    DatoTg(Icons.place, Tg.rosa, '${_tianguis.length}', 'TIANGUIS',
                        onTap: () => setState(() => _mapa = true)),
                  ],
                );
                if (l.isEmpty) {
                  return ListView(children: [
                    cabecera,
                    const SizedBox(
                      height: 360,
                      child: EstadoVacio(
                        icono: Icons.storefront_outlined,
                        titulo: '¡Aún no se pone nadie!',
                        mensaje: 'Ningún puesto abierto por ahora. Vuelve en un rato o prueba otro tianguis.',
                      ),
                    ),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: l.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) return cabecera;
                    final p = l[i - 1];
                    final tia = nombres[p.idTianguis];
                    return TarjetaTg(
                      acento: p.abierto ? Tg.verde : Colors.grey,
                      onTap: () => _abrir(p, tia),
                      child: Row(children: [
                        SelloTg(
                            icono: Icons.storefront,
                            color: p.abierto ? Tg.verde : Colors.grey.shade600,
                            colorIcono: Colors.white,
                            tam: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Tg.marcador(19)),
                            if (tia != null)
                              Text(tia,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              PildoraTg(p.textoEstado,
                                  color: p.abierto ? Tg.verde : Colors.grey.shade700,
                                  colorTexto: Colors.white,
                                  icono: p.abierto ? Icons.check_circle : Icons.schedule),
                              if (p.lat != null)
                                const PildoraTg('CON UBICACIÓN',
                                    color: Tg.rosa, colorTexto: Colors.white, icono: Icons.location_on),
                            ]),
                          ]),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ]),
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
