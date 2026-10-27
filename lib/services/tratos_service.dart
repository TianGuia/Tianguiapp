import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../models/tratos.dart';
import '../models/operaciones.dart';

/// RF-17, RF-18, RF-31, RF-32: propuestas de precio y apartados.
/// Los cambios de estado pasan por funciones SQL (responder_propuesta,
/// responder_apartado) para que sean atómicos y validados.
class TratosService implements OperacionesTratos {
  TratosService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;
  String get _uid => _db.auth.currentUser!.id;

  static const _selProp = '*, productos(nombre, precio_referencia), '
      'comprador:compradores!propuestas_precio_id_comprador_fkey(usuarios!compradores_id_usuario_fkey(nombre_publico)), '
      'vendedor:perfiles_vendedor(nombre_negocio, usuarios(nombre_publico))';

  static const _selApart = '*, productos(nombre), '
      'comprador:compradores!apartados_id_comprador_fkey(usuarios!compradores_id_usuario_fkey(nombre_publico)), '
      'vendedor:perfiles_vendedor(nombre_negocio, usuarios(nombre_publico))';

  /// Marca como vencidos los apartados/ofertas pasados de fecha. Si no hay
  /// pg_cron en tu proyecto, esto es lo que los hace vencer. Nunca lanza error.
  Future<void> vencer() async {
    try {
      await _db.rpc('vencer_pendientes');
    } catch (_) {}
  }

  /// [idVendedor] != null → las que recibe ese vendedor; null → las que envié como comprador.
  Future<List<Propuesta>> propuestas({String? idVendedor}) async {
    final q = _db.from('propuestas_precio').select(_selProp);
    final r = await (idVendedor != null
            ? q.eq('id_vendedor', idVendedor)
            : q.eq('id_comprador', _uid))
        .order('creada_en', ascending: false)
        .limit(80);
    return r.map<Propuesta>(Propuesta.fromMap).toList();
  }

  Future<List<Apartado>> apartados({String? idVendedor}) async {
    final q = _db.from('apartados').select(_selApart);
    final r = await (idVendedor != null
            ? q.eq('id_vendedor', idVendedor)
            : q.eq('id_comprador', _uid))
        .order('creado_en', ascending: false)
        .limit(80);
    return r.map<Apartado>(Apartado.fromMap).toList();
  }

  Future<void> aceptarPropuesta(String id) => _db
      .rpc('responder_propuesta', params: {'p_id': id, 'p_accion': 'aceptar'});

  Future<void> rechazarPropuesta(String id) => _db
      .rpc('responder_propuesta', params: {'p_id': id, 'p_accion': 'rechazar'});

  Future<void> contraofertar(String id, num monto) =>
      _db.rpc('responder_propuesta',
          params: {'p_id': id, 'p_accion': 'contraofertar', 'p_monto': monto});

  @override
  Future<void> aceptarApartado(String id) => _db
      .rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'aceptar'});

  @override
  Future<Apartado> apartadoPorId(String id) async => Apartado.fromMap(
      await _db.from('apartados').select(_selApart).eq('id', id).single());

  @override
  Future<void> rechazarApartado(String id) => _db
      .rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'rechazar'});

  Future<void> cancelarApartado(String id) => _db
      .rpc('responder_apartado', params: {'p_id': id, 'p_accion': 'cancelar'});

  /// Pendientes por atender del vendedor (para el número en el botón).
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
    final porResponder =
        (props as List).where((p) => p['id_emisor'] != _uid).length;
    return porResponder + (aps as List).length;
  }
}
