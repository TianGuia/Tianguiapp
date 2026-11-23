import '../../services/catalogo_service.dart';
import '../../services/chat_service.dart';
import '../modelos.dart';

// el rol de quien busca productos y puestos, tabla compradores
class Comprador {
  final String idComprador, idUsuario;

  Comprador.fromMap(Map<String, dynamic> m)
      : idComprador = m['id_comprador'],
        idUsuario = m['id_usuario'];

  // rf-06 se cumple aqui: se buscan productos escribiendo una palabra o eligiendo una categoria
  Future<List<Producto>> buscarProductos({String? texto, String? idCategoria}) =>
      CatalogoService().buscarProductos(texto: texto, idCategoria: idCategoria);

  // rf-07 se cumple aqui: los productos se filtran por tianguis, dia, categoria y precio
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

  // rf-17 se cumple aqui: el comprador manda el precio que propone por un producto
  Future<void> proponerPrecio({
    required String idProducto,
    required String idVendedor,
    required num monto,
  }) =>
      ChatService().proponerPrecio(idProducto: idProducto, idVendedor: idVendedor, monto: monto);
}
