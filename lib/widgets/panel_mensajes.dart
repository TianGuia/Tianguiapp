import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../screens/chat_screen.dart';
import '../screens/chats_screen.dart';
import '../services/chat_service.dart';

// panel chico del inicio con los ultimos mensajes; solo aparece si ya hay conversaciones
// se actualiza solo cuando llega un mensaje nuevo y al volver de un chat
class PanelMensajes extends StatefulWidget {
  const PanelMensajes({super.key});
  @override
  State<PanelMensajes> createState() => PanelMensajesState();
}

class PanelMensajesState extends State<PanelMensajes> {
  final _svc = ChatService();
  final _db = Supabase.instance.client;
  RealtimeChannel? _canal;
  Timer? _espera;
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    recargar();
    // un mensaje nuevo (o uno que se marca leido) vuelve a pedir la lista
    try {
      _canal = _db
          .channel('panel_mensajes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'mensajes',
            callback: (_) => _recargarPronto(),
          )
          .subscribe();
    } catch (_) {} // sin tiempo real se actualiza al volver de un chat o al jalar el inicio
  }

  @override
  void dispose() {
    _espera?.cancel();
    final c = _canal;
    if (c != null) _db.removeChannel(c);
    super.dispose();
  }

  // junta varios avisos seguidos en una sola consulta
  void _recargarPronto() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 600), recargar);
  }

  Future<void> recargar() async {
    try {
      final l = await _svc.misConversaciones();
      if (mounted) setState(() => _chats = l);
    } catch (_) {} // si falla se queda lo que ya se veia
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) recargar();
  }

  @override
  Widget build(BuildContext context) {
    // primero los que tienen mensajes sin leer, luego los mas recientes (la lista ya viene por fecha)
    final todos = _chats.where((c) => c['ultimo_texto'] != null).toList();
    bool sinLeer(Map<String, dynamic> c) => ((c['no_leidos'] as num?) ?? 0) > 0;
    final conMensajes = [...todos.where(sinLeer), ...todos.where((c) => !sinLeer(c))];
    if (conMensajes.isEmpty) return const SizedBox.shrink();
    final nuevos = conMensajes.fold<int>(0, (t, c) => t + ((c['no_leidos'] as num?)?.toInt() ?? 0));
    final lista = conMensajes.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Tg.azulOscuro,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: nuevos > 0 ? Tg.amarillo : Colors.white24, width: nuevos > 0 ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(nuevos > 0 ? 'Mensajes · $nuevos nuevos' : 'Mensajes',
                    style: Tg.marcador(16, color: nuevos > 0 ? Tg.amarillo : Colors.white)),
              ),
              TextButton(onPressed: () => _abrir(const ChatsScreen()), child: const Text('VER TODOS')),
            ]),
          ),
          for (final c in lista) _fila(c),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }

  Widget _fila(Map<String, dynamic> c) {
    final nombre = ChatService.tituloDe(c);
    final asunto = ChatService.asuntoDe(c);
    final noLeidos = (c['no_leidos'] as num?)?.toInt() ?? 0;
    final texto = '${c['ultimo_texto']}';
    return ListTile(
      dense: true,
      onTap: () => _abrir(ChatScreen(idConversacion: c['id'] as String, titulo: nombre)),
      title: Text(nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: noLeidos > 0 ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text(asunto == null ? texto : '$asunto · $texto',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: noLeidos > 0
          ? Badge(backgroundColor: Tg.rosa, label: Text('$noLeidos'))
          : const Icon(Icons.chevron_right, size: 20),
    );
  }
}
