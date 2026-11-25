import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';

// el administrador lee los avisos de falla que mandan las personas desde Perfil > Reportar una falla
// la tabla es reportes_falla (migracion 20261128000000 de Toldo)
class AdminFallasScreen extends StatefulWidget {
  const AdminFallasScreen({super.key});
  @override
  State<AdminFallasScreen> createState() => _AdminFallasScreenState();
}

class _AdminFallasScreenState extends State<AdminFallasScreen> {
  static const _tipos = <String, (String, IconData, Color)>{
    'no_funciona': ('Algo no funciona', Icons.error_outline, Tg.rojo),
    'se_traba': ('Se traba o se cierra', Icons.hourglass_bottom, Tg.naranja),
    'se_ve_mal': ('Se ve mal', Icons.visibility_off_outlined, Tg.rosa),
    'sugerencia': ('Idea', Icons.lightbulb_outline, Tg.amarillo),
    'otra': ('Otra cosa', Icons.chat_bubble_outline, Tg.azulClaro),
  };

  late Future<List<Map<String, dynamic>>> _futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() async {
    final r = await Supabase.instance.client
        .from('reportes_falla')
        .select('id, tipo, descripcion, plataforma, creada_en')
        .order('creada_en', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(r);
  }

  String _fecha(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : d.toString().substring(0, 16);
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Admin · Fallas')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const CargandoTg();
            if (s.hasError) {
              return EstadoVacio(
                icono: Icons.wifi_off_rounded,
                color: Tg.rojo,
                titulo: 'No se pudieron cargar',
                mensaje: '${s.error}\n(revisa que la migración de fallas esté aplicada)',
                accionTexto: 'Reintentar',
                accionIcono: Icons.refresh,
                onAccion: () => setState(() => _futuro = _cargar()),
              );
            }
            final l = s.data!;
            if (l.isEmpty) {
              return const EstadoVacio(
                icono: Icons.verified,
                color: Tg.verde,
                titulo: '¡Sin fallas!',
                mensaje: 'Nadie ha reportado nada por ahora.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _futuro = _cargar());
                await _futuro;
              },
              child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                CabeceraTg(
                  titulo: 'Avisos de falla',
                  subtitulo: 'Lo más reciente primero',
                  icono: Icons.bug_report,
                  color: Tg.rosa,
                  datos: [DatoTg(Icons.report_problem, Tg.amarillo, '${l.length}', 'AVISOS')],
                ),
                for (final f in l) _tarjeta(f),
              ]),
            );
          },
        ),
      );

  Widget _tarjeta(Map<String, dynamic> f) {
    final t = _tipos['${f['tipo']}'] ?? _tipos['otra']!;
    return TarjetaTg(
      acento: t.$3,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SelloTg(icono: t.$2, color: t.$3, tam: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text('${f['descripcion']}', style: const TextStyle(fontSize: 15, height: 1.15)),
            const SizedBox(height: 4),
            Text('${_fecha(f['creada_en'])} · ${f['plataforma'] ?? '—'}',
                style: const TextStyle(color: Tg.azulClaro, fontWeight: FontWeight.w800, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}
