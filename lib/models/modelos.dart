import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

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
}

class Puesto {
  final String id, idVendedor, idTianguis, nombre, estado;
  final String? codigo;
  final double? lat, lng;
  final DateTime? fechaApertura;
  bool get abierto => estado == 'abierto';
  Puesto.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idVendedor = m['id_vendedor'],
        idTianguis = m['id_tianguis'],
        nombre = m['nombre'],
        codigo = m['codigo'],
        estado = m['estado'],
        lat = (m['latitud'] as num?)?.toDouble(),
        lng = (m['longitud'] as num?)?.toDouble(),
        fechaApertura = m['fecha_apertura'] == null
            ? null
            : DateTime.parse(m['fecha_apertura']).toLocal();
}

class Producto {
  final String id, idVendedor, nombre, estadoArticulo;
  final String? idPuesto, descripcion, categoria, puestoNombre;
  final num? precio;
  final int? cantidad;
  final bool disponible;
  final List<String> imagenes;

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
        imagenes = _urls(m['producto_imagenes']);

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
