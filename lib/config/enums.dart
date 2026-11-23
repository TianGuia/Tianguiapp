// valores de los enum de la base, si en supabase son otros hay que cambiarlos aqui
class Enums {
  // conversaciones.contexto
  static const contextoProducto = 'producto';
  static const contextoEspacio = 'anuncio_espacio';

  // anuncios_espacio.rol, acuerdo y estado
  static const rolOfrezco = 'ofrece';
  static const rolBusco = 'solicita';
  static const acuerdos = ['renta', 'prestamo', 'traspaso'];
  static const anuncioAbierto = 'abierto';
  static const anuncioCerrado = 'cerrado';

  // reportes.tipo_objetivo, igual que en el panel de admin
  static const repPerfil = 'perfil';
  static const repProducto = 'producto';
  static const repAnuncioEspacio = 'anuncio_espacio';
  static const repMensaje = 'mensaje';
  static const repCalificacion = 'calificacion';
}
