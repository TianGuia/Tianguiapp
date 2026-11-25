import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/cerrar_sesion.dart';
import '../widgets/urbano.dart';
import 'chats_screen.dart';
import 'diagnostico_screen.dart';
import 'editar_perfil_screen.dart';
import 'favoritos_screen.dart';
import 'medidas_screen.dart';
import 'notificaciones_screen.dart';
import 'preferencias_notificacion_screen.dart';
import 'reportar_falla_screen.dart';
import 'tratos_screen.dart';
import 'tutorial_screen.dart';
import 'verificar_contacto_screen.dart';

// rf-36 se cumple aqui: la persona puede ver y cambiar su nombre y su foto
class PerfilTab extends StatefulWidget {
  const PerfilTab({super.key});
  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  final _auth = AuthService();
  late Future<Map<String, dynamic>?> _perfil = _auth.miPerfil();

  void _refrescar() {
    if (mounted) {
      setState(() {
        _perfil = _auth.miPerfil();
      });
    }
  }

  Future<void> _verificar() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VerificarContactoScreen()),
    );
    if (ok == true) _refrescar();
  }

  Future<void> _editar() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditarPerfilScreen()),
    );
    if (ok == true) _refrescar();
  }

  void _ir(Widget pantalla) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));

  // tarjeta grande con foto, nombre y correo
  Widget _hero(Map<String, dynamic>? p) {
    final foto = p?['foto_url'] as String?;
    final correo = p?['correo'] as String?;
    final nombre = (p?['nombre_publico'] as String?) ?? '…';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123BB5), Tg.azulOscuro],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.55), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(3, 4), blurRadius: 0)],
      ),
      child: Column(children: [
        Stack(children: [
          // franja de color detras de la foto
          Positioned(left: -30, top: 10, child: Transform.rotate(angle: -0.25, child: Container(width: 190, height: 26, color: Tg.amarillo))),
          Positioned(right: -40, top: 52, child: Transform.rotate(angle: -0.25, child: Container(width: 190, height: 16, color: Tg.rosa))),
          Positioned(right: -20, top: 90, child: Transform.rotate(angle: -0.25, child: Container(width: 120, height: 10, color: Tg.verde))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Tg.amarillo,
                  border: Border.all(color: Tg.azulOscuro, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(2, 3), blurRadius: 0)],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Tg.azulOscuro,
                  backgroundImage: foto == null ? null : NetworkImage(foto),
                  child: foto == null
                      ? Text(
                          nombre.trim().isEmpty ? '?' : String.fromCharCode(nombre.trim().runes.first).toUpperCase(),
                          style: Tg.marcador(46, color: Tg.amarillo))
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(nombre, textAlign: TextAlign.center, style: Tg.marcador(28)),
              const SizedBox(height: 6),
              if (_auth.esAnonimo)
                const PildoraTg('SIN CORREO VERIFICADO',
                    color: Tg.naranja, icono: Icons.warning_amber_rounded)
              else if ((correo ?? '').isNotEmpty)
                PildoraTg(correo!, color: Colors.white, icono: Icons.verified, colorTexto: Tg.azulOscuro),
              const SizedBox(height: 14),
              Material(
                color: Tg.amarillo,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: _editar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit, size: 18, color: Tg.azulOscuro),
                      const SizedBox(width: 8),
                      Text('EDITAR PERFIL', style: Tg.marcador(15, color: Tg.azulOscuro)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
        const CintaTricolor(alto: 6),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _perfil,
      builder: (_, s) {
        final p = s.data;
        return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          _hero(p),
          if (_auth.esAnonimo) ...[
            const SeccionTg('Pendiente'),
            OpcionTg(
              icono: Icons.verified_user_outlined,
              color: Tg.naranja,
              titulo: 'Verificar mi correo',
              subtitulo: 'Necesario para vender y para no perder tus favoritos y mensajes si borras la app.',
              onTap: _verificar,
            ),
          ],
          const SeccionTg('Mi actividad'),
          RejillaMosaicos(hijos: [
            MosaicoTg(
              icono: Icons.chat_bubble_rounded,
              color: Tg.amarillo,
              titulo: 'Mis mensajes',
              angulo: -0.012,
              onTap: () => _ir(const ChatsScreen()),
            ),
            MosaicoTg(
              icono: Icons.favorite_rounded,
              color: Tg.rosa,
              colorTexto: Colors.white,
              titulo: 'Mis favoritos',
              angulo: 0.012,
              onTap: () => _ir(const FavoritosScreen()),
            ),
            MosaicoTg(
              icono: Icons.handshake_rounded,
              color: Tg.azulClaro,
              titulo: 'Propuestas y apartados',
              angulo: 0.012,
              onTap: () => _ir(const TratosScreen()),
            ),
            MosaicoTg(
              icono: Icons.notifications_rounded,
              color: Tg.naranja,
              titulo: 'Notificaciones',
              angulo: -0.012,
              onTap: () => _ir(const NotificacionesScreen()),
            ),
          ]),
          const SeccionTg('Ajustes y avisos'),
          OpcionTg(
            icono: Icons.tune,
            color: Tg.azulClaro,
            titulo: 'Preferencias de notificación',
            subtitulo: 'Recordatorios, silencios y categorías',
            onTap: () => _ir(const PreferenciasNotificacionScreen()),
          ),
          OpcionTg(
            icono: Icons.gavel,
            color: Tg.rosa,
            titulo: 'Avisos de moderación',
            subtitulo: 'Medidas y revisiones de tu cuenta',
            onTap: () => _ir(const MedidasScreen()),
          ),
          OpcionTg(
            icono: Icons.lightbulb_rounded,
            color: Tg.verde,
            titulo: 'Cómo funciona',
            subtitulo: 'Un recorrido corto por la app',
            onTap: () => _ir(const TutorialScreen()),
          ),
          OpcionTg(
            icono: Icons.report_problem_rounded,
            color: Tg.amarillo,
            titulo: 'Reportar una falla',
            subtitulo: 'Algo no funciona o tienes una idea',
            onTap: () => _ir(const ReportarFallaScreen()),
          ),
          OpcionTg(
            icono: Icons.bug_report_outlined,
            color: const Color(0xFF2EAD5B),
            titulo: 'Diagnóstico de conexión',
            subtitulo: 'Revisa si la app llega al servidor',
            onTap: () => _ir(const DiagnosticoScreen()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Tg.rojo, foregroundColor: Colors.white),
              onPressed: () => confirmarCerrarSesion(context),
              icon: const Icon(Icons.logout),
              label: const Text('CERRAR SESIÓN'),
            ),
          ),
        ]);
      },
    );
  }
}
