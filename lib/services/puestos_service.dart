import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/modelos.dart';

/// RF-09, RF-10: mapa de puestos abiertos y su última ubicación.
class PuestosService {
  final _db = Supabase.instance.client;

  Future<List<Puesto>> abiertos({String? idTianguis}) async {
    var q = _db.from('puestos').select().eq('activo', true).eq('estado', 'abierto');
    if (idTianguis != null) q = q.eq('id_tianguis', idTianguis);
    final r = await q.order('fecha_apertura', ascending: false);
    return r.map<Puesto>(Puesto.fromMap).toList();
  }

  /// RF-13/RF-21: horarios generales del tianguis.
  Future<List<Map<String, dynamic>>> horarios(String idTianguis) =>
      _db.from('tianguis_horarios').select().eq('id_tianguis', idTianguis).order('dia_semana');

  /// RF-41: el comprador captura el código que le muestra el vendedor.
  /// Devuelve el id de la visita (función confirmar_visita).
  Future<String> verificarVisita(String codigo) async =>
      await _db.rpc('confirmar_visita', params: {'p_codigo': codigo.trim()})
          as String;

  /// RF-42: etiquetas descriptivas que el comprador puede elegir al calificar.
  /// Si la columna `activa` no existe o la lectura falla, devuelve lista vacía
  /// y la calificación sigue funcionando solo con estrellas y comentario.
  Future<List<Map<String, dynamic>>> etiquetasValoracion() async {
    try {
      final r = await _db
          .from('etiquetas_valoracion')
          .select('id, nombre')
          .eq('activa', true)
          .order('nombre');
      return List<Map<String, dynamic>>.from(r);
    } catch (_) {
      return const [];
    }
  }

  /// RF-42: calificar una visita verificada. El trigger calificacion_desde_visita
  /// completa id_puesto e id_vendedor.
  Future<void> calificar({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) async {
    final uid = _db.auth.currentUser!.id;
    final c = await _db.from('calificaciones').insert({
      'id_visita': idVisita,
      'id_usuario': uid,
      'puntuacion': puntuacion,
      'comentario': comentario,
    }).select('id').single();
    if (idEtiquetas.isNotEmpty) {
      await _db.from('calificacion_etiquetas').insert([
        for (final e in idEtiquetas) {'id_calificacion': c['id'], 'id_etiqueta': e}
      ]);
    }
  }
}
