import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';

/// RF-19 a RF-30: todo lo que hace quien opera un puesto.
class VendedorService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<Map<String, dynamic>?> miPerfil() =>
      _db.from('perfiles_vendedor').select().eq('id_usuario', _uid).maybeSingle();

  /// RF-19
  Future<String> habilitarPerfil({String? nombreNegocio, String? descripcion}) async {
    final r = await _db.from('perfiles_vendedor').insert({
      'id_usuario': _uid,
      'nombre_negocio': nombreNegocio,
      'descripcion': descripcion,
    }).select('id').single();
    return r['id'];
  }

  /// RF-20: asocia al vendedor con un tianguis habitual.
  Future<void> agregarTianguis(String idVendedor, String idTianguis) =>
      _db.from('vendedor_tianguis').insert({'id_vendedor': idVendedor, 'id_tianguis': idTianguis});

  /// RF-21
  Future<void> agregarHorario(String idVendedor, String idTianguis, int dia, String inicio, String fin) =>
      _db.from('vendedor_horarios').insert({
        'id_vendedor': idVendedor, 'id_tianguis': idTianguis,
        'dia_semana': dia, 'hora_inicio': inicio, 'hora_fin': fin,
      });

  /// RF-22
  Future<void> registrarAusencia(String idVendedor, String idTianguis, DateTime fecha, {String? motivo}) =>
      _db.from('ausencias_programadas').insert({
        'id_vendedor': idVendedor, 'id_tianguis': idTianguis,
        'fecha': fecha.toIso8601String().substring(0, 10), 'motivo': motivo,
      });

  /// RF-21: horarios habituales del vendedor.
  Future<List<Map<String, dynamic>>> horarios(String idVendedor) => _db
      .from('vendedor_horarios')
      .select()
      .eq('id_vendedor', idVendedor)
      .order('dia_semana');

  Future<void> eliminarHorario(dynamic id) =>
      _db.from('vendedor_horarios').delete().eq('id', id);

  /// RF-22: ausencias programadas próximas.
  Future<List<Map<String, dynamic>>> ausencias(String idVendedor) => _db
      .from('ausencias_programadas')
      .select()
      .eq('id_vendedor', idVendedor)
      .gte('fecha', DateTime.now().toIso8601String().substring(0, 10))
      .order('fecha');

  Future<void> eliminarAusencia(dynamic id) =>
      _db.from('ausencias_programadas').delete().eq('id', id);

  // ---- Puestos ----
  Future<List<Puesto>> misPuestos(String idVendedor) async {
    final r = await _db.from('puestos').select().eq('id_vendedor', idVendedor).eq('activo', true);
    return r.map<Puesto>(Puesto.fromMap).toList();
  }

  Future<String> crearPuesto(String idVendedor, String idTianguis, String nombre,
      {String? codigo, String? descripcion}) async {
    final r = await _db.from('puestos').insert({
      'id_vendedor': idVendedor, 'id_tianguis': idTianguis,
      'nombre': nombre, 'codigo': codigo, 'descripcion': descripcion,
    }).select('id').single();
    return r['id'];
  }

  /// Edita nombre, código, descripción o foto del puesto.
  Future<void> actualizarPuesto(String idPuesto, Map<String, dynamic> cambios) =>
      _db.from('puestos').update(cambios).eq('id', idPuesto);

  /// Sube (o reemplaza) la foto del puesto. Borra la anterior si existía.
  Future<void> subirFotoPuesto(String idPuesto, File archivo, {String? rutaAnterior}) async {
    final ruta = '$_uid/puestos/$idPuesto/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from(SupabaseConfig.bucketProductos).upload(ruta, archivo);
    await actualizarPuesto(idPuesto, {'foto_ruta': ruta});
    if (rutaAnterior != null) {
      try { await _db.storage.from(SupabaseConfig.bucketProductos).remove([rutaAnterior]); } catch (_) {}
    }
  }

  /// Cierre con aviso a los compradores. Primero cierra la jornada (cerrar_puesto)
  /// y luego marca el tipo de cierre; al volver a abrir el trigger lo limpia.
  Future<void> cerrarTemporalmente(String idPuesto, {DateTime? reabreEn, String? motivo}) async {
    await cerrarPuesto(idPuesto);
    await actualizarPuesto(idPuesto, {
      'cierre_tipo': 'temporal',
      'reabre_en': reabreEn?.toIso8601String().substring(0, 10),
      'cierre_motivo': (motivo ?? '').trim().isEmpty ? null : motivo!.trim(),
    });
  }

  Future<void> cerrarHastaNuevoAviso(String idPuesto, {String? motivo}) async {
    await cerrarPuesto(idPuesto);
    await actualizarPuesto(idPuesto, {
      'cierre_tipo': 'hasta_nuevo_aviso',
      'reabre_en': null,
      'cierre_motivo': (motivo ?? '').trim().isEmpty ? null : motivo!.trim(),
    });
  }

  /// Eliminar = baja lógica (activo=false), como con los productos: se conservan
  /// visitas y calificaciones. Sus productos quedan sin puesto (siguen en tu catálogo).
  Future<void> eliminarPuesto(String idPuesto) async {
    await cerrarPuesto(idPuesto);
    await _db.from('productos').update({'id_puesto': null}).eq('id_puesto', idPuesto);
    await actualizarPuesto(idPuesto, {'activo': false});
  }

  /// RF-27 + RF-28: abre el puesto y registra la ubicación UNA sola vez
  /// (sin rastreo continuo, RNF-2).
  Future<String> abrirPuesto(String idPuesto) async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw Exception('Se necesita el permiso de ubicación para abrir el puesto.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return await _db.rpc('abrir_puesto', params: {
      'p_id_puesto': idPuesto,
      'p_latitud': pos.latitude,
      'p_longitud': pos.longitude,
      'p_precision': pos.accuracy,
    }) as String; // id de jornada
  }

  Future<void> cerrarPuesto(String idPuesto) =>
      _db.rpc('cerrar_puesto', params: {'p_id_puesto': idPuesto});

  /// RF-41: código temporal para que los compradores confirmen su visita.
  Future<Map<String, dynamic>> generarCodigoVisita(String idPuesto, {int minutos = 10}) async {
    final codigo = await _db.rpc('generar_codigo_visita',
        params: {'p_id_puesto': idPuesto, 'p_minutos': minutos}) as String;
    return {
      'codigo': codigo,
      'expira_en': DateTime.now().add(Duration(minutes: minutos)).toUtc().toIso8601String(),
    };
  }

  // ---- Productos ----
  Future<List<Producto>> misProductos(String idVendedor) async {
    final r = await _db
        .from('productos')
        .select('*, categorias(nombre), puestos!productos_id_puesto_fkey(nombre, estado), producto_imagenes(id, ruta_storage, orden)')
        .eq('id_vendedor', idVendedor)
        .eq('activo', true)
        .order('creado_en', ascending: false);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  /// RF-23
  Future<String> crearProducto({
    required String idVendedor,
    String? idPuesto,
    String? idCategoria,
    required String nombre,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precio,
    int? cantidad,
  }) async {
    final r = await _db.from('productos').insert({
      'id_vendedor': idVendedor, 'id_puesto': idPuesto, 'id_categoria': idCategoria,
      'nombre': nombre, 'descripcion': descripcion, 'estado_articulo': estadoArticulo,
      'precio_referencia': precio, 'cantidad_disponible': cantidad,
    }).select('id').single();
    return r['id'];
  }

  /// RF-24 / RF-26
  Future<void> actualizarProducto(String id, Map<String, dynamic> cambios) =>
      _db.from('productos').update({...cambios, 'actualizado_en': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  /// RF-25: baja lógica
  Future<void> retirarProducto(String id) => actualizarProducto(id, {'activo': false});

  /// RF-23: sube una foto a Storage y la liga al producto (al final del orden).
  Future<void> subirImagen(String idProducto, File archivo, {int orden = 0}) async {
    final ruta = '$_uid/$idProducto/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _db.storage.from(SupabaseConfig.bucketProductos).upload(ruta, archivo);
    await _db.from('producto_imagenes').insert({'id_producto': idProducto, 'ruta_storage': ruta, 'orden': orden});
  }

  /// Quita una foto del producto (fila + archivo).
  Future<void> eliminarImagen(ImagenProducto img) async {
    if (img.id != null) await _db.from('producto_imagenes').delete().eq('id', img.id!);
    try { await _db.storage.from(SupabaseConfig.bucketProductos).remove([img.ruta]); } catch (_) {}
  }

  // ---- Ofertas (RF-29, RF-30) ----
  Future<List<Oferta>> misOfertas(String idVendedor) async {
    final r = await _db
        .from('ofertas')
        .select('*, oferta_productos(precio_promocional, descuento_porcentaje, productos(nombre, precio_referencia))')
        .eq('id_vendedor', idVendedor)
        .order('creado_en', ascending: false)
        .limit(50);
    return r.map<Oferta>(Oferta.fromMap).toList();
  }

  Future<void> publicarOferta({
    required String idVendedor,
    required String titulo,
    required DateTime fin,
    required List<({String idProducto, num? precioPromo, num? descuento})> productos,
  }) async {
    final o = await _db.from('ofertas').insert({
      'id_vendedor': idVendedor, 'titulo': titulo,
      'fecha_fin': fin.toUtc().toIso8601String(),
    }).select('id').single();
    try {
      await _db.from('oferta_productos').insert([
        for (final p in productos)
          {
            'id_oferta': o['id'], 'id_producto': p.idProducto,
            'precio_promocional': p.precioPromo, 'descuento_porcentaje': p.descuento,
          }
      ]);
    } catch (e) {
      // no dejar una oferta vacía si fallaron sus productos
      try { await _db.from('ofertas').delete().eq('id', o['id']); } catch (_) {}
      rethrow;
    }
  }

  /// RF-30: terminar anticipadamente.
  Future<void> terminarOferta(String idOferta) =>
      _db.from('ofertas').update({'estado': Est.ofertaFinalizada}).eq('id', idOferta);
}
