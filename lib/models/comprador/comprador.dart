import '../../services/catalogo_service.dart';
import '../../services/chat_service.dart';
import '../modelos.dart';

/// El ROL de quien busca productos y puestos en el tianguis.
///
/// No es una persona distinta: es lo que un Usuario puede hacer como comprador
/// (buscar, filtrar y proponer un precio). En la base de datos es la tabla
/// `compradores`, ligada a su cuenta.
class Comprador {
  final String idComprador, idUsuario;

  Comprador.fromMap(Map<String, dynamic> m)
      : idComprador = m['id_comprador'],
        idUsuario = m['id_usuario'];

  /// RF-06 · Buscar productos por palabra o categoría.
  Future<List<Producto>> buscarProductos({String? texto, String? idCategoria}) =>
      CatalogoService().buscarProductos(texto: texto, idCategoria: idCategoria);

  /// RF-07 · Filtrar por tianguis, día, categoría y rango de precio.
  Future<List<Producto>> filtrarProductos({
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
    int? diaSemana,
  }) =>
      CatalogoService().filtrarProductos(
        texto: texto,
        idCategoria: idCategoria,
        idTianguis: idTianguis,
        precioMin: precioMin,
        precioMax: precioMax,
        diaSemana: diaSemana,
      );

  /// RF-17 · Mandar al vendedor una propuesta de precio (regateo).
  Future<void> proponerPrecio({
    required String idProducto,
    required String idVendedor,
    required num monto,
  }) =>
      ChatService().proponerPrecio(idProducto: idProducto, idVendedor: idVendedor, monto: monto);
}
