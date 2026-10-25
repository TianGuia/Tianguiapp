import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis mensajes')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: ChatService().misConversaciones(),
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) return const Center(child: Text('Aún no tienes conversaciones'));
            return ListView.builder(
              itemCount: l.length,
              itemBuilder: (_, i) {
                final c = l[i];
                final nombre = (c['productos'] as Map?)?['nombre'] ?? 'Conversación';
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text('$nombre'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(idConversacion: c['id'], titulo: '$nombre'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
