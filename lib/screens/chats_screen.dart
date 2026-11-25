import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _svc = ChatService();
  late Future<List<Map<String, dynamic>>> _futuro = _svc.misConversaciones();

  void _recargar() {
    setState(() {
      _futuro = _svc.misConversaciones();
    });
  }

  Future<void> _borrar(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Borrar conversación?'),
        content: Text('Se quitará "$nombre" de tu lista. La otra persona seguirá viéndola.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('BORRAR')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.borrarConversacion(id);
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis mensajes')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('No se pudieron cargar los chats: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) return const Center(child: Text('Aún no tienes conversaciones'));
            return ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) {
                final c = l[i];
                final nombre = ChatService.tituloDe(c);
                final asunto = ChatService.asuntoDe(c);
                final ultimo = c['ultimo_texto'] as String?;
                final noLeidos = (c['no_leidos'] as num?)?.toInt() ?? 0;
                final sub = [if (asunto != null) asunto, if (ultimo != null) ultimo].join(' · ');
                return ListTile(
                  leading: Badge(
                    isLabelVisible: noLeidos > 0,
                    label: Text('$noLeidos'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  title: Text(nombre,
                      style: TextStyle(fontWeight: noLeidos > 0 ? FontWeight.w800 : FontWeight.w600)),
                  subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Borrar conversación',
                    onPressed: () => _borrar(c['id'] as String, nombre),
                  ),
                  onLongPress: () => _borrar(c['id'] as String, nombre),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(idConversacion: c['id'], titulo: nombre),
                      ),
                    );
                    if (mounted) _recargar();
                  },
                );
              },
            );
          },
        ),
      );
}
