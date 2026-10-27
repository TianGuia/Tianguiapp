import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';
import 'favoritos_cambios.dart';

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
    int? diaSemana, // 0 = domingo … 6 = sábado
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

    // RF-07: día de operación. Cuenta el horario habitual del vendedor y el
    // horario general del tianguis donde está su puesto.
    if (diaSemana != null) {
      final hv = await _db
          .from('vendedor_horarios')
          .select('id_vendedor')
          .eq('dia_semana', diaSemana);
      final ht = await _db
          .from('tianguis_horarios')
          .select('id_tianguis')
          .eq('dia_semana', diaSemana);
      final vendedores = {for (final h in hv) h['id_vendedor'] as String}.toList();
      final tianguis = {for (final h in ht) h['id_tianguis'] as String}.toList();
      var puestos = <String>[];
      if (tianguis.isNotEmpty) {
        final ps = await _db.from('puestos').select('id').inFilter('id_tianguis', tianguis);
        puestos = [for (final p in ps) p['id'] as String];
      }
      final condiciones = [
        if (vendedores.isNotEmpty) 'id_vendedor.in.(${vendedores.join(',')})',
        if (puestos.isNotEmpty) 'id_puesto.in.(${puestos.join(',')})',
      ];
      if (condiciones.isEmpty) return [];
      q = q.or(condiciones.join(','));
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
    FavoritosCambios.avisar();
  }

  /// id_usuario del dueño de un perfil de vendedor (para abrir el chat).
  Future<String?> usuarioDeVendedor(String idVendedor) async {
    final r = await _db
        .from('perfiles_vendedor')
        .select('id_usuario')
        .eq('id', idVendedor)
        .maybeSingle();
    return r?['id_usuario'] as String?;
  }

  Future<bool> esFavorito(String idProducto) async {
    final uid = _db.auth.currentUser!.id;
    final r = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', uid)
        .eq('id_producto', idProducto)
        .maybeSingle();
    return r != null;
  }

  /// RF-29: oferta activa (no vencida) de un producto, con su precio final.
  Future<OfertaVigente?> ofertaVigente(String idProducto, num? precioRef) async {
    final r = await _db
        .from('oferta_productos')
        .select('precio_promocional, descuento_porcentaje, ofertas!inner(titulo, estado, fecha_fin)')
        .eq('id_producto', idProducto)
        .eq('ofertas.estado', Est.ofertaActiva)
        .gt('ofertas.fecha_fin', DateTime.now().toUtc().toIso8601String())
        .limit(1);
    if ((r as List).isEmpty) return null;
    final f = r.first;
    final precio = precioPromo(
        precioRef, f['precio_promocional'] as num?, f['descuento_porcentaje'] as num?);
    if (precio == null) return null;
    final o = f['ofertas'] as Map;
    return OfertaVigente(o['titulo'] as String?, DateTime.parse(o['fecha_fin']).toLocal(), precio);
  }
}
