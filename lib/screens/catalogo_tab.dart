import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../widgets/entradas.dart';
import '../widgets/pincel.dart';
import 'producto_detalle_screen.dart';
import 'puesto_screen.dart' show TarjetaProducto;

/// RF-06, RF-07, RF-08: búsqueda y filtros de productos.
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
  int? _dia; // 0 = domingo … 6 = sábado
  num? _precioMin, _precioMax;
  late Future<List<Producto>> _futuro = _svc.buscar();

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

  void _buscar() {
    setState(() {
      _futuro = _svc.buscar(
        texto: _texto.text,
        idCategoria: _cat,
        idTianguis: _idTianguis,
        diaSemana: _dia,
        precioMin: _precioMin,
        precioMax: _precioMax,
      );
    });
  }

  static const _negro = TextStyle(color: Colors.black);
  static const _etiquetaCampo = TextStyle(color: Colors.black54);

  /// RF-07: filtros por tianguis, día de operación y rango de precio.
  Future<void> _filtros() async {
    FocusScope.of(context).unfocus();
    // Si el tianguis elegido ya no está activo, no se ofrece como valor del menú.
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
              // Los campos del tema tienen fondo blanco: el texto se fuerza a negro
              // (si no, lo escrito o elegido queda blanco sobre blanco).
              DropdownButtonFormField<String?>(
                value: idT,
                isExpanded: true,
                dropdownColor: Tg.azulOscuro,
                iconEnabledColor: Colors.black54,
                selectedItemBuilder: (_) => [
                  const Text('Todos los tianguis', style: _negro),
                  for (final t in _tianguis)
                    Text(t.nombre, style: _negro, overflow: TextOverflow.ellipsis),
                ],
                decoration:
                    const InputDecoration(labelText: 'Tianguis', labelStyle: _etiquetaCampo),
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
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: min,
                    style: _negro,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: Entradas.formatoDinero,
                    decoration: const InputDecoration(
                        labelText: 'Precio mínimo',
                        labelStyle: _etiquetaCampo,
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
                        labelText: 'Precio máximo',
                        labelStyle: _etiquetaCampo,
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
                // El FilledButton del tema ocupa todo el ancho (Size.fromHeight):
                // dentro de un Row necesita Expanded o el layout falla.
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

  /// Resumen de lo que está filtrando; cada chip se quita con su «x».
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
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
              }
              if (s.hasError) return Center(child: Text('Error: ${s.error}'));
              final l = s.data!;
              if (l.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_filtrosActivos > 0
                        ? 'Sin resultados con estos filtros'
                        : 'Sin resultados'),
                    if (_filtrosActivos > 0)
                      TextButton(onPressed: _quitarFiltros, child: const Text('QUITAR FILTROS')),
                  ]),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: l.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => TarjetaProducto(
                  producto: l[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: l[i])),
                  ),
                ),
              );
            },
          ),
        ),
      ]);
}
