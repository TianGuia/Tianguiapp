import '../../services/vendedor_service.dart';

// une a un vendedor con los tianguis donde trabaja, tabla vendedor_tianguis
// hace falta porque un vendedor puede estar en varios tianguis
class VendedorTianguis {
  final String idVendedor, idTianguis;

  VendedorTianguis.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id_vendedor'],
        idTianguis = m['id_tianguis'];

  // rf-15 se cumple aqui: el vendedor dice en que tianguis pone su puesto
  static Future<void> agregar(String idVendedor, String idTianguis) =>
      VendedorService().agregarTianguis(idVendedor, idTianguis);
}
