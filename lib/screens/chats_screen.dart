import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/mensajeria.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  final ChatService? service;
  const ChatsScreen({super.key, this.service});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final _svc = widget.service ?? ChatService();
  late Future<List<Conversacion>> _futuro = _svc.misConversaciones();

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
        content: Text(
            'Se quitará "$nombre" de tu lista. La otra persona seguirá viéndola.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('BORRAR')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.borrarConversacion(id);
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo borrar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis mensajes')),
        body: FutureBuilder<List<Conversacion>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) {
              return const Center(child: Text('Aún no tienes conversaciones'));
            }
            return ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) {
                final c = l[i];
                final nombre = c.productoNombre ?? 'Conversación';
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(nombre),
                  subtitle: Text(
                      '${c.participantes.length} participantes · ${c.estado}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Borrar conversación',
                    onPressed: () => _borrar(c.idConversacion, nombre),
                  ),
                  onLongPress: () => _borrar(c.idConversacion, nombre),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                            idConversacion: c.idConversacion, titulo: nombre),
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
