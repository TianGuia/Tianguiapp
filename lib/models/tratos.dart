import '../config/estados.dart';
import '../services/chat_service.dart';
import '../services/tratos_service.dart';
import '../services/vendedor_service.dart';

/// "25/10 16:30"
String fmtFecha(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.day)}/${dos(l.month)} ${dos(l.hour)}:${dos(l.minute)}';
}

String? _nombreVendedor(dynamic v) {
  if (v is! Map) return null;
  final n = v['nombre_negocio'] as String?;
  if (n != null && n.isNotEmpty) return n;
  return (v['usuarios'] as Map?)?['nombre_publico'] as String?;
}

/// RF-17 / RF-31: propuesta de precio (o contraoferta, si trae idAnterior).
class Propuesta {
  final String id, idProducto, idComprador, idVendedor, idEmisor, estado;
  final String? idAnterior, productoNombre, compradorNombre, vendedorNombre;
  final num monto;
  final num? precioRef;
  final DateTime creada;

  Propuesta.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idProducto = m['id_producto'],
        idComprador = m['id_comprador'],
        idVendedor = m['id_vendedor'],
        idEmisor = m['id_emisor'],
        idAnterior = m['id_propuesta_anterior'],
        estado = m['estado'],
        monto = m['monto'] as num,
        precioRef = (m['productos'] as Map?)?['precio_referencia'] as num?,
        productoNombre = (m['productos'] as Map?)?['nombre'] as String?,
        compradorNombre = ((m['comprador'] as Map?)?['usuarios'] as Map?)?['nombre_publico'] as String?,
        vendedorNombre = _nombreVendedor(m['vendedor']),
        creada = DateTime.parse(m['creada_en']).toLocal();

  bool get pendiente => estado == Est.pendiente;
  bool get esContraoferta => idAnterior != null;
}

/// RF-18 / RF-32: apartado temporal.
class Apartado {
  final String id, idProducto, idComprador, idVendedor, estado;
  final String? productoNombre, compradorNombre, vendedorNombre;
  final int cantidad;
  final DateTime? expira;

  Apartado.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idProducto = m['id_producto'],
        idComprador = m['id_comprador'],
        idVendedor = m['id_vendedor'],
        estado = m['estado'],
        cantidad = (m['cantidad'] as num).toInt(),
        productoNombre = (m['productos'] as Map?)?['nombre'] as String?,
        compradorNombre = ((m['comprador'] as Map?)?['usuarios'] as Map?)?['nombre_publico'] as String?,
        vendedorNombre = _nombreVendedor(m['vendedor']),
        expira = m['fecha_expiracion'] == null
            ? null
            : DateTime.parse(m['fecha_expiracion']).toLocal();

  bool get pendiente => estado == Est.pendiente;
  bool get aceptado => estado == Est.apAceptado;

  /// RF-18
  static Future<void> solicitarApartado({
    required String idProducto,
    required String idVendedor,
    int cantidad = 1,
  }) =>
      ChatService().solicitarApartado(idProducto: idProducto, idVendedor: idVendedor, cantidad: cantidad);

  /// RF-32
  Future<void> aceptarApartado() => TratosService().aceptarApartado(id);

  /// RF-32
  Future<void> rechazarApartado() => TratosService().rechazarApartado(id);
}

/// Renglón de una oferta: un producto con su descuento o precio promocional.
class OfertaItem {
  final String producto;
  final num? ref, promo, descuento;
  OfertaItem(this.producto, this.ref, this.promo, this.descuento);

  num? get precioFinal => precioPromo(ref, promo, descuento);
}

/// Precio final: el promocional si existe; si no, el de referencia menos el %.
num? precioPromo(num? ref, num? promo, num? descuento) {
  if (promo != null) return promo;
  if (ref != null && descuento != null) {
    final v = ref * (1 - descuento / 100);
    return (v * 100).round() / 100;
  }
  return null;
}

/// RF-29 / RF-30
class Oferta {
  /// id de la oferta (si agrupa varios productos, el de la primera fila).
  final String id, estado;
  final String? titulo;
  final DateTime fin;
  final List<OfertaItem> items;

  Oferta._(this.id, this.estado, this.titulo, this.fin, this.items);

  /// En la base cada fila de `ofertas` es un producto (id_producto). Una
  /// publicación con varios productos son varias filas enlazadas por
  /// id_oferta_origen; aquí se unen en una sola [Oferta].
  factory Oferta.fromFilas(List<Map<String, dynamic>> filas) {
    final p = filas.first;
    return Oferta._(
      (p['id_oferta_origen'] ?? p['id']) as String,
      filas.any((f) => f['estado'] == Est.ofertaActiva) ? Est.ofertaActiva : p['estado'] as String,
      p['titulo'] as String?,
      DateTime.parse(p['fecha_fin']).toLocal(),
      [
        for (final f in filas)
          OfertaItem(
            (f['productos'] as Map?)?['nombre'] as String? ?? 'Producto',
            (f['productos'] as Map?)?['precio_referencia'] as num?,
            f['precio_promocional'] as num?,
            f['descuento'] as num?,
          )
      ],
    );
  }

  factory Oferta.fromMap(Map<String, dynamic> m) => Oferta.fromFilas([m]);

  /// Agrupa las filas de `ofertas` por publicación (conserva el orden recibido).
  static List<Oferta> agrupar(List<Map<String, dynamic>> filas) {
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final f in filas) {
      grupos.putIfAbsent((f['id_oferta_origen'] ?? f['id']) as String, () => []).add(f);
    }
    return grupos.values.map(Oferta.fromFilas).toList();
  }

  bool get vigente => estado == Est.ofertaActiva && fin.isAfter(DateTime.now());

  /// RF-29
  static Future<void> publicarOferta({
    required String idVendedor,
    required String titulo,
    required DateTime fin,
    required List<({String idProducto, num? precioPromo, num? descuento})> productos,
  }) =>
      VendedorService().publicarOferta(
        idVendedor: idVendedor,
        titulo: titulo,
        fin: fin,
        productos: productos,
      );

  /// RF-30
  Future<void> finalizarOferta() => VendedorService().finalizarOferta(id);
}

/// Oferta que se muestra al comprador en el detalle del producto.
class OfertaVigente {
  final String? titulo;
  final DateTime fin;
  final num precio;
  OfertaVigente(this.titulo, this.fin, this.precio);
}
