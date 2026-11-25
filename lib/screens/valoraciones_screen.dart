import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../widgets/moderacion.dart';

// RF-43 se cumple aqui: el vendedor ve las calificaciones que le han dejado
// Revisión de calificaciones, descrita en el caso de uso del vendedor del SRS.
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
        .select('id, id_usuario, puntuacion, comentario, creada_en, puestos(nombre), '
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
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Mis valoraciones')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const CargandoTg();
            if (s.hasError) {
              return EstadoVacio(
                icono: Icons.wifi_off_rounded,
                color: Tg.rojo,
                titulo: '¡Se cayó la señal!',
                mensaje: 'No se pudieron cargar las valoraciones.\n${s.error}',
              );
            }
            final l = s.data!;
            if (l.isEmpty) {
              return const EstadoVacio(
                icono: Icons.star_rounded,
                titulo: '¡Aún no te califican!',
                mensaje: 'Cuando alguien visite tu puesto y te deje estrellas, tus valoraciones salen aquí.',
              );
            }
            final promedio = l.map((c) => (c['puntuacion'] as num).toDouble()).reduce((a, b) => a + b) / l.length;
            return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
              CabeceraTg(
                titulo: 'Tu reputación',
                subtitulo: 'Lo que dicen de tu puesto',
                icono: Icons.star_rounded,
                datos: [
                  DatoTg(Icons.star, Tg.amarillo, promedio.toStringAsFixed(1), 'PROMEDIO'),
                  DatoTg(Icons.rate_review, Tg.azulClaro, '${l.length}', 'VALORACIONES'),
                ],
              ),
              for (final c in l)
                TarjetaTg(
                  acento: Tg.amarillo,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('★' * (c['puntuacion'] as num).toInt(),
                          style: const TextStyle(color: Tg.amarillo, fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${(c['puestos'] as Map?)?['nombre'] ?? ''}',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    if ((c['comentario'] ?? '') != '')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${c['comentario']}', style: const TextStyle(fontSize: 16, height: 1.2)),
                      ),
                    if (_etiquetas(c).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(spacing: 6, runSpacing: 4, children: [
                          for (final e in _etiquetas(c)) PildoraTg(e, color: Tg.azulClaro, colorTexto: Tg.azulOscuro),
                        ]),
                      ),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                        onPressed: () => reportarContenido(
                          context,
                          tipoObjetivo: TipoReporte.calificacion,
                          idObjetivo: c['id'] as String,
                          idUsuarioReportado: c['id_usuario'] as String?,
                        ),
                        child: const Text('Reportar'),
                      ),
                      TextButton(
                        onPressed: () => solicitarRevision(context, idCalificacion: c['id'] as String),
                        child: const Text('Solicitar revisión'),
                      ),
                    ]),
                  ]),
                ),
            ]);
          },
        ),
      );
}
