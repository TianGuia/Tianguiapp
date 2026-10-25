import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/inicio_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _svc = InicioService();
  late final Future<List<Map<String, dynamic>>> _futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() async {
    final l = await _svc.notificaciones();
    // Se marcan como leídas al abrir la pantalla; la lista ya se trajo con su estado original.
    _svc.marcarLeidas().catchError((_) {});
    return l;
  }

  String _fecha(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}  ${dos(d.hour)}:${dos(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
          }
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          final l = s.data!;
          if (l.isEmpty) {
            return const Center(child: Text('No tienes notificaciones por ahora'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: l.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = l[i];
              final nueva = n['leida'] == false;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: nueva ? Tg.amarillo : Colors.white12,
                    child: Icon(Icons.notifications,
                        color: nueva ? Tg.azulOscuro : Colors.white70),
                  ),
                  title: Text(n['titulo'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text([n['cuerpo'], _fecha(n['creada_en'])]
                      .where((e) => e != null && '$e'.isNotEmpty)
                      .join('\n')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
