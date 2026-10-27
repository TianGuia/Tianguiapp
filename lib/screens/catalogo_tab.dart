import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
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

  /// RF-07: filtros por tianguis, día de operación y rango de precio.
  Future<void> _filtros() async {
    var idT = _idTianguis;
    var dia = _dia;
    final min = TextEditingController(text: _precioMin?.toString() ?? '');
    final max = TextEditingController(text: _precioMax?.toString() ?? '');
    final aplicar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Filtrar productos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: idT,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tianguis'),
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio mínimo', prefixText: '\$ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: max,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio máximo', prefixText: '\$ '),
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
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('APLICAR')),
              ]),
            ]),
          ),
        ),
      ),
    );
    final pMin = num.tryParse(min.text.trim().replaceAll(',', '.'));
    final pMax = num.tryParse(max.text.trim().replaceAll(',', '.'));
    min.dispose();
    max.dispose();
    if (aplicar != true) return;
    _idTianguis = idT;
    _dia = dia;
    _precioMin = pMin;
    _precioMax = pMax;
    _buscar();
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
              if (l.isEmpty) return const Center(child: Text('Sin resultados'));
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
