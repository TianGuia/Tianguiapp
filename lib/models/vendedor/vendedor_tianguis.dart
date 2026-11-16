import '../../services/vendedor_service.dart';

/// Une a un Vendedor con los tianguis donde trabaja normalmente (RF-20).
///
/// Existe porque un vendedor puede estar en varios tianguis y un tianguis tiene
/// muchos vendedores. En el diagrama se llama Vendedor_Tianguis; en Dart se
/// escribe sin guion bajo. Tabla `vendedor_tianguis`.
class VendedorTianguis {
  final String idVendedor, idTianguis;

  VendedorTianguis.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id_vendedor'],
        idTianguis = m['id_tianguis'];

  /// RF-20 · Agregar un tianguis a los habituales del vendedor.
  static Future<void> agregar(String idVendedor, String idTianguis) =>
      VendedorService().agregarTianguis(idVendedor, idTianguis);
}
