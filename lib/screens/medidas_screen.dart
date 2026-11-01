import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../services/ocultos.dart';
import '../widgets/moderacion.dart';

/// RF-45 y RF-46: medidas de moderación aplicadas a mi cuenta o contenido,
/// con su motivo general, y solicitud de revisión (apelación).
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
        .eq('activa', true) // al levantarla el administrador, deja de aparecerle al usuario
        .order('creada_en', ascending: false);
    final a = await _db.from('apelaciones').select().eq('id_usuario', uid).not('id_medida', 'is', null);
    return (
      medidas: List<Map<String, dynamic>>.from(m),
      apelaciones: {for (final x in a) x['id_medida'] as String: Map<String, dynamic>.from(x)},
    );
  }

  String _fecha(String iso) => DateTime.parse(iso).toLocal().toString().substring(0, 10);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Avisos de moderación')),
        body: FutureBuilder(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final d = s.data!;
            final medidas = d.medidas.where((m) => !_ocultas.contains(m['id'])).toList();
            if (medidas.isEmpty) return const Center(child: Text('No tienes medidas de moderación'));
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final m in medidas)
                Builder(builder: (_) {
                  final ap = d.apelaciones[m['id']];
                  return Dismissible(
                    key: ValueKey(m['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(color: Tg.rojo, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _quitar(m['id'] as String),
                    child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${m['tipo_medida']}'.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Tg.amarillo)),
                        const SizedBox(height: 4),
                        Text('${m['motivo_general']}'),
                        const SizedBox(height: 4),
                        Text('${_fecha(m['creada_en'])}${m['activa'] == true ? ' · activa' : ' · sin efecto'}',
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        if (ap != null)
                          Text('Revisión: ${ap['estado']}${ap['comentario_resolucion'] != null ? ' · ${ap['comentario_resolucion']}' : ''}'),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(spacing: 4, children: [
                            if (ap == null)
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
                    ),
                  );
                }),
            ]);
          },
        ),
      );
}
