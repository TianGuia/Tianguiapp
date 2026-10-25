import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';

/// RF-06, RF-07, RF-08.
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
    _svc.categorias().then((c) => setState(() => _cats = c));
  }

  void _buscar() => setState(() => _futuro = _svc.buscar(texto: _texto.text, idCategoria: _cat));

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _texto,
            style: const TextStyle(color: Colors.black),
            onSubmitted: (_) => _buscar(),
            decoration: InputDecoration(
              hintText: 'Buscar productos…',
              prefixIcon: const Icon(Icons.search, color: Tg.azul),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward, color: Tg.azul), onPressed: _buscar),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(label: const Text('Todas'), selected: _cat == null, onSelected: (_) { _cat = null; _buscar(); }),
            ),
            for (final c in _cats)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(c['nombre']), selected: _cat == c['id'], onSelected: (_) { _cat = c['id']; _buscar(); }),
              ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<Producto>>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (s.hasError) return Center(child: Text('Error: ${s.error}'));
              final l = s.data!;
              if (l.isEmpty) return const Center(child: Text('Sin resultados'));
              return ListView.builder(
                itemCount: l.length,
                itemBuilder: (_, i) {
                  final p = l[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: p.imagenes.isEmpty
                          ? const Icon(Icons.image_not_supported, size: 40)
                          : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imagenes.first, width: 56, height: 56, fit: BoxFit.cover)),
                      title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text([p.categoria, p.puestoNombre].whereType<String>().join(' · ')),
                      trailing: Text(p.precio == null ? '' : '\$${p.precio}',
                          style: const TextStyle(color: Tg.amarillo, fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]);
}
