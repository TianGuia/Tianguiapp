import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/confianza.dart';
import '../models/operaciones.dart';

class ConfianzaService implements OperacionesConfianza {
  ConfianzaService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;
  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<Reporte> reportar({
    required String tipoObjetivo,
    required String idObjetivo,
    String? idUsuarioReportado,
    required String motivo,
  }) async {
    if (motivo.trim().isEmpty) {
      throw ArgumentError('Escribe el motivo del reporte');
    }
    return Reporte.fromMap(
      await _db
          .from('reportes')
          .insert({
            'id_reportante': _uid,
            'tipo_objetivo': tipoObjetivo,
            'id_objetivo': idObjetivo,
            'id_usuario_reportado': idUsuarioReportado,
            'motivo': motivo.trim(),
          })
          .select()
          .single(),
    );
  }

  @override
  Future<Apelacion> solicitarRevision({
    String? idReporte,
    required String motivo,
  }) async {
    if (motivo.trim().isEmpty) {
      throw ArgumentError('Escribe el motivo de la revisión');
    }
    return Apelacion.fromMap(
      await _db
          .from('apelaciones')
          .insert({
            'id_usuario': _uid,
            'id_reporte': idReporte,
            'motivo': motivo.trim(),
          })
          .select()
          .single(),
    );
  }

  Future<List<Reporte>> misReportes() async => (await _db
          .from('reportes')
          .select()
          .eq('id_reportante', _uid)
          .order('creado_en', ascending: false))
      .map(Reporte.fromMap)
      .toList();
  Future<List<Apelacion>> misApelaciones() async => (await _db
          .from('apelaciones')
          .select()
          .eq('id_usuario', _uid)
          .order('creada_en', ascending: false))
      .map(Apelacion.fromMap)
      .toList();
}
