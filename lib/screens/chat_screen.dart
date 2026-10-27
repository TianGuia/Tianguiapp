import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../services/chat_service.dart';
import '../models/mensajeria.dart';
import '../widgets/moderacion.dart';

/// RF-37: mensajes en tiempo real entre los participantes.
class ChatScreen extends StatefulWidget {
  final String idConversacion, titulo;
  const ChatScreen(
      {super.key, required this.idConversacion, required this.titulo});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _svc = ChatService();
  final _txt = TextEditingController();
  final _yo = Supabase.instance.client.auth.currentUser!.id;

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  String? _otro;
  bool _bloqueado = false;

  @override
  void initState() {
    super.initState();
    _cargarOtro();
  }

  Future<void> _cargarOtro() async {
    try {
      final id = await _svc.otroParticipante(widget.idConversacion);
      final b = id == null ? false : await _svc.estaBloqueado(id);
      if (mounted) {
        setState(() {
          _otro = id;
          _bloqueado = b;
        });
      }
    } catch (_) {/* el menú simplemente no aparece */}
  }

  Future<void> _reportar() async {
    final otro = _otro;
    if (otro == null) return;
    await reportarContenido(
      context,
      tipoObjetivo: TipoReporte.perfil,
      idObjetivo: otro,
      idUsuarioReportado: otro,
    );
  }

  Future<void> _alternarBloqueo() async {
    final otro = _otro;
    if (otro == null) return;
    try {
      if (_bloqueado) {
        await _svc.desbloquear(otro);
      } else {
        final ok = await confirmarBloqueo(context, widget.titulo);
        if (ok != true) return;
        await _svc.bloquear(otro);
      }
      if (!mounted) return;
      setState(() => _bloqueado = !_bloqueado);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_bloqueado ? 'Usuario bloqueado' : 'Usuario desbloqueado')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
  }

  Future<void> _enviar() async {
    final t = _txt.text.trim();
    if (t.isEmpty) return;
    try {
      await _svc.enviar(widget.idConversacion, t);
      if (_txt.text.trim() == t) _txt.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se envió: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.titulo),
          actions: [
            if (_otro != null)
              PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'reportar' ? _reportar() : _alternarBloqueo(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'reportar', child: Text('Reportar')),
                  PopupMenuItem(
                      value: 'bloquear',
                      child: Text(_bloqueado
                          ? 'Desbloquear usuario'
                          : 'Bloquear usuario')),
                ],
              ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<List<Mensaje>>(
              stream: _svc.mensajes(widget.idConversacion),
              builder: (_, s) {
                if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final l = s.data!;
                if (l.isEmpty) {
                  return const Center(child: Text('Escribe el primer mensaje'));
                }
                return ListView.builder(
                  reverse: true, // el mensaje más nuevo queda abajo
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final m = l[i];
                    final mio = m.idRemitente == _yo;
                    return Align(
                      alignment:
                          mio ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: mio ? Tg.amarillo : Tg.azulOscuro,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!mio)
                                const Text('Participante',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 10)),
                              Text(m.contenido,
                                  style: TextStyle(
                                      color:
                                          mio ? Tg.azulOscuro : Colors.white)),
                            ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_bloqueado)
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Bloqueaste a este usuario. Desbloquéalo para enviar mensajes.',
                    textAlign: TextAlign.center),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _txt,
                      style: const TextStyle(color: Colors.black),
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje…'),
                    ),
                  ),
                  IconButton(
                      onPressed: _enviar,
                      icon: const Icon(Icons.send, color: Tg.amarillo)),
                ]),
              ),
            ),
        ]),
      );
}
