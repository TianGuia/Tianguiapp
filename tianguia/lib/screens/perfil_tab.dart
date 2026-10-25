import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import 'chats_screen.dart';
import 'diagnostico_screen.dart';
import 'tratos_screen.dart';

/// RF-05: perfil de la cuenta.
class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return FutureBuilder<Map<String, dynamic>?>(
      future: auth.miPerfil(),
      builder: (_, s) {
        final p = s.data;
        final foto = p?['foto_url'] as String?;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Tg.amarillo),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Tg.azulOscuro,
                backgroundImage: foto == null ? null : NetworkImage(foto),
                child: foto == null ? const Icon(Icons.person, size: 48) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(p?['nombre_publico'] ?? '…',
              textAlign: TextAlign.center, style: Tg.marcador(26)),
          Text(p?['correo'] ?? '', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Tg.amarillo),
              title: const Text('Mis mensajes', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const ChatsScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined, color: Tg.amarillo),
              title: const Text('Mis propuestas y apartados',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const TratosScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined, color: Tg.amarillo),
              title: const Text('Diagnóstico de conexión',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const DiagnosticoScreen())),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: auth.cerrarSesion, child: const Text('CERRAR SESIÓN')),
        ]);
      },
    );
  }
}
