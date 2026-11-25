import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../services/ocultos.dart';
import '../widgets/moderacion.dart';

// RF-45 se cumple aqui: la persona se entera de la medida que puso el administrador
// RF-46 se cumple aqui: la persona pide que el administrador revise otra vez una decision
class MedidasScreen extends StatefulWidget {
  const MedidasScreen({super.key});
  @override
  State<MedidasScreen> createState() => _MedidasScreenState();
}

class _MedidasScreenState extends State<MedidasScreen> {
  final _db = Supabase.instance.client;
  late Future<({List<Map<String, dynamic>> medidas, Map<String, Map<String, dynamic>> apelaciones})> _futuro = _cargar();
  Set<String> _ocultas = {};

  @override
  void initState() {
    super.initState();
    Ocultos.cargar('medidas').then((s) {
      if (mounted) setState(() => _ocultas = s);
    });
  }

  Future<void> _quitar(String id) async {
    setState(() => _ocultas.add(id));
    await Ocultos.agregar('medidas', [id]);
  }

  Future<({List<Map<String, dynamic>> medidas, Map<String, Map<String, dynamic>> apelaciones})> _cargar() async {
    final uid = _db.auth.currentUser!.id;
    final m = await _db
        .from('medidas_moderacion')
        .select()
        .eq('id_usuario_afectado', uid)
        .order('creada_en', ascending: false);
    final a = await _db.from('apelaciones').select().eq('id_usuario', uid)
        .not('id_medida', 'is', null).order('creada_en');
    return (
      medidas: List<Map<String, dynamic>>.from(m),
      apelaciones: {for (final x in a) x['id_medida'] as String: Map<String, dynamic>.from(x)},
    );
  }

  String _fecha(String iso) => DateTime.parse(iso).toLocal().toString().substring(0, 10);

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Avisos de moderación')),
        body: FutureBuilder(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const CargandoTg();
            if (s.hasError) {
              return EstadoVacio(
                icono: Icons.wifi_off_rounded,
                color: Tg.rojo,
                titulo: '¡Se cayó la señal!',
                mensaje: 'No se pudieron cargar las medidas.\n${s.error}',
              );
            }
            final d = s.data!;
            final medidas = d.medidas.where((m) {
              final activa = m['activa'] == true;
              final ap = d.apelaciones[m['id']];
              return (activa || ap != null) &&
                  (activa && ap == null || !_ocultas.contains(m['id']));
            }).toList();
            if (medidas.isEmpty) {
              return const EstadoVacio(
                icono: Icons.verified_user_rounded,
                color: Color(0xFF2EAD5B),
                titulo: '¡Cuenta limpia!',
                mensaje: 'No tienes medidas de moderación. Sigue así y respeta las reglas del tianguis.',
              );
            }
            final activas = medidas.where((m) => m['activa'] == true).length;
            return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
              CabeceraTg(
                titulo: 'Avisos de moderación',
                subtitulo: 'Desliza a la izquierda para quitar uno de la lista',
                icono: Icons.gavel_rounded,
                color: Tg.rosa,
                datos: [
                  DatoTg(Icons.warning_amber_rounded, Tg.naranja, '$activas', 'ACTIVAS'),
                  DatoTg(Icons.history, Tg.azulClaro, '${medidas.length - activas}', 'SIN EFECTO'),
                ],
              ),
              for (final m in medidas)
                Builder(builder: (_) {
                  final ap = d.apelaciones[m['id']];
                  final activa = m['activa'] == true;
                  return Dismissible(
                    key: ValueKey(m['id']),
                    direction: activa && ap == null
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    background: const FondoBorrar(),
                    onDismissed: (_) => _quitar(m['id'] as String),
                    child: TarjetaTg(
                      acento: activa ? Tg.naranja : Colors.grey,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text('${m['tipo_medida']}'.replaceAll('_', ' ').toUpperCase(),
                                style: Tg.marcador(16, color: Tg.amarillo)),
                          ),
                          PildoraTg(activa ? 'ACTIVA' : 'SIN EFECTO',
                              color: activa ? Tg.naranja : Colors.grey,
                              colorTexto: activa ? Tg.azulOscuro : Colors.white),
                        ]),
                        const SizedBox(height: 6),
                        Text('${m['motivo_general']}', style: const TextStyle(fontSize: 16, height: 1.2)),
                        const SizedBox(height: 4),
                        Text(_fecha(m['creada_en']),
                            style: const TextStyle(color: Tg.azulClaro, fontWeight: FontWeight.w800)),
                        if (ap != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                'Revisión: ${ap['resolucion'] ?? ap['estado']}${ap['comentario_resolucion'] != null ? ' · ${ap['comentario_resolucion']}' : ''}',
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(spacing: 4, children: [
                            if (activa && ap == null)
                              TextButton(
                                onPressed: () async {
                                  final ok = await solicitarRevision(context, idMedida: m['id'] as String);
                                  if (ok && mounted) setState(() => _futuro = _cargar());
                                },
                                child: const Text('Solicitar revisión'),
                              ),
                            TextButton(
                              onPressed: () => _quitar(m['id'] as String),
                              child: const Text('Quitar de la lista'),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  );
                }),
            ]);
          },
        ),
      );
}
