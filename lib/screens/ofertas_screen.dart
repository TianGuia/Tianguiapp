import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';
import '../services/vendedor_service.dart';
import '../widgets/entradas.dart';

/// RF-29 / RF-30: ofertas relámpago del vendedor.
class OfertasScreen extends StatefulWidget {
  final String idVendedor;
  const OfertasScreen({super.key, required this.idVendedor});
  @override
  State<OfertasScreen> createState() => _OfertasScreenState();
}

class _OfertasScreenState extends State<OfertasScreen> {
  final _svc = VendedorService();
  late Future<List<Oferta>> _futuro = _svc.misOfertas(widget.idVendedor);

  void _recargar() {
    setState(() {
      _futuro = _svc.misOfertas(widget.idVendedor);
    });
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _nueva() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OfertaFormScreen(idVendedor: widget.idVendedor)),
    );
    if (ok == true) _recargar();
  }

  Future<void> _terminar(Oferta o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Terminar oferta?'),
        content: const Text('Dejará de mostrarse a los compradores de inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.terminarOferta(o.id);
      _recargar();
    } catch (e) {
      _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ofertas relámpago')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _nueva,
          icon: const Icon(Icons.bolt),
          label: const Text('Oferta'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => _recargar(),
          child: FutureBuilder<List<Oferta>>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
              }
              if (s.hasError) {
                return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${s.error}'))]);
              }
              final l = s.data!;
              if (l.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Aún no publicas ofertas')),
                ]);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 6, bottom: 90),
                itemCount: l.length,
                itemBuilder: (_, i) {
                  final o = l[i];
                  return Opacity(
                    opacity: o.vigente ? 1 : 0.6,
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Text(o.titulo ?? 'Oferta',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                  color: o.vigente ? Tg.verde : Colors.grey,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(o.vigente ? 'VIGENTE' : 'TERMINADA',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(o.vigente ? 'Termina: ${fmtFecha(o.fin)}' : 'Terminó: ${fmtFecha(o.fin)}'),
                          const SizedBox(height: 6),
                          for (final it in o.items)
                            Text('• ${it.producto}: '
                                '${it.ref != null ? '\$${it.ref} → ' : ''}'
                                '${it.precioFinal != null ? '\$${it.precioFinal}' : '—'}'
                                '${it.descuento != null ? '  (-${it.descuento}%)' : ''}'),
                          if (o.vigente)
                            TextButton.icon(
                              onPressed: () => _terminar(o),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('Terminar ahora'),
                            ),
                        ]),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
}

/// Crear una oferta: título, hora de fin, productos y descuento o precio fijo.
class OfertaFormScreen extends StatefulWidget {
  final String idVendedor;
  const OfertaFormScreen({super.key, required this.idVendedor});
  @override
  State<OfertaFormScreen> createState() => _OfertaFormScreenState();
}

class _OfertaFormScreenState extends State<OfertaFormScreen> {
  static const _negro = TextStyle(color: Colors.black);
  final _svc = VendedorService();
  final _titulo = TextEditingController();
  DateTime _fin = DateTime.now().add(const Duration(hours: 3));
  bool _porcentaje = true; // true = % de descuento, false = precio fijo
  List<Producto> _productos = [];
  bool _cargando = true;
  bool _guardando = false;
  final Map<String, TextEditingController> _valores = {}; // id producto -> valor (solo seleccionados)
  final List<TextEditingController> _todos = []; // para liberarlos al salir

  @override
  void initState() {
    super.initState();
    _svc.misProductos(widget.idVendedor).then((l) {
      if (mounted) {
        setState(() {
          _productos = l.where((p) => p.disponible).toList();
          _cargando = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _cargando = false);
    });
  }

  @override
  void dispose() {
    _titulo.dispose();
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _elegirFin() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fin.isBefore(hoy) ? hoy : _fin,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_fin));
    if (t == null) return;
    setState(() => _fin = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _guardar() async {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) return _msg('Ponle un título a la oferta');
    if (!_fin.isAfter(DateTime.now())) return _msg('La hora de fin debe ser futura');
    if (_valores.isEmpty) return _msg('Elige al menos un producto');

    final items = <({String idProducto, num? precioPromo, num? descuento})>[];
    for (final p in _productos.where((p) => _valores.containsKey(p.id))) {
      final txt = _valores[p.id]!.text.trim();
      final v = _porcentaje ? Entradas.leerPorcentaje(txt) : Entradas.leerDinero(txt);
      if (v == null) {
        return _msg('Escribe un ${_porcentaje ? 'descuento' : 'precio'} válido (solo números) para "${p.nombre}"');
      }
      if (_porcentaje) {
        if (v <= 0 || v > 100) return _msg('El descuento de "${p.nombre}" debe ser de 1 a 100%');
        items.add((idProducto: p.id, precioPromo: null, descuento: v));
      } else {
        if (v <= 0) return _msg('El precio de "${p.nombre}" debe ser mayor a 0');
        if (p.precio != null && v >= p.precio!) {
          return _msg('El precio de oferta de "${p.nombre}" debe ser menor a \$${p.precio}');
        }
        items.add((idProducto: p.id, precioPromo: v, descuento: null));
      }
    }

    setState(() => _guardando = true);
    try {
      await _svc.publicarOferta(
          idVendedor: widget.idVendedor, titulo: titulo, fin: _fin, productos: items);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg('No se publicó: ${e is PostgrestException ? e.message : e}');
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nueva oferta')),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: Tg.amarillo))
            : ListView(padding: const EdgeInsets.all(16), children: [
                TextField(
                  controller: _titulo,
                  style: _negro,
                  inputFormatters: Entradas.texto(60),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Título: Todo a mitad de precio…'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _elegirFin,
                  icon: const Icon(Icons.timer_outlined),
                  label: Text('Termina: ${fmtFecha(_fin)}'),
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, children: [
                  ChoiceChip(
                    label: const Text('Descuento %'),
                    selected: _porcentaje,
                    onSelected: (_) => setState(() => _porcentaje = true),
                  ),
                  ChoiceChip(
                    label: const Text('Precio fijo'),
                    selected: !_porcentaje,
                    onSelected: (_) => setState(() => _porcentaje = false),
                  ),
                ]),
                const SizedBox(height: 8),
                if (_productos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No tienes productos disponibles. Agrega productos primero.'),
                  ),
                for (final p in _productos) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _valores.containsKey(p.id),
                    title: Text(p.nombre),
                    subtitle: Text(p.precio == null ? 'Sin precio' : '\$${p.precio}'),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        final c = TextEditingController();
                        _todos.add(c);
                        _valores[p.id] = c;
                      } else {
                        _valores.remove(p.id);
                      }
                    }),
                  ),
                  if (_valores.containsKey(p.id))
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: TextField(
                        controller: _valores[p.id],
                        style: _negro,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters:
                            _porcentaje ? Entradas.formatoPorcentaje : Entradas.formatoDinero,
                        decoration: InputDecoration(
                            hintText: _porcentaje ? '% de descuento (1 a 100)' : 'Precio de oferta en pesos'),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: const Text('PUBLICAR OFERTA'),
                ),
              ]),
      );
}
