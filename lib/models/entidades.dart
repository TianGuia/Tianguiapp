// Entidades del diagrama de clases de TianGuía que no tenían clase propia.
// Los nombres de clases, atributos y métodos siguen el diagrama (SRS).
// Los atributos usan camelCase (convención de Dart): id_usuario -> idUsuario.
// Cada método delega en el servicio correspondiente, donde vive la lógica.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/catalogo_service.dart';
import '../services/chat_service.dart';
import '../services/puestos_service.dart';
import '../services/vendedor_service.dart';
import 'modelos.dart';

/// Cuenta de la plataforma (tabla `usuarios`). Comprador y Vendedor son
/// especializaciones solapadas: una misma cuenta puede tener ambos roles.
class Usuario {
  final String idUsuario, nombre, estadoCuenta;
  final String? correo, telefono, fotoPerfil;
  final DateTime fechaRegistro;

  Usuario.fromMap(Map<String, dynamic> m)
      : idUsuario = m['id'],
        nombre = m['nombre_publico'],
        correo = m['correo'],
        telefono = m['telefono'],
        fotoPerfil = m['foto_url'],
        estadoCuenta = m['estado_cuenta'].toString(),
        fechaRegistro = DateTime.parse(m['creado_en']).toLocal();

  /// RF-01
  static Future<void> registrar(String nombre) => AuthService().registrar(nombre);

  /// RF-03
  static Future<void> iniciarSesion(String correo, String codigo) =>
      AuthService().iniciarSesion(correo, codigo);

  /// RF-05
  Future<void> actualizarPerfil({String? nombre, String? telefono, String? fotoUrl}) =>
      AuthService().actualizarPerfil(nombre: nombre, telefono: telefono, fotoUrl: fotoUrl);
}

/// Rol de comprador (tabla `compradores`).
class Comprador {
  final String idComprador, idUsuario;

  Comprador.fromMap(Map<String, dynamic> m)
      : idComprador = m['id_comprador'],
        idUsuario = m['id_usuario'];

  /// RF-06
  Future<List<Producto>> buscarProductos({String? texto, String? idCategoria}) =>
      CatalogoService().buscarProductos(texto: texto, idCategoria: idCategoria);

  /// RF-07
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

  /// RF-17
  Future<void> proponerPrecio({
    required String idProducto,
    required String idVendedor,
    required num monto,
  }) =>
      ChatService().proponerPrecio(idProducto: idProducto, idVendedor: idVendedor, monto: monto);
}

/// Perfil de vendedor (tabla `perfiles_vendedor`).
class Vendedor {
  final String idVendedor, idUsuario, estado;
  final String? nombreNegocio, descripcion;
  final DateTime fechaHabilitacion;

  Vendedor.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id'],
        idUsuario = m['id_usuario'],
        nombreNegocio = m['nombre_negocio'],
        descripcion = m['descripcion'],
        estado = m['estado'].toString(),
        fechaHabilitacion = DateTime.parse(m['fecha_habilitacion']).toLocal();

  /// RF-19
  static Future<String> habilitarPerfil({String? nombreNegocio, String? descripcion}) =>
      VendedorService().habilitarPerfil(nombreNegocio: nombreNegocio, descripcion: descripcion);

  /// RF-21
  Future<void> registrarHorario(String idTianguis, int dia, String inicio, String fin) =>
      VendedorService().registrarHorario(idVendedor, idTianguis, dia, inicio, fin);

  /// RF-22
  Future<void> registrarAusencia(String idTianguis, DateTime fecha, {String? motivo}) =>
      VendedorService().registrarAusencia(idVendedor, idTianguis, fecha, motivo: motivo);
}

/// Confirmación de presencia en un puesto (tabla `visitas`).
class Visita {
  final String idVisita, idComprador, idPuesto, metodoVerificacion, estado;
  final String? idJornada;
  final DateTime fechaHora;

  Visita.fromMap(Map<String, dynamic> m)
      : idVisita = m['id'],
        idComprador = m['id_usuario'],
        idPuesto = m['id_puesto'],
        idJornada = m['id_jornada'],
        metodoVerificacion = m['metodo_verificacion'],
        estado = m['estado'],
        fechaHora = DateTime.parse(m['fecha_hora']).toLocal();

  /// RF-41: devuelve el id de la visita creada.
  static Future<String> verificarVisita(String codigo) => PuestosService().verificarVisita(codigo);
}

/// Valoración de una visita verificada (tabla `calificaciones`).
class Calificacion {
  final String idCalificacion, idComprador, idPuesto, idVendedor;
  final int puntuacion;
  final String? comentario;
  final List<String> etiquetas;
  final DateTime fechaCreacion;

