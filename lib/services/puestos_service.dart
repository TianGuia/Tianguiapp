import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/modelos.dart';
import 'comprador_id.dart';

// RF-09 se cumple aqui: se ven en un mapa los puestos que estan abiertos
// RF-10 se cumple aqui: se ve si el puesto esta abierto o cerrado y donde estaba la ultima vez
class PuestosService {
  final _db = Supabase.instance.client;

  Future<List<Puesto>> consultarMapa({String? idTianguis}) async {
    var q = _db.from('puestos').select().eq('activo', true).eq('estado', 'abierto');
    if (idTianguis != null) q = q.eq('id_tianguis', idTianguis);
    final r = await q.order('fecha_apertura', ascending: false);
    return r.map<Puesto>(Puesto.fromMap).toList();
  }

  // zonas, pasillos y espacios que el administrador registro para pintarlos en el mapa
  Future<List<Map<String, dynamic>>> zonasDeTianguis() =>
      _db.from('tianguis_zonas').select().order('orden');

  // horarios generales del tianguis.
  Future<List<Map<String, dynamic>>> horarios(String idTianguis) =>
      _db.from('tianguis_horarios').select().eq('id_tianguis', idTianguis).order('dia_semana');

  // RF-41 se cumple aqui: el comprador escribe el codigo que le da el vendedor para confirmar que si fue al puesto
  Future<String> verificarVisita(String codigo) async =>
      await _db.rpc('confirmar_visita', params: {'p_codigo': codigo.trim()})
          as String;

  // RF-42 se cumple aqui: salen las etiquetas que el comprador puede elegir al calificar
  // si falla la lectura devuelve lista vacia y se califica solo con estrellas y comentario
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

  // RF-42 se cumple aqui: despues de una visita confirmada el comprador deja su calificacion
  Future<void> registrarCalificacion({
    required String idVisita,
    required int puntuacion,
    String? comentario,
    List<String> idEtiquetas = const [],
  }) async {
    final c = await _db.from('calificaciones').insert({
      'id_visita': idVisita,
      'id_usuario': await miIdComprador(),
      'puntuacion': puntuacion,
      'comentario': comentario,
    }).select('id').single();
    if (idEtiquetas.isNotEmpty) {
      await _db.from('calificacion_etiquetas').insert([
        for (final e in idEtiquetas) {'id_calificacion': c['id'], 'id_etiqueta': e}
      ]);
    }
  }

  // lo que ve cualquier usuario: cuantas veces le pusieron cada etiqueta al puesto
  // nunca trae comentarios, esos solo los ve el vendedor. si falla devuelve lista vacia
  Future<List<({String nombre, int total})>> etiquetasDePuesto(String idPuesto) async {
    try {
      final r = await _db.rpc('etiquetas_puesto', params: {'p_puesto': idPuesto}) as List;
      return [
        for (final x in r) (nombre: '${x['nombre']}', total: (x['total'] as num).toInt()),
      ];
    } catch (_) {
      return const [];
    }
  }
}
