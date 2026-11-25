import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../services/inicio_service.dart';
import '../widgets/mensaje.dart';

// rf-07 se cumple a medias, aqui se muestran los avisos de ofertas pero la app no los crea, eso le toca al backend
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
    // se marcan como leidas al abrir la pantalla; la lista ya se trajo con su estado original.
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

  void _msg(String t) => mostrarMensaje(context, t);

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
    return ScaffoldTg(
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
          if (s.connectionState != ConnectionState.done) return const CargandoTg();
          if (s.hasError) {
            return EstadoVacio(
              icono: Icons.wifi_off_rounded,
              color: Tg.rojo,
              titulo: '¡Se cayó la señal!',
              mensaje: 'No se pudieron cargar los avisos.\n${s.error}',
            );
          }
          final l = _lista ?? s.data!;
          if (l.isEmpty) {
            return const EstadoVacio(
              icono: Icons.notifications_active_rounded,
              color: Tg.naranja,
              titulo: '¡Todo tranquilo!',
              mensaje: 'Aquí te avisamos de ofertas, apartados, propuestas y cuando abra un puesto que sigues.',
            );
          }
          final nuevas = l.where((n) => n['leida'] == false).length;
          return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
            CabeceraTg(
              titulo: 'Tus avisos',
              subtitulo: 'Desliza a la izquierda para borrar uno',
              icono: Icons.notifications_rounded,
              color: Tg.naranja,
              datos: [
                DatoTg(Icons.mark_email_unread, Tg.amarillo, '$nuevas', 'NUEVOS'),
                DatoTg(Icons.notifications, Tg.azulClaro, '${l.length}', 'EN TOTAL'),
              ],
            ),
            for (final n in l) _tarjeta(n),
          ]);
        },
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> n) {
    final nueva = n['leida'] == false;
    return Dismissible(
      key: ValueKey(n['id']),
      direction: DismissDirection.endToStart,
      background: const FondoBorrar(),
      onDismissed: (_) => _borrar(n),
      child: TarjetaTg(
        acento: nueva ? Tg.amarillo : Colors.white24,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelloTg(
            icono: nueva ? Icons.notifications_active : Icons.notifications_none,
            color: nueva ? Tg.amarillo : Colors.white24,
            colorIcono: nueva ? Tg.azulOscuro : Colors.white70,
            tam: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n['titulo'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.1)),
              if ((n['cuerpo'] ?? '') != '')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${n['cuerpo']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.15)),
                ),
              const SizedBox(height: 4),
              Text(_fecha(n['creada_en']),
                  style: const TextStyle(color: Tg.azulClaro, fontWeight: FontWeight.w800, fontSize: 12.5)),
            ]),
          ),
          IconButton(
            tooltip: 'Borrar',
            icon: const Icon(Icons.close, size: 20, color: Colors.white54),
            onPressed: () => _borrar(n),
          ),
        ]),
      ),
    );
  }
}
