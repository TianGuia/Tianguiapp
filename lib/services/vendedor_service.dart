import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../config/estados.dart';
import '../models/modelos.dart';
import '../models/tratos.dart';

// aqui se cumplen rf-14 a rf-25, cada parte de abajo dice cual cumple
class VendedorService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<Map<String, dynamic>?> miPerfil() =>
      _db.from('perfiles_vendedor').select().eq('id_usuario', _uid).maybeSingle();

  // rf-14 se cumple aqui: la persona activa su perfil de vendedor
  Future<String> habilitarPerfil({String? nombreNegocio, String? descripcion}) async {
    final r = await _db.from('perfiles_vendedor').insert({
      'id_usuario': _uid,
      'nombre_negocio': nombreNegocio,
      'descripcion': descripcion,
    }).select('id').single();
    return r['id'];
  }

  // rf-15 se cumple aqui: el vendedor dice en que tianguis pone su puesto
  Future<void> agregarTianguis(String idVendedor, String idTianguis) =>
      _db.from('vendedor_tianguis').insert({'id_vendedor': idVendedor, 'id_tianguis': idTianguis});

  // rf-16 se cumple aqui: el vendedor guarda que dias y a que hora trabaja
  Future<void> registrarHorario(String idVendedor, String idTianguis, int dia, String inicio, String fin) =>
      _db.from('vendedor_horarios').insert({
        'id_vendedor': idVendedor, 'id_tianguis': idTianguis,
        'dia_semana': dia, 'hora_inicio': inicio, 'hora_fin': fin,
      });

  // rf-17 se cumple aqui: el vendedor avisa con tiempo que un dia no va a ir
  // rf-08 se cumple a medias, aqui solo se guarda la ausencia, avisar al comprador le toca al backend
  Future<void> registrarAusencia(String idVendedor, String idTianguis, DateTime fecha, {String? motivo}) =>
      _db.from('ausencias_programadas').insert({
        'id_vendedor': idVendedor, 'id_tianguis': idTianguis,
        'fecha': fecha.toIso8601String().substring(0, 10), 'motivo': motivo,
      });

  Future<List<Map<String, dynamic>>> horarios(String idVendedor) => _db
      .from('vendedor_horarios')
      .select()
      .eq('id_vendedor', idVendedor)
      .order('dia_semana');

  Future<void> eliminarHorario(dynamic id) =>
      _db.from('vendedor_horarios').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> ausencias(String idVendedor) => _db
      .from('ausencias_programadas')
      .select()
      .eq('id_vendedor', idVendedor)
      .gte('fecha', DateTime.now().toIso8601String().substring(0, 10))
      .order('fecha');

  Future<void> eliminarAusencia(dynamic id) =>
      _db.from('ausencias_programadas').delete().eq('id', id);

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

  Future<void> actualizarPuesto(String idPuesto, Map<String, dynamic> cambios) =>
      _db.from('puestos').update(cambios).eq('id', idPuesto);

  // sube o cambia la foto del puesto y borra la anterior
  Future<void> subirFotoPuesto(String idPuesto, File archivo, {String? rutaAnterior}) async {
    final ruta = '$_uid/puestos/$idPuesto/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from(SupabaseConfig.bucketProductos).upload(ruta, archivo);
    await actualizarPuesto(idPuesto, {'foto_ruta': ruta});
    if (rutaAnterior != null) {
      try { await _db.storage.from(SupabaseConfig.bucketProductos).remove([rutaAnterior]); } catch (_) {} // si no se borra, la foto vieja queda guardada
    }
  }

  // cierre con aviso: cierra la jornada y despues marca el tipo de cierre
  // al abrir otra vez el trigger lo limpia
  Future<void> cerrarTemporalmente(String idPuesto, {DateTime? reabreEn, String? motivo}) async {
    await marcarCerrado(idPuesto);
    await actualizarPuesto(idPuesto, {
      'cierre_tipo': 'temporal',
      'reabre_en': reabreEn?.toIso8601String().substring(0, 10),
      'cierre_motivo': (motivo ?? '').trim().isEmpty ? null : motivo!.trim(),
    });
  }

  Future<void> cerrarHastaNuevoAviso(String idPuesto, {String? motivo}) async {
    await marcarCerrado(idPuesto);
    await actualizarPuesto(idPuesto, {
      'cierre_tipo': 'hasta_nuevo_aviso',
      'reabre_en': null,
      'cierre_motivo': (motivo ?? '').trim().isEmpty ? null : motivo!.trim(),
    });
  }

  // eliminar es baja logica, se quedan visitas y calificaciones
  // retirar_puesto (Toldo) lo hace todo en una transaccion: cierra la jornada,
  // retira los productos conservando su stock, termina las ofertas y desactiva el puesto
  Future<void> eliminarPuesto(String idPuesto) =>
      _db.rpc('retirar_puesto', params: {'p_id_puesto': idPuesto});

  // rf-22 se cumple aqui: el vendedor abre o cierra su puesto
  // rf-23 se cumple aqui: al abrir el puesto se guarda donde esta ese dia
  Future<String> marcarAbierto(String idPuesto) async {
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

  Future<void> marcarCerrado(String idPuesto) =>
      _db.rpc('cerrar_puesto', params: {'p_id_puesto': idPuesto});

  // rf-41 se cumple aqui: el comprador escribe el codigo que le da el vendedor para confirmar que si fue al puesto
  Future<Map<String, dynamic>> generarCodigoVisita(String idPuesto, {int minutos = 10}) async {
    final codigo = await _db.rpc('generar_codigo_visita',
        params: {'p_id_puesto': idPuesto, 'p_minutos': minutos}) as String;
    return {
      'codigo': codigo,
      'expira_en': DateTime.now().add(Duration(minutes: minutos)).toUtc().toIso8601String(),
    };
  }

  Future<List<Producto>> misProductos(String idVendedor) async {
    final r = await _db
        .from('productos')
        .select('*, categorias(nombre), puestos!productos_id_puesto_fkey(nombre, estado), producto_imagenes(id, ruta_storage, orden)')
        .eq('id_vendedor', idVendedor)
        .eq('activo', true)
        .order('creado_en', ascending: false);
    return r.map<Producto>(Producto.fromMap).toList();
  }

  // rf-18 se cumple aqui: el vendedor agrega un producto con nombre, fotos y precio
  Future<String> crearProducto({
    required String idVendedor,
    String? idPuesto,
    String? idCategoria,
    required String nombre,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precio,
    int? cantidad,
    bool disponibilidadManual = true,
  }) async {
    final r = await _db.from('productos').insert({
      'id_vendedor': idVendedor, 'id_puesto': idPuesto, 'id_categoria': idCategoria,
      'nombre': nombre, 'descripcion': descripcion, 'estado_articulo': estadoArticulo,
      'precio_referencia': precio, 'cantidad_disponible': cantidad,
      'disponibilidad_manual': disponibilidadManual,
    }).select('id').single();
    return r['id'];
  }

  // rf-19 se cumple aqui: el vendedor cambia los datos de un producto
  // rf-21 se cumple aqui: el vendedor actualiza cuantos le quedan de un producto
  Future<void> actualizarStock(String id, int cantidad) =>
      actualizarProducto(id, {'cantidad_disponible': cantidad});

  Future<void> actualizarProducto(String id, Map<String, dynamic> cambios) async {
    await _db.from('productos').update(cambios).eq('id', id).select('id').single();
  }

  // rf-20 se cumple aqui: el producto no se borra, solo se oculta para que ya no salga
  Future<void> retirarProducto(String id) => actualizarProducto(id, {'activo': false});

  Future<void> subirImagen(String idProducto, File archivo, {int orden = 0}) async {
    final ruta = '$_uid/$idProducto/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _db.storage.from(SupabaseConfig.bucketProductos).upload(ruta, archivo);
    await _db.from('producto_imagenes').insert({'id_producto': idProducto, 'ruta_storage': ruta, 'orden': orden});
  }

  Future<void> eliminarImagen(ImagenProducto img) async {
    if (img.id != null) await _db.from('producto_imagenes').delete().eq('id', img.id!);
    try { await _db.storage.from(SupabaseConfig.bucketProductos).remove([img.ruta]); } catch (_) {} // si no se borra, el archivo queda suelto
  }

  Future<List<Oferta>> misOfertas(String idVendedor) async {
    final r = await _db
        .from('ofertas')
        .select('*, productos!ofertas_id_producto_fkey(nombre, precio_referencia)')
        .eq('id_vendedor', idVendedor)
        .order('creado_en', ascending: false)
        .limit(100);
    return Oferta.agrupar(List<Map<String, dynamic>>.from(r));
  }

  // cada producto de una oferta es una fila, las de una misma publicacion se enlazan con id_oferta_origen
  Future<void> publicarOferta({
    required String idVendedor,
    required String titulo,
    required DateTime fin,
    required List<({String idProducto, num? precioPromo, num? descuento})> productos,
  }) async {
    Map<String, dynamic> fila(({String idProducto, num? precioPromo, num? descuento}) p,
            [String? origen]) =>
        {
          'id_vendedor': idVendedor,
          'titulo': titulo,
          'fecha_fin': fin.toUtc().toIso8601String(),
          'id_producto': p.idProducto,
          'precio_promocional': p.precioPromo,
          'descuento': p.descuento,
          if (origen != null) 'id_oferta_origen': origen,
        };

    final primera = await _db.from('ofertas').insert(fila(productos.first)).select('id').single();
    if (productos.length == 1) return;
    try {
      await _db.from('ofertas').insert([
        for (final p in productos.skip(1)) fila(p, primera['id'] as String),
      ]);
    } catch (e) {
      // no dejar una oferta a medias si fallo algun producto
      try { await _db.from('ofertas').delete().eq('id', primera['id']); } catch (_) {} // si tampoco se borra, queda a medias
      rethrow;
    }
  }

  // rf-25 se cumple aqui: la oferta deja de verse cuando se acaba su tiempo y el vendedor la puede terminar antes
  Future<void> finalizarOferta(String idOferta) =>
      _db
          .from('ofertas')
          .update({'estado': Est.ofertaFinalizada})
          .or('id.eq.$idOferta,id_oferta_origen.eq.$idOferta');
}
