/// Valores de ENUM de la base de datos que el código necesita.
///
/// CONFIRMAR en Supabase > SQL Editor y ajustar aquí si difieren:
///   select t.typname, string_agg(e.enumlabel, ', ' order by e.enumsortorder)
///   from pg_type t join pg_enum e on e.enumtypid = t.oid group by t.typname;
class Enums {
  // conversaciones.contexto (ya se usa 'producto')
  static const contextoProducto = 'producto';
  static const contextoEspacio = 'anuncio_espacio';

  // anuncios_espacio.rol / acuerdo / estado (el default de estado es 'abierto')
  static const rolOfrezco = 'ofrece';
  static const rolBusco = 'solicita';
  static const acuerdos = ['renta', 'prestamo', 'traspaso'];
  static const anuncioAbierto = 'abierto';
  static const anuncioCerrado = 'cerrado';

  // reportes.tipo_objetivo (mismos valores que interpreta el panel de admin)
  static const repPerfil = 'perfil';
  static const repProducto = 'producto';
  static const repAnuncioEspacio = 'anuncio_espacio';
  static const repMensaje = 'mensaje';
  static const repCalificacion = 'calificacion';
}
