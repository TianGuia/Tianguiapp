import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/puestos_service.dart';
import '../services/vendedor_service.dart';

class Tianguis {
  final String id, nombre;
  final String? direccion, descripcion;
  final double? lat, lng;
  Tianguis.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        nombre = m['nombre'],
        direccion = m['direccion'],
        descripcion = m['descripcion'],
        lat = (m['latitud'] as num?)?.toDouble(),
        lng = (m['longitud'] as num?)?.toDouble();

  // rf-04 se cumple aqui: se ven en un mapa los puestos que estan abiertos
  // rf-05 se cumple aqui: se ve si el puesto esta abierto o cerrado y donde estaba la ultima vez
  Future<List<Puesto>> consultarMapa() => PuestosService().consultarMapa(idTianguis: id);
}

class Puesto {
  final String id, idVendedor, idTianguis, nombre, estado;
  final String? codigo, descripcion, fotoRuta, cierreTipo, cierreMotivo;
  final double? lat, lng;
  final DateTime? fechaApertura, reabreEn;
  bool get abierto => estado == 'abierto';

  // rf-22 se cumple aqui: el vendedor abre o cierra su puesto
  // rf-23 se cumple aqui: al abrir el puesto se guarda donde esta ese dia
  Future<String> marcarAbierto() => VendedorService().marcarAbierto(id);

  Future<void> marcarCerrado() => VendedorService().marcarCerrado(id);

  Puesto.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idVendedor = m['id_vendedor'],
        idTianguis = m['id_tianguis'],
        nombre = m['nombre'],
        codigo = m['codigo'],
        descripcion = m['descripcion'],
        fotoRuta = m['foto_ruta'],
        cierreTipo = m['cierre_tipo'],
        cierreMotivo = m['cierre_motivo'],
        reabreEn = m['reabre_en'] == null ? null : DateTime.tryParse(m['reabre_en']),
        estado = m['estado'],
        lat = (m['latitud'] as num?)?.toDouble(),
        lng = (m['longitud'] as num?)?.toDouble(),
        fechaApertura = m['fecha_apertura'] == null
            ? null
            : DateTime.parse(m['fecha_apertura']).toLocal();

  String? get fotoUrl => fotoRuta == null
      ? null
      : Supabase.instance.client.storage
          .from(SupabaseConfig.bucketProductos)
          .getPublicUrl(fotoRuta!);

  String get textoEstado {
    if (abierto) return 'ABIERTO';
    if (cierreTipo == 'temporal') return 'CERRADO TEMPORALMENTE';
    if (cierreTipo == 'hasta_nuevo_aviso') return 'CERRADO HASTA NUEVO AVISO';
    return 'CERRADO';
  }

  // detalle del cierre, ejemplo: "Vuelve el 12/11, Vacaciones"
  String? get detalleCierre {
    if (abierto || cierreTipo == null) return null;
    final r = reabreEn;
    final partes = <String>[
      if (r != null)
        'Vuelve el ${r.day.toString().padLeft(2, '0')}/${r.month.toString().padLeft(2, '0')}',
      if ((cierreMotivo ?? '').isNotEmpty) cierreMotivo!,
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }
}

class ImagenProducto {
  final String? id;
  final String ruta;
  final int orden;
  ImagenProducto(this.id, this.ruta, this.orden);
  String get url => Supabase.instance.client.storage
      .from(SupabaseConfig.bucketProductos)
      .getPublicUrl(ruta);
}

class Producto {
  final String id, idVendedor, nombre, estadoArticulo;
  final String? idPuesto, descripcion, categoria, puestoNombre, puestoEstado;
  final num? precio;
  final int? cantidad;
  final bool disponible;
  final List<String> imagenes;
  final List<ImagenProducto> fotos;

  Producto.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idVendedor = m['id_vendedor'],
        idPuesto = m['id_puesto'],
        nombre = m['nombre'],
        descripcion = m['descripcion'],
        estadoArticulo = m['estado_articulo'],
        precio = m['precio_referencia'] as num?,
        cantidad = m['cantidad_disponible'] as int?,
        disponible = m['disponible'] ?? true,
        categoria = (m['categorias'] as Map?)?['nombre'],
        puestoNombre = (m['puestos'] as Map?)?['nombre'],
        puestoEstado = (m['puestos'] as Map?)?['estado'],
        fotos = _fotos(m['producto_imagenes']),
        imagenes = _urls(m['producto_imagenes']);

