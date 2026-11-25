import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../widgets/entradas.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';
import '../widgets/aviso_sincronizacion.dart';
import 'producto_detalle_screen.dart';
import 'puesto_screen.dart' show TarjetaProducto;

// rf-01 se cumple aqui: se buscan productos escribiendo una palabra o eligiendo una categoria
// rf-02 se cumple aqui: los productos se filtran por tianguis, dia, categoria y precio
// rf-03 se cumple aqui: se muestra todo de un producto, como fotos, precio y quien lo vende
typedef _Filtros = (String, String?, String?, int?, num?, num?);

class CatalogoTab extends StatefulWidget {
  const CatalogoTab({super.key});
  @override
  State<CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<CatalogoTab> {
  final _svc = CatalogoService();
  final _texto = TextEditingController();
  List<Map<String, dynamic>> _cats = [];
  String? _cat;
  List<Tianguis> _tianguis = [];
  String? _idTianguis;
  int? _dia; // 0 = domingo … 6 = sabado
  num? _precioMin, _precioMax;
  late _Filtros _consultaActual = _criterios;
  late Future<List<Producto>> _futuro = _consultar(_consultaActual);
  _Filtros? _filtrosSincronizados;
  List<Producto>? _sincronizados;
  int _solicitud = 0;

  _Filtros get _criterios => (_texto.text.trim(), _cat, _idTianguis, _dia, _precioMin, _precioMax);

  Future<List<Producto>> _consultar(_Filtros filtros) async {
    final solicitud = ++_solicitud;
    final productos = await _svc.filtrarProductos(
      texto: filtros.$1, idCategoria: filtros.$2, idTianguis: filtros.$3,
      diaSemana: filtros.$4, precioMin: filtros.$5, precioMax: filtros.$6,
    ).timeout(const Duration(seconds: 10));
    if (mounted && solicitud == _solicitud) {
      _filtrosSincronizados = filtros;
      _sincronizados = productos;
    }
    return productos;
  }

  static const _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  int get _filtrosActivos =>
      (_idTianguis != null ? 1 : 0) +
      (_dia != null ? 1 : 0) +
      (_precioMin != null || _precioMax != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _svc.categorias().then((c) {
      if (mounted) setState(() => _cats = c);
    }).catchError((_) {});
    _svc.tianguis().then((t) {
      if (mounted) setState(() => _tianguis = t);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() => setState(() {
    _consultaActual = _criterios;
    _futuro = _consultar(_consultaActual);
  });

  void _reintentar() => setState(() => _futuro = _consultar(_consultaActual));

  static const _negro = TextStyle(color: Colors.black);
  static const _etiquetaCampo = TextStyle(color: Colors.black54);

  Future<void> _filtros() async {
    FocusScope.of(context).unfocus();
    // si el tianguis elegido ya no esta activo, no se ofrece como valor del menu.
    var idT = _tianguis.any((t) => t.id == _idTianguis) ? _idTianguis : null;
    var dia = _dia;
    final min = TextEditingController(text: _precioMin?.toString() ?? '');
    final max = TextEditingController(text: _precioMax?.toString() ?? '');
    final aplicar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tg.azulOscuro,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filtrar productos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              // los campos del tema tienen fondo blanco, se fuerza el texto a negro o sale blanco sobre blanco
              const Text('Tianguis', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: idT,
                isExpanded: true,
                dropdownColor: Tg.azulOscuro,
                iconEnabledColor: Colors.black54,
                selectedItemBuilder: (_) => [
                  const Text('Todos los tianguis', style: _negro),
                  for (final t in _tianguis)
                    Text(t.nombre, style: _negro, overflow: TextOverflow.ellipsis),
                ],
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los tianguis')),
                  for (final t in _tianguis) DropdownMenuItem(value: t.id, child: Text(t.nombre)),
                ],
                onChanged: (v) => set(() => idT = v),
              ),
              const SizedBox(height: 14),
              const Text('Día de operación', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                ChoiceChip(
                  label: const Text('Cualquiera'),
                  selected: dia == null,
                  onSelected: (_) => set(() => dia = null),
                ),
                for (var i = 0; i < 7; i++)
                  ChoiceChip(
                    label: Text(_dias[i]),
                    selected: dia == i,
                    onSelected: (_) => set(() => dia = i),
                  ),
              ]),
              const SizedBox(height: 14),
              const Text('Rango de precio', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: min,
                    style: _negro,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Entradas.formatoDinero,
                    decoration: const InputDecoration(
                        hintText: 'Mínimo',
                        hintStyle: _etiquetaCampo,
                        prefixText: r'$ ',
                        prefixStyle: _negro),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: max,
                    style: _negro,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Entradas.formatoDinero,
                    decoration: const InputDecoration(
                        hintText: 'Máximo',
                        hintStyle: _etiquetaCampo,
                        prefixText: r'$ ',
                        prefixStyle: _negro),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                TextButton(
                  onPressed: () {
                    idT = null;
                    dia = null;
                    min.clear();
                    max.clear();
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('LIMPIAR'),
                ),
                const SizedBox(width: 12),
                // el FilledButton del tema ocupa todo el ancho, en un Row necesita Expanded o falla el layout
                Expanded(
                  child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true), child: const Text('APLICAR')),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
    final pMin = Entradas.leerDinero(min.text);
    final pMax = Entradas.leerDinero(max.text);
    min.dispose();
    max.dispose();
    if (aplicar != true || !mounted) return;
    if (pMin != null && pMax != null && pMin > pMax) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El precio mínimo no puede ser mayor al máximo')));
      return;
    }
    _idTianguis = idT;
    _dia = dia;
    _precioMin = pMin;
    _precioMax = pMax;
    _buscar();
  }

  void _quitarFiltros() {
    _idTianguis = null;
    _dia = null;
    _precioMin = null;
    _precioMax = null;
    _buscar();
  }

  String _textoPrecio() {
    String f(num v) => '\$${v == v.truncate() ? v.toInt() : v}';
    if (_precioMin != null && _precioMax != null) return '${f(_precioMin!)} – ${f(_precioMax!)}';
    if (_precioMin != null) return 'Desde ${f(_precioMin!)}';
    return 'Hasta ${f(_precioMax!)}';
  }

  Widget _chipsFiltros() {
    if (_filtrosActivos == 0) return const SizedBox.shrink();
    final tianguis = _tianguis.where((t) => t.id == _idTianguis).firstOrNull?.nombre;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          if (_idTianguis != null)
            InputChip(
              label: Text(tianguis ?? 'Tianguis'),
              onDeleted: () {
                _idTianguis = null;
                _buscar();
              },
            ),
          if (_dia != null)
            InputChip(
              label: Text(_dias[_dia!]),
              onDeleted: () {
                _dia = null;
                _buscar();
              },
            ),
          if (_precioMin != null || _precioMax != null)
            InputChip(
              label: Text(_textoPrecio()),
              onDeleted: () {
                _precioMin = null;
                _precioMax = null;
                _buscar();
              },
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(
            controller: _texto,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            decoration: InputDecoration(
              hintText: 'Buscar antojitos, ropa, chacharas…',
              prefixIcon: const Icon(Icons.search, color: Tg.azul),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Filtros',
                  icon: Badge(
                    isLabelVisible: _filtrosActivos > 0,
                    label: Text('$_filtrosActivos'),
                    child: const Icon(Icons.tune, color: Tg.azul),
                  ),
                  onPressed: _filtros,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Tg.azul),
                  onPressed: _buscar,
                ),
              ]),
            ),
          ),
        ),
        _chipsFiltros(),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipCategoria(
                  texto: 'Todas',
                  icono: Icons.storefront,
                  seleccionado: _cat == null,
                  onTap: () {
                    _cat = null;
                    _buscar();
                  },
                ),
              ),
              for (final c in _cats)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChipCategoria(
                    texto: c['nombre'] as String,
                    icono: iconoCategoria(c['nombre'] as String),
                    seleccionado: _cat == c['id'],
                    onTap: () {
                      _cat = c['id'] as String;
                      _buscar();
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<Producto>>(
            future: _futuro,
            builder: (_, s) {
              final cache = _consultaActual == _filtrosSincronizados ? _sincronizados : null;
              final l = s.connectionState == ConnectionState.done && !s.hasError ? s.data : cache;
              final aviso = s.connectionState == ConnectionState.done && s.hasError
                  ? AvisoSincronizacion(hayDatos: l != null, onReintentar: _reintentar)
                  : null;
              if (l == null) {
                return aviso == null ? const CargandoTg() : Align(alignment: Alignment.topCenter, child: aviso);
              }

              Widget conAviso(Widget contenido) => aviso == null ? contenido : Column(children: [
                aviso,
                Expanded(child: contenido),
              ]);
              if (l.isEmpty) {
                return conAviso(EstadoVacio(
                  icono: Icons.search_off,
                  titulo: '¡Nel, nada por aquí!',
                  mensaje: _filtrosActivos > 0
                      ? 'No hay nada con estos filtros. Quítalos para ver más.'
                      : 'Prueba con otra palabra o elige otra categoría.',
                  accionTexto: _filtrosActivos > 0 ? 'Quitar filtros' : null,
                  accionIcono: Icons.filter_alt_off,
                  onAccion: _filtrosActivos > 0 ? _quitarFiltros : null,
                ));
              }
              return conAviso(ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                itemCount: l.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return CabeceraTg(
                      titulo: 'Catálogo',
                      subtitulo: 'Lo que se vende en los tianguis',
                      icono: Icons.shopping_bag,
                      color: Tg.rosa,
                      datos: [
                        DatoTg(Icons.inventory_2, Tg.amarillo, '${l.length}', 'PRODUCTOS'),
                        DatoTg(Icons.storefront, Tg.verde,
                            '${l.where((p) => p.puestoEstado == 'abierto').length}', 'EN PUESTO ABIERTO'),
                      ],
                    );
                  }
                  final p = l[i - 1];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    child: TarjetaProducto(
                      producto: p,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: p)),
                      ),
                    ),
                  );
                },
              ));
            },
          ),
        ),
      ]);
}
