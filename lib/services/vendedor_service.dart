import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';
import '../models/identidad.dart';
import '../models/operaciones.dart';

/// RF-19 a RF-30: todo lo que hace quien opera un puesto.
class VendedorService implements OperacionesVendedor {
  VendedorService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;
  String get _uid => _db.auth.currentUser!.id;

  Future<Vendedor?> miPerfil() async {
    final r = await _db
        .from('perfiles_vendedor')
        .select('*, usuarios!perfiles_vendedor_id_usuario_fkey(*)')
        .eq('id_usuario', _uid)
        .maybeSingle();
    return r == null ? null : Vendedor.fromMap(r);
  }

  /// RF-19
  @override
  Future<Vendedor> habilitarPerfil(
      {String? nombreNegocio, String? descripcion}) async {
    final r = await _db
        .from('perfiles_vendedor')
        .insert({
          'id_usuario': _uid,
          'nombre_negocio': nombreNegocio,
          'descripcion': descripcion,
        })
        .select('*, usuarios!perfiles_vendedor_id_usuario_fkey(*)')
        .single();
    return Vendedor.fromMap(r);
  }

  /// RF-20: asocia al vendedor con un tianguis habitual.
  Future<void> agregarTianguis(String idVendedor, String idTianguis) => _db
      .from('vendedor_tianguis')
      .insert({'id_vendedor': idVendedor, 'id_tianguis': idTianguis});

  /// RF-21
  @override
  Future<void> agregarHorario(String idVendedor, String idTianguis, int dia,
          String inicio, String fin) =>
      _db.from('vendedor_horarios').insert({
        'id_vendedor': idVendedor,
        'id_tianguis': idTianguis,
        'dia_semana': dia,
        'hora_inicio': inicio,
        'hora_fin': fin,
      });

  /// RF-22
  @override
  Future<void> registrarAusencia(
          String idVendedor, String idTianguis, DateTime fecha,
          {String? motivo}) =>
      _db.from('ausencias_programadas').insert({
        'id_vendedor': idVendedor,
        'id_tianguis': idTianguis,
        'fecha': fecha.toIso8601String().substring(0, 10),
        'motivo': motivo,
      });

  // ---- Puestos ----
  Future<List<Puesto>> misPuestos(String idVendedor) async {
    final r = await _db
        .from('puestos')
        .select()
        .eq('id_vendedor', idVendedor)
        .eq('activo', true);
    return r.map<Puesto>(Puesto.fromMap).toList();
  }

  Future<String> crearPuesto(
      String idVendedor, String idTianguis, String nombre,
      {String? codigo, String? descripcion}) async {
    final r = await _db
        .from('puestos')
        .insert({
          'id_vendedor': idVendedor,
          'id_tianguis': idTianguis,
          'nombre': nombre,
          'codigo': codigo,
          'descripcion': descripcion,
        })
        .select('id')
        .single();
    return r['id'];
  }

  /// Edita nombre, código, descripción o foto del puesto.
  Future<void> actualizarPuesto(
          String idPuesto, Map<String, dynamic> cambios) =>
      _db.from('puestos').update(cambios).eq('id', idPuesto);

  /// Sube (o reemplaza) la foto del puesto. Borra la anterior si existía.
  Future<void> subirFotoPuesto(String idPuesto, File archivo,
      {String? rutaAnterior}) async {
    final ruta =
        '$_uid/puestos/$idPuesto/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage
        .from(SupabaseConfig.bucketProductos)
        .upload(ruta, archivo);
    await actualizarPuesto(idPuesto, {'foto_ruta': ruta});
    if (rutaAnterior != null) {
      try {
        await _db.storage
            .from(SupabaseConfig.bucketProductos)
            .remove([rutaAnterior]);
      } catch (_) {}
    }
  }