  // rf-18 se cumple aqui: el vendedor agrega un producto con nombre, fotos y precio
  static Future<String> crearProducto({
    required String idVendedor,
    String? idPuesto,
    String? idCategoria,
    required String nombre,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precio,
    int? cantidad,
  }) =>
      VendedorService().crearProducto(
        idVendedor: idVendedor,
        idPuesto: idPuesto,
        idCategoria: idCategoria,
        nombre: nombre,
        descripcion: descripcion,
        estadoArticulo: estadoArticulo,
        precio: precio,
        cantidad: cantidad,
      );

  // rf-21 se cumple aqui: el vendedor actualiza cuantos le quedan de un producto
  Future<void> actualizarStock(int cantidad) => VendedorService().actualizarStock(id, cantidad);

  static List<ImagenProducto> _fotos(dynamic filas) {
    if (filas is! List) return [];
    final l = [
      for (final f in filas)
        ImagenProducto(f['id'] as String?, f['ruta_storage'] as String, (f['orden'] as int?) ?? 0)
    ]..sort((a, b) => a.orden.compareTo(b.orden));
    return l;
  }

  static List<String> _urls(dynamic filas) {
    if (filas is! List) return [];
    final l = List<Map<String, dynamic>>.from(filas)
      ..sort((a, b) => (a['orden'] as int).compareTo(b['orden'] as int));
    return l
        .map((f) => Supabase.instance.client.storage
            .from(SupabaseConfig.bucketProductos)
            .getPublicUrl(f['ruta_storage']))
        .toList();
  }
}

// fila de v_puestos_resumen, sirve para el destacado y las tendencias
class PuestoResumen {
  final String id, nombre, idTianguis;
  final String? tianguisNombre, categoria, descripcion, rutaImagen;
  final int? diaSemana;
  final double promedio; // 0 si aun no tiene calificaciones
  final int calificaciones, guardados;
  // personas distintas que lo calificaron (una persona puede calificar en varias jornadas)
  final int calificadores;
  final bool abierto;
  // marcas calculadas en la base (v_puestos_resumen): Nuevo = menos de 30 dias desde
  // su primera apertura; Veterano = mas de 1 año, 10 personas, promedio >= 4 y sigue abriendo
  final bool esNuevo, esVeterano;

  PuestoResumen.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        nombre = m['nombre'],
        idTianguis = m['id_tianguis'],
        tianguisNombre = m['tianguis_nombre'],
        categoria = m['categoria_nombre'],
        descripcion = m['descripcion'],
        rutaImagen = m['ruta_imagen'],
        diaSemana = (m['dia_semana'] as num?)?.toInt(),
        promedio = (m['promedio'] as num?)?.toDouble() ?? 0,
        calificaciones = (m['calificaciones'] as num?)?.toInt() ?? 0,
        guardados = (m['guardados'] as num?)?.toInt() ?? 0,
        calificadores = (m['calificadores'] as num?)?.toInt() ?? 0,
        esNuevo = m['es_nuevo'] == true,
        esVeterano = m['es_veterano'] == true,
        abierto = m['abierto'] == true;

  String? get imagenUrl => rutaImagen == null
      ? null
      : Supabase.instance.client.storage
          .from(SupabaseConfig.bucketProductos)
          .getPublicUrl(rutaImagen!);

  static const _dias = ['DOMINGO', 'LUNES', 'MARTES', 'MIÉRCOLES', 'JUEVES', 'VIERNES', 'SÁBADO'];

  // ejemplo: "EL NIÑO 1 - LUNES"
  String get ubicacion {
    final d = diaSemana;
    final dia = (d != null && d >= 0 && d <= 6) ? _dias[d] : null;
    return [tianguisNombre?.toUpperCase(), dia].whereType<String>().join(' - ');
  }
}
