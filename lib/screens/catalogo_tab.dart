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
  late Future<List<Producto>> _futuro = _svc.buscar();

  @override
  void initState() {
    super.initState();
    _svc.categorias().then((c) {
      if (mounted) setState(() => _cats = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _buscar() {
    setState(() {
      _futuro = _svc.buscar(texto: _texto.text, idCategoria: _cat);
    });
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
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Tg.azul),
                onPressed: _buscar,
              ),
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
