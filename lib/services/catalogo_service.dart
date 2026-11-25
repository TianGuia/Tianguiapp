import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';
import 'favoritos_cambios.dart';

// rf-01 se cumple aqui: se buscan productos escribiendo una palabra o eligiendo una categoria
// rf-02 se cumple aqui: los productos se filtran por tianguis, dia, categoria y precio
// rf-03 se cumple aqui: se muestra todo de un producto, como fotos, precio y quien lo vende
class CatalogoService {
  CatalogoService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _select =
      '*, categorias(nombre), puestos!productos_id_puesto_fkey(nombre, estado), perfiles_vendedor(nombre_negocio), producto_imagenes(ruta_storage, orden)';

  Future<List<Map<String, dynamic>>> categorias() =>
      _db.from('categorias').select().eq('activa', true).order('nombre');

  Future<List<Tianguis>> tianguis() async {
    final r = await _db.from('tianguis').select().eq('activo', true).order('nombre');
    return r.map<Tianguis>(Tianguis.fromMap).toList();
  }

  Future<List<Producto>> buscarProductos({String? texto, String? idCategoria}) =>
      filtrarProductos(texto: texto, idCategoria: idCategoria);

  Future<List<Producto>> filtrarProductos({
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
    int? diaSemana, // 0 = domingo … 6 = sabado
  }) async {
    var q = _db.rpc<PostgrestList>('productos_catalogo', params: {
      'p_tianguis': idTianguis,
      'p_dia': diaSemana,
    });

    if (texto != null && texto.trim().isNotEmpty) {
      q = q.textSearch('busqueda', texto.trim(),
          config: 'spanish', type: TextSearchType.websearch);
    }
    if (idCategoria != null) q = q.eq('id_categoria', idCategoria);
    if (precioMin != null) q = q.gte('precio_referencia', precioMin);
    if (precioMax != null) q = q.lte('precio_referencia', precioMax);

    final r = await q.select(_select).order('creado_en', ascending: false).limit(60);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  Future<Producto?> porId(String id) async {
    final r = await _db.from('productos').select(_select).eq('id', id).maybeSingle();
    return r == null ? null : Producto.fromMap(r);
  }

  Future<String?> nombreVendedorDeProducto(String idProducto) =>
      _db.rpc<String?>('nombre_vendedor_producto', params: {'p_producto': idProducto});

  // favoritos
  // rf-06 se cumple aqui: se guardan productos como favoritos
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

  // id_usuario del dueño de un perfil de vendedor, para abrir el chat.
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

  // rf-25: solo se consultan ofertas activas que aún no vencen.
  Future<OfertaVigente?> ofertaVigente(String idProducto, num? precioRef) async {
    final ahora = DateTime.now().toUtc().toIso8601String();
    final r = await _db
        .from('ofertas')
        .select('titulo, fecha_fin, precio_promocional, descuento')
        .eq('id_producto', idProducto)
        .eq('estado', Est.ofertaActiva)
        .lte('fecha_inicio', ahora)
        .gt('fecha_fin', ahora)
        .order('fecha_fin')
        .order('id')
        .limit(1);
    if (r.isEmpty) return null;
    final o = r.first;
    final precio = precioPromo(precioRef, o['precio_promocional'] as num?, o['descuento'] as num?);
    if (precio == null) return null;
    return OfertaVigente(o['titulo'] as String?, DateTime.parse(o['fecha_fin']).toLocal(), precio);
  }
}
