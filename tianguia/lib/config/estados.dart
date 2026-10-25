/// Valores de los ENUM de Supabase que usa la app. Si tu base usa otros
/// textos, cámbialos aquí y en supabase/04_tratos_ofertas.sql.
class Est {
  static const pendiente = 'pendiente';
  // estado_propuesta
  static const propAceptada = 'aceptada';
  static const propRechazada = 'rechazada';
  static const propContra = 'contraofertada';
  // estado_apartado
  static const apAceptado = 'aceptado';
  static const apRechazado = 'rechazado';
  static const apCancelado = 'cancelado';
  static const apExpirado = 'expirado';
  // estado_oferta
  static const ofertaActiva = 'activa';
  static const ofertaFinalizada = 'finalizada';
}
