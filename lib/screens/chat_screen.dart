import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../services/chat_service.dart';

/// RF-37: mensajes en tiempo real entre los dos participantes.
class ChatScreen extends StatefulWidget {
  final String idConversacion, titulo;
  const ChatScreen({super.key, required this.idConversacion, required this.titulo});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _svc = ChatService();
  final _txt = TextEditingController();
  final _yo = Supabase.instance.client.auth.currentUser!.id;

  Future<void> _enviar() async {
    final t = _txt.text.trim();
    if (t.isEmpty) return;
    _txt.clear();
    try {
      await _svc.enviar(widget.idConversacion, t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se envió: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _svc.mensajes(widget.idConversacion),
              builder: (_, s) {
                if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final l = s.data!;
                if (l.isEmpty) return const Center(child: Text('Escribe el primer mensaje'));
                return ListView.builder(
                  reverse: true, // el mensaje más nuevo queda abajo
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final m = l[i];
                    final mio = m['id_remitente'] == _yo;
                    return Align(
                      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mio ? Tg.amarillo : Tg.azulOscuro,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m['contenido'],
                            style: TextStyle(color: mio ? Tg.azulOscuro : Colors.white)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _txt,
                    style: const TextStyle(color: Colors.black),
                    onSubmitted: (_) => _enviar(),
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje…'),
                  ),
                ),
                IconButton(onPressed: _enviar, icon: const Icon(Icons.send, color: Tg.amarillo)),
              ]),
            ),
          ),
        ]),
      );
}