  /// Cierre con aviso a los compradores. Primero cierra la jornada (cerrar_puesto)
  /// y luego marca el tipo de cierre; al volver a abrir el trigger lo limpia.
  Future<void> cerrarTemporalmente(String idPuesto,
      {DateTime? reabreEn, String? motivo}) async {
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

  /// Baja lógica transaccional del puesto, sus productos y ofertas.
  Future<void> eliminarPuesto(String idPuesto) =>
      _db.rpc('retirar_puesto', params: {'p_id_puesto': idPuesto});

  @override
  Future<Puesto> puestoPorId(String idPuesto) async => Puesto.fromMap(
      await _db.from('puestos').select().eq('id', idPuesto).single());

  /// RF-27 + RF-28: abre el puesto y registra la ubicación UNA sola vez
  /// (sin rastreo continuo, RNF-2).
  @override
  Future<String> abrirPuesto(String idPuesto) async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied ||
        permiso == LocationPermission.deniedForever) {
      throw Exception(
          'Se necesita el permiso de ubicación para abrir el puesto.');
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

  @override
  Future<void> cerrarPuesto(String idPuesto) =>
      _db.rpc('cerrar_puesto', params: {'p_id_puesto': idPuesto});

  /// RF-41: código temporal para que los compradores confirmen su visita.
  Future<Map<String, dynamic>> generarCodigoVisita(String idPuesto,
      {int minutos = 10}) async {
    final codigo = await _db.rpc('generar_codigo_visita',
        params: {'p_id_puesto': idPuesto, 'p_minutos': minutos}) as String;
    return {
      'codigo': codigo,
      'expira_en': DateTime.now()
          .add(Duration(minutes: minutos))
          .toUtc()
          .toIso8601String(),
    };
  }

  // ---- Productos ----
  Future<List<Producto>> misProductos(String idVendedor) async {
    final r = await _db
        .from('productos')
        .select(_selectProducto)
        .eq('id_vendedor', idVendedor)
        .eq('activo', true)
        .order('creado_en', ascending: false);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  /// RF-23
  @override
  Future<Producto> crearProducto({
    required String idVendedor,
    required String idPuesto,
    String? idCategoria,
    required String nombre,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precio,
    int? cantidad,
  }) async {
    if (idPuesto.trim().isEmpty) {
      throw ArgumentError('El producto requiere un puesto');
    }
    if (cantidad != null && cantidad < 0) throw ArgumentError('Stock negativo');
    if (precio != null && precio < 0) throw ArgumentError('Precio negativo');
    final puesto = await puestoPorId(idPuesto);
    if (puesto.idVendedor != idVendedor || !puesto.activo) {
      throw StateError('Selecciona un puesto activo del mismo vendedor');
    }
    final r = await _db
        .from('productos')
        .insert({
          'id_vendedor': idVendedor,
          'id_puesto': idPuesto,
          'id_categoria': idCategoria,
          'nombre': nombre,
          'descripcion': descripcion,
          'estado_articulo': estadoArticulo,
          'precio_referencia': precio,
          'cantidad_disponible': cantidad,
        })
        .select(_selectProducto)
        .single();
    return Producto.fromMap(r);
  }

  static const _selectProducto = '*, categorias(nombre), '
      'puestos!productos_id_puesto_fkey(nombre, estado), producto_imagenes(id, ruta_storage, orden)';
  @override
  Future<Producto> productoPorId(String id) async => Producto.fromMap(await _db
      .from('productos')
      .select(_selectProducto)
      .eq('id', id)
      .single());

  /// RF-24 / RF-26
  @override
  Future<void> actualizarProducto(
      String id, Map<String, dynamic> cambios) async {
    if (cambios.containsKey('id_puesto') &&
        (cambios['id_puesto'] is! String ||
            (cambios['id_puesto'] as String).trim().isEmpty)) {
      throw ArgumentError('El producto requiere un puesto');
    }
    await _db.from('productos').update({
      ...cambios,
      'actualizado_en': DateTime.now().toUtc().toIso8601String()
    }).eq('id', id);
  }

  /// RF-25: baja lógica
  Future<void> retirarProducto(String id) =>
      actualizarProducto(id, {'activo': false});

  /// RF-23: sube una foto a Storage y la liga al producto (al final del orden).
  Future<void> subirImagen(String idProducto, File archivo,
      {int orden = 0}) async {
    final ruta =
        '$_uid/$idProducto/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _db.storage
        .from(SupabaseConfig.bucketProductos)
        .upload(ruta, archivo);
    await _db.from('producto_imagenes').insert(
        {'id_producto': idProducto, 'ruta_storage': ruta, 'orden': orden});
  }

  /// Quita una foto del producto (fila + archivo).
  Future<void> eliminarImagen(ImagenProducto img) async {
    if (img.id != null) {
      await _db.from('producto_imagenes').delete().eq('id', img.id!);
    }
    try {
      await _db.storage.from(SupabaseConfig.bucketProductos).remove([img.ruta]);
    } catch (_) {}
  }

  // ---- Ofertas (RF-29, RF-30) ----
  Future<List<Oferta>> misOfertas(String idVendedor) async {
    final r = await _db
        .from('ofertas')
        .select(_selectOferta)
        .eq('id_vendedor', idVendedor)
        .order('creado_en', ascending: false)
        .limit(50);
    return r.map<Oferta>(Oferta.fromMap).toList();
  }

  static const _selectOferta =
      '*, productos!ofertas_id_producto_fkey(nombre, precio_referencia)';
  @override
  Future<Oferta> ofertaPorId(String idOferta) async => Oferta.fromMap(await _db
      .from('ofertas')
      .select(_selectOferta)
      .eq('id', idOferta)
      .single());

  @override
  Future<List<Oferta>> publicarOferta({
    required String idVendedor,
    required String titulo,
    required DateTime fin,
    required List<({String idProducto, num? precioPromo, num? descuento})>
        productos,
  }) async {
    if (productos.isEmpty || !fin.isAfter(DateTime.now())) {
      throw ArgumentError('Selecciona productos y una fecha final futura');
    }
    for (final p in productos) {
      if ((p.precioPromo == null && p.descuento == null) ||
          (p.precioPromo != null && p.precioPromo! < 0) ||
          (p.descuento != null && (p.descuento! <= 0 || p.descuento! > 100))) {
        throw ArgumentError('Precio o descuento no válido');
      }
    }
    final r = await _db.from('ofertas').insert([
      for (final p in productos)
        {
          'id_vendedor': idVendedor,
          'titulo': titulo,
          'id_producto': p.idProducto,
          'precio_promocional': p.precioPromo,
          'descuento': p.descuento,
          'fecha_fin': fin.toUtc().toIso8601String(),
        }
    ]).select(_selectOferta);
    return r.map(Oferta.fromMap).toList();
  }

  /// RF-30: terminar anticipadamente.
  @override
  Future<void> terminarOferta(String idOferta) => _db
      .from('ofertas')
      .update({'estado': Est.ofertaFinalizada}).eq('id', idOferta);
}
