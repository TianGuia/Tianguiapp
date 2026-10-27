import 'identidad.dart';
import 'confianza.dart';
import 'mensajeria.dart';
import 'modelos.dart';
import 'tratos.dart';

/// Puertos del dominio. Los adaptadores de Supabase viven en services/.
abstract interface class OperacionesUsuario {
  Future<void> entrarAnonimo(String nombre);
  Future<void> verificarCodigo(String correo, String codigo);
  Future<Usuario?> miPerfil();
  Future<void> actualizarPerfil({
    String? nombre,
    String? telefono,
    String? fotoUrl,
  });
}

abstract interface class OperacionesCatalogo {
  Future<List<Producto>> buscar({
    String? texto,
    String? idCategoria,
    String? idTianguis,
    num? precioMin,
    num? precioMax,
  });
  Future<MapaTianguis> consultarMapa(String idTianguis);
}

abstract interface class OperacionesVendedor {
  Future<Vendedor> habilitarPerfil({
    String? nombreNegocio,
    String? descripcion,
  });
  Future<void> agregarHorario(
    String idVendedor,
    String idTianguis,
    int dia,
    String inicio,
    String fin,
  );
  Future<void> registrarAusencia(
    String idVendedor,
    String idTianguis,
    DateTime fecha, {
    String? motivo,
  });
  Future<String> abrirPuesto(String idPuesto);
  Future<void> cerrarPuesto(String idPuesto);
  Future<Puesto> puestoPorId(String idPuesto);
  Future<Producto> crearProducto({
    required String idVendedor,
    required String idPuesto,
    String? idCategoria,
    required String nombre,
    String? descripcion,
    String estadoArticulo = 'nuevo',
    num? precio,
    int? cantidad,
  });
  Future<void> actualizarProducto(String id, Map<String, dynamic> cambios);
  Future<Producto> productoPorId(String id);
  Future<List<Oferta>> publicarOferta({
    required String idVendedor,
    required String titulo,
    required DateTime fin,
    required List<({String idProducto, num? precioPromo, num? descuento})>
        productos,
  });
  Future<void> terminarOferta(String idOferta);
  Future<Oferta> ofertaPorId(String idOferta);
}

abstract interface class OperacionesChat {
  Future<Conversacion> iniciarConversacion({
    String? idProducto,
    String? idReceptor,
  });
  Future<Mensaje> enviar(String idConversacion, String texto);
  Future<Propuesta> proponerPrecio({
    required String idProducto,
    required String idVendedor,
    required num monto,
  });
  Future<Apartado> solicitarApartado({
    required String idProducto,
    required String idVendedor,
    int cantidad = 1,
    Duration vigencia = const Duration(hours: 24),
  });
}

abstract interface class OperacionesTratos {
  Future<void> aceptarApartado(String id);
  Future<void> rechazarApartado(String id);
  Future<Apartado> apartadoPorId(String id);
}

abstract interface class OperacionesVisitas {
  Future<Visita> verificarVisita(String codigo);
  Future<Calificacion> calificar({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  });
}

abstract interface class OperacionesConfianza {
  Future<Reporte> reportar({
    required String tipoObjetivo,
    required String idObjetivo,
    String? idUsuarioReportado,
    required String motivo,
  });
  Future<Apelacion> solicitarRevision({
    String? idReporte,
    required String motivo,
  });
}
