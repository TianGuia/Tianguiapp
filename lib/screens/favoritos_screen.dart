import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/favoritos_cambios.dart';
import 'producto_detalle_screen.dart';
import 'puesto_screen.dart';

/// RF-11: favoritos guardados (puestos, productos y tianguis).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});
  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  final _db = Supabase.instance.client;
  Map<String, String> _tianguis = {};
  late Future<List<Map<String, dynamic>>> _futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() async {
    // puestos -> tianguis no tiene FK directa, así que los nombres se piden aparte.
    final t = await CatalogoService().tianguis();
    _tianguis = {for (final x in t) x.id: x.nombre};
    final r = await _db
        .from('favoritos')
        .select('id, id_puesto, id_producto, id_tianguis, '
            'puestos(id, nombre, estado, id_tianguis, descripcion), '
            'productos(id, nombre, precio_referencia)')
        .eq('id_usuario', _db.auth.currentUser!.id)
        .order('creado_en', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  Future<void> _quitar(Map<String, dynamic> f) async {
    await _db.from('favoritos').delete().eq('id', f['id']);
    FavoritosCambios.avisar();
    setState(() => _futuro = _cargar());
  }

  Future<void> _abrir(Map<String, dynamic> f) async {
    final p = f['puestos'] as Map?;
    if (p != null) {
      final res = PuestoResumen.fromMap({
        'id': p['id'],
        'nombre': p['nombre'],
        'id_tianguis': p['id_tianguis'],
        'tianguis_nombre': _tianguis[p['id_tianguis']],
        'descripcion': p['descripcion'],
        'abierto': p['estado'] == 'abierto',
      });
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PuestoScreen(puesto: res)));
    } else if (f['id_producto'] != null) {
      final prod = await CatalogoService().porId(f['id_producto'] as String);
      if (prod != null && mounted) {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: prod)));
      }
    }
    if (mounted) setState(() => _futuro = _cargar());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis favoritos')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) return const Center(child: Text('Aún no guardas favoritos'));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: l.length,
              itemBuilder: (_, i) {
                final f = l[i];
                final puesto = f['puestos'] as Map?;
                final prod = f['productos'] as Map?;
                final esTianguis = f['id_tianguis'] != null;
                final IconData icono;
                final String titulo;
                final String sub;
                if (puesto != null) {
                  icono = Icons.storefront;
                  titulo = '${puesto['nombre']}';
                  sub = puesto['estado'] == 'abierto' ? 'Abierto ahora' : 'Cerrado';
                } else if (esTianguis) {
                  icono = Icons.place;
                  titulo = _tianguis[f['id_tianguis']] ?? 'Tianguis';
                  sub = 'Tianguis';
                } else {
                  icono = Icons.shopping_bag_outlined;
                  titulo = '${prod?['nombre'] ?? 'Producto'}';
                  sub = prod?['precio_referencia'] != null ? '\$${prod!['precio_referencia']}' : '';
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(icono, color: Tg.amarillo),
                    title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(sub),
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Tg.rosa),
                      tooltip: 'Quitar de favoritos',
                      onPressed: () => _quitar(f),
                    ),
                    onTap: esTianguis ? null : () => _abrir(f),
                  ),
                );
              },
            );
          },
        ),
      );
}
