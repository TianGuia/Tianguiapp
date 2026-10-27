import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';
import '../models/operaciones.dart';

/// RF-06, RF-07, RF-08: búsqueda, filtros y consulta de productos.
class CatalogoService implements OperacionesCatalogo {
  CatalogoService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;

  static const _select =
      '*, categorias(nombre), puestos!productos_id_puesto_fkey(nombre, estado), producto_imagenes(id, ruta_storage, orden)';

  Future<List<Map<String, dynamic>>> categorias() =>
      _db.from('categorias').select().eq('activa', true).order('nombre');

  Future<List<Tianguis>> tianguis() async {
    final r = await _db
        .from('tianguis')
        .select('*, tianguis_horarios(*)')
        .eq('activo', true)
        .order('nombre');
    return r.map<Tianguis>(Tianguis.fromMap).toList();
  }

  @override
  Future<MapaTianguis> consultarMapa(String idTianguis) async {
    final t = await _db
        .from('tianguis')
        .select('*, tianguis_horarios(*)')
        .eq('id', idTianguis)
        .single();
    final zonas = await _db
        .from('tianguis_zonas')
        .select()
        .eq('id_tianguis', idTianguis)
        .order('orden');
    return MapaTianguis(
        Tianguis.fromMap(t), zonas.map(ZonaTianguis.fromMap).toList());
  }

  @override
  Future<List<Producto>> buscar({
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
  }) async {
    var q = _db
        .from('productos')
        .select(_select)
        .eq('activo', true)
        .eq('moderado', false)
        .eq('disponible', true);

    if (texto != null && texto.trim().isNotEmpty) {
      q = q.textSearch('busqueda', texto.trim(),
          config: 'spanish', type: TextSearchType.websearch);
    }
    if (idCategoria != null) q = q.eq('id_categoria', idCategoria);
    if (precioMin != null) q = q.gte('precio_referencia', precioMin);
    if (precioMax != null) q = q.lte('precio_referencia', precioMax);

    if (idTianguis != null) {
      // productos cuyo puesto pertenece al tianguis elegido
      final ps =
          await _db.from('puestos').select('id').eq('id_tianguis', idTianguis);
      final ids = ps.map((p) => p['id'] as String).toList();
      if (ids.isEmpty) return [];
      q = q.inFilter('id_puesto', ids);
    }

    final r = await q.order('creado_en', ascending: false).limit(60);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  Future<Producto?> porId(String id) async {
    final r =
        await _db.from('productos').select(_select).eq('id', id).maybeSingle();
    return r == null ? null : Producto.fromMap(r);
  }

  // ---- Favoritos (RF-11) ----
  Future<void> alternarFavoritoProducto(String idProducto) async {
    final uid = _db.auth.currentUser!.id;
    final ya = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', uid)
        .eq('id_producto', idProducto)
        .maybeSingle();
    if (ya != null) {
      await _db.from('favoritos').delete().eq('id', ya['id']);
    } else {
      await _db
          .from('favoritos')
          .insert({'id_usuario': uid, 'id_producto': idProducto});
    }
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
  Future<OfertaVigente?> ofertaVigente(
      String idProducto, num? precioRef) async {
    final r = await _db
        .from('ofertas')
        .select(
            'precio_promocional, descuento, titulo, estado, fecha_inicio, fecha_fin')
        .eq('id_producto', idProducto)
        .eq('estado', Est.ofertaActiva)
        .lte('fecha_inicio', DateTime.now().toUtc().toIso8601String())
        .gt('fecha_fin', DateTime.now().toUtc().toIso8601String())
        .order('fecha_fin', ascending: true)
        .limit(1);
    if ((r as List).isEmpty) return null;
    final f = r.first;
    final precio = precioPromo(
        precioRef, f['precio_promocional'] as num?, f['descuento'] as num?);
    if (precio == null) return null;
    return OfertaVigente(f['titulo'] as String?,
        DateTime.parse(f['fecha_fin']).toLocal(), precio);
  }
}
