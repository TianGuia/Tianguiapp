import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../models/tratos.dart';
import 'comprador_id.dart';

// propuestas de precio y apartados
// rf-12 y rf-13 las crea el comprador, rf-26 y rf-27 las contesta el vendedor
// los cambios de estado van por funciones sql para que sean atomicos
class TratosService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  static const _selProp = '*, productos(nombre, precio_referencia), '
      'comprador:compradores!propuestas_precio_id_comprador_fkey(usuarios(nombre_publico)), '
      'vendedor:perfiles_vendedor(nombre_negocio, usuarios(nombre_publico))';

  static const _selApart = '*, productos(nombre), '
      'comprador:compradores!apartados_id_comprador_fkey(usuarios(nombre_publico)), '
      'vendedor:perfiles_vendedor(nombre_negocio, usuarios(nombre_publico))';

  // marca como vencidos los apartados y ofertas pasados de fecha
  // si no hay pg_cron esto es lo que los vence. no lanza error
  Future<void> vencer() async {
    try {
      await _db.rpc('vencer_pendientes');
    } catch (_) {} // si falla ya se venceran despues
  }

  // con idVendedor son las que recibe ese vendedor, sin el son las que mande como comprador
  Future<List<Propuesta>> propuestas({String? idVendedor}) async {
    final q = _db.from('propuestas_precio').select(_selProp);
    final r = await (idVendedor != null
            ? q.eq('id_vendedor', idVendedor)
            : q.eq('id_comprador', await miIdComprador()))
        .order('creada_en', ascending: false)
        .limit(80);
    return r.map<Propuesta>(Propuesta.fromMap).toList();
  }

  Future<List<Apartado>> apartados({String? idVendedor}) async {
    final q = _db.from('apartados').select(_selApart);
    final r = await (idVendedor != null
            ? q.eq('id_vendedor', idVendedor)
            : q.eq('id_comprador', await miIdComprador()))
        .order('creado_en', ascending: false)
        .limit(80);
    return r.map<Apartado>(Apartado.fromMap).toList();
  }

  Future<void> aceptarPropuesta(String id) =>
      _db.rpc('responder_propuesta', params: {'p_id': id, 'p_accion': 'aceptar'});

  Future<void> rechazarPropuesta(String id) =>
      _db.rpc('responder_propuesta', params: {'p_id': id, 'p_accion': 'rechazar'});

  Future<void> contraofertar(String id, num monto) => _db.rpc('responder_propuesta',
      params: {'p_id': id, 'p_accion': 'contraofertar', 'p_monto': monto});

  Future<void> aceptarApartado(String id) =>
      _db.rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'aceptar'});

  Future<void> rechazarApartado(String id) =>
      _db.rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'rechazar'});

  Future<void> cancelarApartado(String id) =>
      _db.rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'cancelar'});

  Future<int> pendientes(String idVendedor) async {
    final props = await _db
        .from('propuestas_precio')
        .select('id, id_emisor')
        .eq('id_vendedor', idVendedor)
        .eq('estado', Est.pendiente);
    final aps = await _db
        .from('apartados')
        .select('id')
        .eq('id_vendedor', idVendedor)
        .eq('estado', Est.pendiente);
    final porResponder = (props as List).where((p) => p['id_emisor'] != _uid).length;
    return porResponder + (aps as List).length;
  }
}
