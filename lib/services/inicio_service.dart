import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/modelos.dart';
import 'favoritos_cambios.dart';

/// Datos de la pantalla de inicio (funciones SQL del backend en Toldo).
class InicioService {
  final _db = Supabase.instance.client;

  /// {abiertos: n, en_espera: n}
  Future<Map<String, dynamic>> resumen() async {
    final r = await _db.rpc('resumen_inicio');
    return Map<String, dynamic>.from(r as Map);
  }

  Future<PuestoResumen?> destacado({String? idCategoria}) async {
    final r = await _db.rpc('puesto_destacado', params: {'p_categoria': idCategoria}) as List;
    return r.isEmpty ? null : PuestoResumen.fromMap(Map<String, dynamic>.from(r.first));
  }

  Future<List<PuestoResumen>> tendencias({String? idCategoria, int limite = 12}) async {
    final r = await _db.rpc('puestos_tendencia',
        params: {'p_categoria': idCategoria, 'p_limite': limite}) as List;
    return r.map((e) => PuestoResumen.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  // ---- Favoritos de puestos (RF-11) ----
  Future<bool> esFavoritoPuesto(String idPuesto) async {
    final uid = _db.auth.currentUser!.id;
    final r = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', uid)
        .eq('id_puesto', idPuesto)
        .maybeSingle();
    return r != null;
  }

  /// Devuelve el nuevo estado (true = quedó guardado).
  Future<bool> alternarFavoritoPuesto(String idPuesto) async {
    final uid = _db.auth.currentUser!.id;
    final ya = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', uid)
        .eq('id_puesto', idPuesto)
        .maybeSingle();
    if (ya != null) {
      await _db.from('favoritos').delete().eq('id', ya['id']);
      FavoritosCambios.avisar();
      return false;
    }
    await _db.from('favoritos').insert({'id_usuario': uid, 'id_puesto': idPuesto});
    FavoritosCambios.avisar();
    return true;
  }

  /// RF-11: favorito de tianguis.
  Future<bool> esFavoritoTianguis(String idTianguis) async {
    final r = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', _db.auth.currentUser!.id)
        .eq('id_tianguis', idTianguis)
        .limit(1);
    return (r as List).isNotEmpty;
  }

  /// Devuelve el nuevo estado (true = quedó guardado).
  Future<bool> alternarFavoritoTianguis(String idTianguis) async {
    final uid = _db.auth.currentUser!.id;
    final ya = await _db
        .from('favoritos')
        .select('id')
        .eq('id_usuario', uid)
        .eq('id_tianguis', idTianguis)
        .limit(1);
    if ((ya as List).isNotEmpty) {
      await _db.from('favoritos').delete().eq('id', ya.first['id']);
      FavoritosCambios.avisar();
      return false;
    }
    await _db.from('favoritos').insert({'id_usuario': uid, 'id_tianguis': idTianguis});
    FavoritosCambios.avisar();
    return true;
  }

  /// Fila completa del puesto (estado, tipo de cierre, motivo, fecha de regreso).
  Future<Puesto?> puestoPorId(String idPuesto) async {
    final r = await _db.from('puestos').select().eq('id', idPuesto).maybeSingle();
    return r == null ? null : Puesto.fromMap(r);
  }

  /// Productos activos de un puesto.
  Future<List<Producto>> productosDePuesto(String idPuesto) async {
    final r = await _db
        .from('productos')
        .select('*, categorias(nombre), puestos(nombre, estado), producto_imagenes(id, ruta_storage, orden)')
        .eq('id_puesto', idPuesto)
        .eq('activo', true)
        .eq('moderado', false)
        .order('creado_en', ascending: false);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  // ---- Notificaciones (RF-33 a RF-36) ----
  Future<int> noLeidas() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return 0;
    final r = await _db.from('notificaciones').select('id').eq('id_usuario', uid).eq('leida', false);
    return (r as List).length;
  }

  Future<List<Map<String, dynamic>>> notificaciones() => _db
      .from('notificaciones')
      .select()
      .eq('id_usuario', _db.auth.currentUser!.id)
      .order('creada_en', ascending: false)
      .limit(60);

  Future<void> marcarLeidas() => _db
      .from('notificaciones')
      .update({'leida': true})
      .eq('id_usuario', _db.auth.currentUser!.id)
      .eq('leida', false);
}
