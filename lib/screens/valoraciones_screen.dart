import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/moderacion.dart';

/// RF-43: el vendedor consulta sus valoraciones y etiquetas.
/// También puede solicitar la revisión de una calificación (RF-46).
class ValoracionesScreen extends StatefulWidget {
  final String idVendedor;
  const ValoracionesScreen({super.key, required this.idVendedor});
  @override
  State<ValoracionesScreen> createState() => _ValoracionesScreenState();
}

class _ValoracionesScreenState extends State<ValoracionesScreen> {
  final _db = Supabase.instance.client;
  late final Future<List<Map<String, dynamic>>> _futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() async {
    final r = await _db
        .from('calificaciones')
        .select('id, puntuacion, comentario, creada_en, puestos(nombre), '
            'calificacion_etiquetas(etiquetas_valoracion(nombre))')
        .eq('id_vendedor', widget.idVendedor)
        .eq('moderado', false)
        .order('creada_en', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  List<String> _etiquetas(Map<String, dynamic> c) => [
        for (final e in (c['calificacion_etiquetas'] as List? ?? []))
          if ((e['etiquetas_valoracion'] as Map?)?['nombre'] != null) e['etiquetas_valoracion']['nombre'] as String
      ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis valoraciones')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) return const Center(child: Text('Aún no tienes valoraciones'));
            final promedio = l.map((c) => (c['puntuacion'] as num).toDouble()).reduce((a, b) => a + b) / l.length;
            return ListView(padding: const EdgeInsets.all(12), children: [
              Center(
                child: Text('★ ${promedio.toStringAsFixed(1)}  (${l.length})', style: Tg.marcador(26)),
              ),
              const SizedBox(height: 10),
              for (final c in l)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('★' * (c['puntuacion'] as num).toInt(), style: const TextStyle(color: Tg.amarillo, fontSize: 18)),
                        const Spacer(),
                        Text('${(c['puestos'] as Map?)?['nombre'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      ]),
                      if ((c['comentario'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 6), child: Text(c['comentario'])),
                      if (_etiquetas(c).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 6, children: [for (final e in _etiquetas(c)) Chip(label: Text(e))]),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => solicitarRevision(context, idCalificacion: c['id'] as String),
                          child: const Text('Solicitar revisión'),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
