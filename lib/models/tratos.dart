import '../config/estados.dart';
import 'operaciones.dart';

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
        compradorNombre = ((m['comprador'] as Map?)?['usuarios']
            as Map?)?['nombre_publico'] as String?,
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
  final DateTime fechaInicio;
  String get idApartado => id;
  DateTime? get fechaExpiracion => expira;
  static Future<Apartado> solicitarApartado(
    OperacionesChat operaciones, {
    required String idProducto,
    required String idVendedor,
    int cantidad = 1,
    Duration vigencia = const Duration(hours: 24),
  }) =>
      operaciones.solicitarApartado(
        idProducto: idProducto,
        idVendedor: idVendedor,
        cantidad: cantidad,
        vigencia: vigencia,
      );
  Future<Apartado> aceptarApartado(OperacionesTratos operaciones) async {
    await operaciones.aceptarApartado(id);
    return operaciones.apartadoPorId(id);
  }

  Future<Apartado> rechazarApartado(OperacionesTratos operaciones) async {
    await operaciones.rechazarApartado(id);
    return operaciones.apartadoPorId(id);
  }

  Apartado.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idProducto = m['id_producto'],
        idComprador = m['id_comprador'],
        idVendedor = m['id_vendedor'],
        estado = m['estado'],
        cantidad = (m['cantidad'] as num).toInt(),
        productoNombre = (m['productos'] as Map?)?['nombre'] as String?,
        compradorNombre = ((m['comprador'] as Map?)?['usuarios']
            as Map?)?['nombre_publico'] as String?,
        vendedorNombre = _nombreVendedor(m['vendedor']),
        fechaInicio = DateTime.parse(m['fecha_inicio']),
        expira = m['fecha_expiracion'] == null
            ? null
            : DateTime.parse(m['fecha_expiracion']).toLocal();

  bool get pendiente => estado == Est.pendiente;
  bool get aceptado => estado == Est.apAceptado;
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
  final String id, idProducto, estado;
  final String? titulo;
  final DateTime inicio, fin;
  final num? precioPromocional, descuento;
  final OfertaItem item;
  String get idOferta => id;
  DateTime get fechaInicio => inicio;
  DateTime get fechaFin => fin;
  static Future<Oferta> publicarOferta(
    OperacionesVendedor operaciones, {
    required String idVendedor,
    required String idProducto,
    required String titulo,
    required DateTime fin,
    num? precioPromocional,
    num? descuento,
  }) async =>
      (await operaciones.publicarOferta(
        idVendedor: idVendedor,
        titulo: titulo,
        fin: fin,
        productos: [
          (
            idProducto: idProducto,
            precioPromo: precioPromocional,
            descuento: descuento,
          ),
        ],
      ))
          .single;
  Future<Oferta> finalizarOferta(OperacionesVendedor operaciones) async {
    await operaciones.terminarOferta(id);
    return operaciones.ofertaPorId(id);
  }

  Oferta.fromMap(Map<String, dynamic> m)
      : id = m['id'],
        idProducto = m['id_producto'],
        estado = m['estado'],
        titulo = m['titulo'] as String?,
        inicio = DateTime.parse(m['fecha_inicio']),
        fin = DateTime.parse(m['fecha_fin']).toLocal(),
        precioPromocional = m['precio_promocional'] as num?,
        descuento = m['descuento'] as num?,
        item = OfertaItem(
          (m['productos'] as Map?)?['nombre'] as String? ?? 'Producto',
          (m['productos'] as Map?)?['precio_referencia'] as num?,
          m['precio_promocional'] as num?,
          m['descuento'] as num?,
        );

  bool get vigente {
    final ahora = DateTime.now();
    return estado == Est.ofertaActiva &&
        !inicio.isAfter(ahora) &&
        fin.isAfter(ahora);
  }
}

/// Oferta que se muestra al comprador en el detalle del producto.
class OfertaVigente {
  final String? titulo;
  final DateTime fin;
  final num precio;
  OfertaVigente(this.titulo, this.fin, this.precio);
}
