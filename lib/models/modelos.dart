import '../services/imagenes_service.dart';
import 'operaciones.dart';

class Tianguis {
  final String id, nombre;
  final String? direccion, descripcion;
  final double? lat, lng;
  final bool activo;
  final List<HorarioTianguis> horarios;
  String get idTianguis => id;
  String? get ubicacion => direccion;
  String get estado => activo ? 'activo' : 'inactivo';
  String get diasOperacion =>
      horarios.map((h) => h.diaSemana.toString()).toSet().join(', ');
  String get horarioGeneral =>
      horarios.map((h) => '${h.diaSemana}: ${h.inicio}–${h.fin}').join('; ');
  Future<MapaTianguis> consultarMapa(OperacionesCatalogo operaciones) =>
      operaciones.consultarMapa(id);
  Tianguis.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        nombre = m['nombre'],
        direccion = m['direccion'],
        descripcion = m['descripcion'],
        lat = (m['latitud'] as num?)?.toDouble(),
        lng = (m['longitud'] as num?)?.toDouble(),
        activo = m['activo'] as bool,
        horarios = List.unmodifiable([
          for (final h in (m['tianguis_horarios'] as List? ?? []))
            HorarioTianguis.fromMap(h),
        ]);
}

class HorarioTianguis {
  final int diaSemana;
  final String inicio, fin;
  HorarioTianguis.fromMap(Map<String, dynamic> m)
      : diaSemana = (m['dia_semana'] as num).toInt(),
        inicio = m['hora_inicio'],
        fin = m['hora_fin'];
}

class ZonaTianguis {
  final String id, nombre, tipo;
  final Map<String, dynamic>? geometria;
  ZonaTianguis.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        nombre = m['nombre'],
        tipo = m['tipo'],
        geometria = m['geometria'] == null
            ? null
            : Map<String, dynamic>.from(m['geometria']);
}

class MapaTianguis {
  final Tianguis tianguis;
  final List<ZonaTianguis> zonas;
  MapaTianguis(this.tianguis, List<ZonaTianguis> zonas)
      : zonas = List.unmodifiable(zonas);
}

class Puesto {
  final String id, idVendedor, idTianguis, nombre, estado;
  final String? codigo, descripcion, fotoRuta, cierreTipo, cierreMotivo;
  final double? lat, lng;
  final bool activo;
  final DateTime? fechaApertura, fechaCierre, reabreEn;
  String get idPuesto => id;
  String? get ubicacion => lat == null || lng == null ? null : '$lat,$lng';
  Future<Puesto> marcarAbierto(OperacionesVendedor operaciones) async {
    await operaciones.abrirPuesto(id);
    return operaciones.puestoPorId(id);
  }

  Future<Puesto> marcarCerrado(OperacionesVendedor operaciones) async {
    await operaciones.cerrarPuesto(id);
    return operaciones.puestoPorId(id);
  }

  bool get abierto => estado == 'abierto';

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
        reabreEn =
            m['reabre_en'] == null ? null : DateTime.tryParse(m['reabre_en']),
        estado = m['estado'],
        activo = m['activo'] as bool,
        lat = (m['latitud'] as num?)?.toDouble(),
        lng = (m['longitud'] as num?)?.toDouble(),
        fechaCierre = m['fecha_cierre'] == null
            ? null
            : DateTime.parse(m['fecha_cierre']),
        fechaApertura = m['fecha_apertura'] == null
            ? null
            : DateTime.parse(m['fecha_apertura']).toLocal();

  String? get fotoUrl => fotoRuta == null ? null : urlImagenProducto(fotoRuta!);

  /// Texto del estado para mostrar (abierto / cerrado / cierres especiales).
  String get textoEstado {
    if (abierto) return 'ABIERTO';
    if (cierreTipo == 'temporal') return 'CERRADO TEMPORALMENTE';
    if (cierreTipo == 'hasta_nuevo_aviso') return 'CERRADO HASTA NUEVO AVISO';
    return 'CERRADO';
  }

  /// Detalle del cierre: "Vuelve el 12/11 · Vacaciones".
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

/// Foto de un producto (con id y ruta para poder borrarla).
class ImagenProducto {
  final String? id;
  final String ruta;
  final int orden;
  ImagenProducto(this.id, this.ruta, this.orden);
  String get url => urlImagenProducto(ruta);
}

class Producto {
  final String id, idVendedor, idPuesto, nombre, estadoArticulo;
  final String? descripcion, categoria, puestoNombre, puestoEstado;
  final num? precio;
  final int? cantidad;
  final bool disponible;
  final List<String> imagenes;
  final List<ImagenProducto> fotos;
  String get idProducto => id;
  num? get precioReferencia => precio;
  int? get disponibilidad => cantidad;
  static Future<Producto> crearProducto(
    OperacionesVendedor operaciones, {
    required String idVendedor,
    required String idPuesto,
    required String nombre,
    String? idCategoria,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precioReferencia,
    int? disponibilidad,
  }) =>
      operaciones.crearProducto(
        idVendedor: idVendedor,
        idPuesto: idPuesto,
        nombre: nombre,
        idCategoria: idCategoria,
        descripcion: descripcion,
        estadoArticulo: estadoArticulo,
        precio: precioReferencia,
        cantidad: disponibilidad,
      );
  Future<Producto> actualizarStock(
    OperacionesVendedor operaciones,
    int cantidad,
  ) async {
    if (cantidad < 0) throw ArgumentError.value(cantidad, 'cantidad');
    await operaciones.actualizarProducto(id, {
      'cantidad_disponible': cantidad,
      'disponible': cantidad > 0,
    });
    return operaciones.productoPorId(id);
  }

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

  static List<ImagenProducto> _fotos(dynamic filas) {
    if (filas is! List) return [];
    final l = [
      for (final f in filas)
        ImagenProducto(
          f['id'] as String?,
          f['ruta_storage'] as String,
          (f['orden'] as int?) ?? 0,
        ),
    ]..sort((a, b) => a.orden.compareTo(b.orden));
    return l;
  }

  static List<String> _urls(dynamic filas) {
    if (filas is! List) return [];
    final l = List<Map<String, dynamic>>.from(filas)
      ..sort((a, b) => (a['orden'] as int).compareTo(b['orden'] as int));
    return l
        .map((f) => urlImagenProducto(f['ruta_storage'] as String))
        .toList();
  }
}

/// Fila de la vista v_puestos_resumen (inicio: destacado y tendencias).
class PuestoResumen {
  final String id, nombre, idTianguis;
  final String? tianguisNombre, categoria, descripcion, rutaImagen;
  final int? diaSemana;
  final double promedio; // 0 si aún no tiene calificaciones
  final int calificaciones, guardados;
  final bool abierto;

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
        abierto = m['abierto'] == true;

  String? get imagenUrl =>
      rutaImagen == null ? null : urlImagenProducto(rutaImagen!);

  static const _dias = [
    'DOMINGO',
    'LUNES',
    'MARTES',
    'MIÉRCOLES',
    'JUEVES',
    'VIERNES',
    'SÁBADO',
  ];

  /// "EL NIÑO 1 - LUNES"
  String get ubicacion {
    final d = diaSemana;
    final dia = (d != null && d >= 0 && d <= 6) ? _dias[d] : null;
    return [tianguisNombre?.toUpperCase(), dia].whereType<String>().join(' - ');
  }
}
