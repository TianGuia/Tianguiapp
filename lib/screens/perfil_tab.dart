import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../models/identidad.dart';
import '../widgets/cerrar_sesion.dart';
import 'chats_screen.dart';
import 'diagnostico_screen.dart';
import 'editar_perfil_screen.dart';
import 'favoritos_screen.dart';
import 'medidas_screen.dart';
import 'preferencias_notificacion_screen.dart';
import 'tratos_screen.dart';
import 'verificar_contacto_screen.dart';

/// RF-05: perfil de la cuenta.
class PerfilTab extends StatefulWidget {
  const PerfilTab({super.key});
  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  final _auth = AuthService();

  Future<void> _verificar() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VerificarContactoScreen()),
    );
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _editar() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditarPerfilScreen()),
    );
    if (ok == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    return FutureBuilder<Usuario?>(
      future: auth.miPerfil(),
      builder: (_, s) {
        final p = s.data;
        final foto = p?.fotoPerfil;
        final correo = p?.correo;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Tg.amarillo),
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Tg.azulOscuro,
                backgroundImage: foto == null ? null : NetworkImage(foto),
                child: foto == null ? const Icon(Icons.person, size: 48) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(p?.nombre ?? '…',
              textAlign: TextAlign.center, style: Tg.marcador(26)),
          Text(auth.esAnonimo ? 'Cuenta sin correo verificado' : (correo ?? ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_outlined, color: Tg.amarillo),
              title: const Text('Editar perfil',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Nombre público y fotografía'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editar,
            ),
          ),
          const SizedBox(height: 10),
          if (auth.esAnonimo) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined,
                    color: Tg.amarillo),
                title: const Text('Verificar mi correo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Necesario para vender y para no perder tus favoritos y mensajes si borras la app.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _verificar,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.chat_bubble_outline, color: Tg.amarillo),
              title: const Text('Mis mensajes',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChatsScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite_border, color: Tg.amarillo),
              title: const Text('Mis favoritos',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FavoritosScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined, color: Tg.amarillo),
              title: const Text('Mis propuestas y apartados',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TratosScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune, color: Tg.amarillo),
              title: const Text('Preferencias de notificación',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PreferenciasNotificacionScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.gavel, color: Tg.amarillo),
              title: const Text('Avisos de moderación',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MedidasScreen())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading:
                  const Icon(Icons.bug_report_outlined, color: Tg.amarillo),
              title: const Text('Diagnóstico de conexión',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DiagnosticoScreen())),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
              onPressed: () => confirmarCerrarSesion(context),
              child: const Text('CERRAR SESIÓN')),
        ]);
      },
    );
  }
}