  Calificacion.fromMap(Map<String, dynamic> m)
      : idCalificacion = m['id'],
        idComprador = m['id_usuario'],
        idPuesto = m['id_puesto'],
        idVendedor = m['id_vendedor'],
        puntuacion = (m['puntuacion'] as num).toInt(),
        comentario = m['comentario'],
        etiquetas = [
          for (final e in (m['calificacion_etiquetas'] as List? ?? const []))
            ((e['etiquetas_valoracion'] as Map?)?['nombre'] ?? '').toString()
        ]..removeWhere((e) => e.isEmpty),
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  /// RF-42
  static Future<void> registrarCalificacion({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) =>
      PuestosService().registrarCalificacion(
        idVisita: idVisita,
        puntuacion: puntuacion,
        comentario: comentario,
        idEtiquetas: idEtiquetas,
      );
}

/// Canal privado entre usuarios (tabla `conversaciones`).
class Conversacion {
  final String idConversacion, estado;
  final String? contexto, idProducto, idAnuncioEspacio;
  final DateTime fechaCreacion;

  Conversacion.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id'],
        estado = m['estado'],
        contexto = m['contexto']?.toString(),
        idProducto = m['id_producto'],
        idAnuncioEspacio = m['id_anuncio_espacio'],
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  /// RF-16 / RF-35: devuelve el id de la conversación (nueva o existente).
  static Future<String> iniciarConversacion({
    String? idProducto,
    String? idAnuncio,
    required String idUsuarioReceptor,
  }) =>
      ChatService().iniciarConversacion(
        idProducto: idProducto,
        idAnuncio: idAnuncio,
        idUsuarioReceptor: idUsuarioReceptor,
      );
}

/// Contenido enviado dentro de una conversación (tabla `mensajes`).
class Mensaje {
  final String idMensaje, idConversacion, idRemitente, contenido;
  final String? estado;
  final DateTime fechaEnvio;

  Mensaje.fromMap(Map<String, dynamic> m)
      : idMensaje = m['id'],
        idConversacion = m['id_conversacion'],
        idRemitente = m['id_remitente'],
        contenido = m['contenido'],
        estado = m['estado'],
        fechaEnvio = DateTime.parse(m['enviado_en']).toLocal();

  /// RF-37
  static Future<void> enviarMensaje(String idConversacion, String texto) =>
      ChatService().enviarMensaje(idConversacion, texto);
}

/// Reporte de contenido o de un usuario (tabla `reportes`).
class Reporte {
  final String idReporte, idUsuario, tipo, idReferencia, motivo, estado;
  final DateTime fechaCreacion;

  Reporte.fromMap(Map<String, dynamic> m)
      : idReporte = m['id'],
        idUsuario = m['id_reportante'],
        tipo = m['tipo_objetivo'].toString(),
        idReferencia = m['id_objetivo'],
        motivo = m['motivo'],
        estado = m['estado'].toString(),
        fechaCreacion = DateTime.parse(m['creado_en']).toLocal();

  /// RF-44
  static Future<void> crearReporte({
    required String tipoObjetivo,
    required String idObjetivo,
    String? idUsuarioReportado,
    required String motivo,
  }) =>
      ChatService().crearReporte(
        tipoObjetivo: tipoObjetivo,
        idObjetivo: idObjetivo,
        idUsuarioReportado: idUsuarioReportado,
        motivo: motivo,
      );
}

/// Solicitud de revisión de una medida, reporte o calificación (tabla `apelaciones`).
class Apelacion {
  final String idApelacion, idUsuario, motivo, estado;
  final String? idReporte, resolucion;
  final DateTime fechaCreacion;

  Apelacion.fromMap(Map<String, dynamic> m)
      : idApelacion = m['id'],
        idUsuario = m['id_usuario'],
        idReporte = m['id_reporte'],
        motivo = m['motivo'],
        estado = m['estado'].toString(),
        resolucion = m['resolucion']?.toString(),
        fechaCreacion = DateTime.parse(m['creada_en']).toLocal();

  /// RF-46: pasa exactamente uno de [idMedida], [idReporte] o [idCalificacion].
  static Future<void> solicitarRevision({
    String? idMedida,
    String? idReporte,
    String? idCalificacion,
    required String motivo,
  }) {
    final db = Supabase.instance.client;
    return db.from('apelaciones').insert({
      'id_usuario': db.auth.currentUser!.id,
      'id_medida': idMedida,
      'id_reporte': idReporte,
      'id_calificacion': idCalificacion,
      'motivo': motivo,
    });
  }
}

/// Entidad asociativa Participante (tabla `participantes`): relaciona cada
/// Usuario con las Conversaciones en las que participa. Llave: (idConversacion, idUsuario).
class Participante {
  final String idConversacion, idUsuario;

  Participante.fromMap(Map<String, dynamic> m)
      : idConversacion = m['id_conversacion'],
        idUsuario = m['id_usuario'];
}

/// Entidad asociativa Vendedor_Tianguis (tabla `vendedor_tianguis`): tianguis en
/// los que opera habitualmente un Vendedor (RF-20). Llave: (idVendedor, idTianguis).
/// En Dart se escribe en PascalCase: Vendedor_Tianguis -> VendedorTianguis.
class VendedorTianguis {
  final String idVendedor, idTianguis;

  VendedorTianguis.fromMap(Map<String, dynamic> m)
      : idVendedor = m['id_vendedor'],
        idTianguis = m['id_tianguis'];

  /// RF-20: asocia al vendedor con un tianguis habitual.
  static Future<void> agregar(String idVendedor, String idTianguis) =>
      VendedorService().agregarTianguis(idVendedor, idTianguis);
}
