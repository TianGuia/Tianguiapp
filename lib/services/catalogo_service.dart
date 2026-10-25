import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/modelos.dart';

/// RF-06, RF-07, RF-08: búsqueda, filtros y consulta de productos.
class CatalogoService {
  final _db = Supabase.instance.client;

  static const _select =
      '*, categorias(nombre), puestos(nombre, estado), producto_imagenes(ruta_storage, orden)';

  Future<List<Map<String, dynamic>>> categorias() =>
      _db.from('categorias').select().eq('activa', true).order('nombre');

  Future<List<Tianguis>> tianguis() async {
    final r = await _db.from('tianguis').select().eq('activo', true).order('nombre');
    return r.map<Tianguis>(Tianguis.fromMap).toList();
  }

  Future<List<Producto>> buscar({
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
  }) async {
    var q = _db.from('productos').select(_select).eq('activo', true).eq('moderado', false).eq('disponible', true);

    if (texto != null && texto.trim().isNotEmpty) {
      q = q.textSearch('busqueda', texto.trim(),
          config: 'spanish', type: TextSearchType.websearch);
    }
    if (idCategoria != null) q = q.eq('id_categoria', idCategoria);
    if (precioMin != null) q = q.gte('precio_referencia', precioMin);
    if (precioMax != null) q = q.lte('precio_referencia', precioMax);

    if (idTianguis != null) {
      // productos cuyo puesto pertenece al tianguis elegido
      final ps = await _db.from('puestos').select('id').eq('id_tianguis', idTianguis);
      final ids = ps.map((p) => p['id'] as String).toList();
      if (ids.isEmpty) return [];
      q = q.inFilter('id_puesto', ids);
    }

    final r = await q.order('creado_en', ascending: false).limit(60);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  Future<Producto?> porId(String id) async {
    final r = await _db.from('productos').select(_select).eq('id', id).maybeSingle();
    return r == null ? null : Producto.fromMap(r);
  }

  // ---- Favoritos (RF-11) ----
  Future<void> alternarFavoritoProducto(String idProducto) async {
    final uid = _db.auth.currentUser!.id;
    final ya = await _db.from('favoritos').select('id').eq('id_usuario', uid).eq('id_producto', idProducto).maybeSingle();
    if (ya != null) {
      await _db.from('favoritos').delete().eq('id', ya['id']);
    } else {
      await _db.from('favoritos').insert({'id_usuario': uid, 'id_producto': idProducto});
    }
  }
}
