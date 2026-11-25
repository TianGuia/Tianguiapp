import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/datos_en_vivo.dart';
import '../services/favoritos_cambios.dart';
import '../services/inicio_service.dart';
import '../services/puestos_service.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';
import '../widgets/aviso_sincronizacion.dart';
import '../widgets/visita_flow.dart';
import 'mapa_puestos_screen.dart';
import 'puesto_screen.dart';

// aqui se cumplen rf-04, rf-05, rf-41, rf-42, cada parte de abajo dice cual cumple
class PuestosTab extends StatefulWidget {
  final bool iniciaEnMapa;
  final String? tianguisInicial;
  final String? puestoEnMapa;
  const PuestosTab({super.key, this.iniciaEnMapa = false, this.tianguisInicial, this.puestoEnMapa});
  @override
  State<PuestosTab> createState() => _PuestosTabState();
}

class _PuestosTabState extends State<PuestosTab> {
  final _catalogo = CatalogoService();
  final _puestos = PuestosService();
  late String? _filtro = widget.tianguisInicial;
  late bool _mapa = widget.iniciaEnMapa;
  bool _favTianguis = false;
  final _inicio = InicioService();
  late final DatosEnVivo<(List<Puesto>, List<Tianguis>, List<Map<String, dynamic>>)> _datos;
  List<Tianguis> get _tianguis => _datos.datos?.$2 ?? [];

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
    _datos.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _datos = DatosEnVivo(
      () => (_puestos.consultarMapa(), _catalogo.tianguis(), _puestos.zonasDeTianguis()).wait,
      tablas: {'puestos': null, 'tianguis': null, 'tianguis_zonas': null},
    );
    FavoritosCambios.version.addListener(_refrescarFavTianguis);
    _refrescarFavTianguis();
  }

  void _filtrar(String? id) {
    setState(() {
      _filtro = id;
      _favTianguis = false;
    });
    _refrescarFavTianguis();
  }

  Future<void> _alternarFavTianguis() async {
    final id = _filtro;
    if (id == null) return;
    try {
      final v = await _inicio.alternarFavoritoTianguis(id);
      if (mounted && _filtro == id) setState(() => _favTianguis = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
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
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _datos,
        builder: (context, _) => _contenido(context),
      );

  Widget _contenido(BuildContext context) {
    final nombres = {for (final t in _tianguis) t.id: t.nombre};
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => confirmarVisita(context),
        icon: const Icon(Icons.verified),
        label: const Text('Ya visité un puesto', style: TextStyle(fontWeight: FontWeight.w800)),
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
        if (_datos.desactualizado)
          AvisoSincronizacion(hayDatos: _datos.hayDatos, onReintentar: _datos.recargar),
        Expanded(child: _resultados(nombres)),
      ]),
    );
  }

  Widget _resultados(Map<String, String> nombres) {
    final datos = _datos.datos;
    if (datos == null) {
      return _datos.desactualizado ? const SizedBox.shrink() : const CargandoTg();
    }
    final l = datos.$1
        .where(
          (p) => nombres.containsKey(p.idTianguis) && (_filtro == null || p.idTianguis == _filtro),
        )
        .toList();
    if (_mapa) {
      final enfocado = _filtro == widget.tianguisInicial ? widget.puestoEnMapa : null;
      return MapaPuestos(
        key: ValueKey(_filtro),
        puestos: enfocado == null ? l : l.where((p) => p.id == enfocado).toList(),
        tianguis: _tianguis,
        zonas: datos.$3,
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
      return RefreshIndicator(
          onRefresh: _datos.recargar,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
            cabecera,
            const SizedBox(
              height: 360,
              child: EstadoVacio(
                icono: Icons.storefront_outlined,
                titulo: '¡Aún no se pone nadie!',
                mensaje:
                    'Ningún puesto abierto por ahora. Vuelve en un rato o prueba otro tianguis.',
              ),
            ),
          ]));
    }
    return RefreshIndicator(
        onRefresh: _datos.recargar,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: Tg.marcador(19)),
                    if (tia != null)
                      Text(tia,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      PildoraTg(p.textoEstado,
                          color: p.abierto ? Tg.verde : Colors.grey.shade700,
                          colorTexto: Colors.white,
                          icono: p.abierto ? Icons.check_circle : Icons.schedule),
                      if (p.abierto)
                        PildoraTg(p.tieneUbicacion ? 'CON UBICACIÓN' : 'SIN UBICACIÓN',
                            color: p.tieneUbicacion ? Tg.rosa : Colors.grey.shade700,
                            colorTexto: Colors.white,
                            icono: p.tieneUbicacion ? Icons.location_on : Icons.location_off),
                    ]),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ]),
            );
          },
        ));
  }
}
