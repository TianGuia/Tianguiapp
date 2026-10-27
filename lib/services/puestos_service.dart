import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/modelos.dart';
import '../models/confianza.dart';
import '../models/operaciones.dart';

/// RF-09, RF-10: mapa de puestos abiertos y su última ubicación.
class PuestosService implements OperacionesVisitas {
  PuestosService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;

  Future<List<Puesto>> abiertos({String? idTianguis}) async {
    var q =
        _db.from('puestos').select().eq('activo', true).eq('estado', 'abierto');
    if (idTianguis != null) q = q.eq('id_tianguis', idTianguis);
    final r = await q.order('fecha_apertura', ascending: false);
    return r.map<Puesto>(Puesto.fromMap).toList();
  }

  /// RF-13/RF-21: horarios generales del tianguis.
  Future<List<Map<String, dynamic>>> horarios(String idTianguis) => _db
      .from('tianguis_horarios')
      .select()
      .eq('id_tianguis', idTianguis)
      .order('dia_semana');

  /// RF-41: el comprador captura el código que le muestra el vendedor.
  /// Recupera la visita persistida por confirmar_visita, incluido su estado.
  @override
  Future<Visita> verificarVisita(String codigo) async {
    final id = await _db
        .rpc('confirmar_visita', params: {'p_codigo': codigo.trim()}) as String;
    return Visita.fromMap(
        await _db.from('visitas').select().eq('id', id).single());
  }

  /// RF-42: calificar una visita verificada. El trigger calificacion_desde_visita
  /// completa id_puesto e id_vendedor.
  @override
  Future<Calificacion> calificar({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) async {
    if (puntuacion < 1 || puntuacion > 5) {
      throw ArgumentError('La puntuación debe ser de 1 a 5');
    }
    final uid = _db.auth.currentUser!.id;
    final c = await _db
        .from('calificaciones')
        .insert({
          'id_visita': idVisita,
          'id_usuario': uid,
          'puntuacion': puntuacion,
          'comentario': comentario,
        })
        .select('id')
        .single();
    if (idEtiquetas.isNotEmpty) {
      await _db.from('calificacion_etiquetas').insert([
        for (final e in idEtiquetas)
          {'id_calificacion': c['id'], 'id_etiqueta': e}
      ]);
    }
    return Calificacion.fromMap(await _db
        .from('calificaciones')
        .select('*, calificacion_etiquetas(etiquetas_valoracion(nombre))')
        .eq('id', c['id'])
        .single());
  }
}
