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
  List<Map<String, dynamic>>? _lista;

  Future<List<Map<String, dynamic>>> _cargar() async {
    final l = await _svc.notificaciones();
    // Se marcan como leídas al abrir la pantalla; la lista ya se trajo con su estado original.
    _svc.marcarLeidas().catchError((_) {});
    _lista = List<Map<String, dynamic>>.of(l);
    return l;
  }

  String _fecha(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}  ${dos(d.hour)}:${dos(d.minute)}';
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _borrar(Map<String, dynamic> n) async {
    setState(() => _lista!.remove(n));
    try {
      await _svc.borrarNotificacion(n['id'] as String);
    } catch (_) {
      if (!mounted) return;
      setState(() => _lista!.add(n)); // no se pudo: vuelve a la lista
      _msg('No se pudo borrar la notificación');
    }
  }

  Future<void> _borrarTodas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todas?'),
        content: const Text('Se borrarán todas tus notificaciones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.borrarNotificaciones();
      if (mounted) setState(() => _lista!.clear());
    } catch (_) {
      if (mounted) _msg('No se pudieron borrar las notificaciones');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (_lista != null && _lista!.isNotEmpty)
            IconButton(
              tooltip: 'Borrar todas',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _borrarTodas,
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futuro,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
          }
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          final l = _lista ?? s.data!;
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
              return Dismissible(
                key: ValueKey(n['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: Tg.rojo, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _borrar(n),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: nueva ? Tg.amarillo : Colors.white12,
                      child: Icon(Icons.notifications, color: nueva ? Tg.azulOscuro : Colors.white70),
                    ),
                    title: Text(n['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([n['cuerpo'], _fecha(n['creada_en'])]
                        .where((e) => e != null && '$e'.isNotEmpty)
                        .join('\n')),
                    trailing: IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                      onPressed: () => _borrar(n),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
