import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../services/chat_service.dart';
import '../widgets/moderacion.dart';
import '../widgets/entradas.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';

// rf-37 se cumple aqui: las dos personas del chat mandan y reciben mensajes
class ChatScreen extends StatefulWidget {
  final String idConversacion, titulo;
  // nombre y foto de la otra persona, si no vienen se buscan al abrir
  final String? nombre, fotoUrl;
  const ChatScreen({
    super.key,
    required this.idConversacion,
    required this.titulo,
    this.nombre,
    this.fotoUrl,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _svc = ChatService();
  final _txt = TextEditingController();
  final _yo = Supabase.instance.client.auth.currentUser!.id;

  String? _otro;
  bool _bloqueado = false;
  late String? _nombre = widget.nombre;
  late String? _foto = widget.fotoUrl;

  static const _rapidas = [
    '¿Todavía lo tienes?',
    '¿Cuál es lo menos?',
    '¿Dónde te pones?',
    '¿A qué hora llegas?',
  ];

  @override
  void initState() {
    super.initState();
    _cargarOtro();
  }

  Future<void> _cargarOtro() async {
    try {
      final id = await _svc.otroParticipante(widget.idConversacion);
      final b = id == null ? false : await _svc.estaBloqueado(id);
      if (id != null && _nombre == null) {
        final p = (await _svc.perfilesPublicos([id]))[id];
        if (p != null && p.nombre.isNotEmpty) {
          _nombre = p.nombre;
          _foto = p.foto;
        }
      }
      if (mounted) setState(() { _otro = id; _bloqueado = b; });
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

  // rf-44 se cumple aqui: se manda un reporte cuando algo rompe las reglas
  Future<void> _reportarMensaje(Map<String, dynamic> m) async {
    final id = m['id'];
    if (id == null) return;
    await reportarContenido(
      context,
      tipoObjetivo: TipoReporte.mensaje,
      idObjetivo: '$id',
      idUsuarioReportado: m['id_remitente'] as String?,
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
          content: Text(_bloqueado ? 'Usuario bloqueado' : 'Usuario desbloqueado')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo: $e')));
      }
    }
  }

  Future<void> _enviar() async {
    final t = _txt.text.trim();
    if (t.isEmpty) return;
    _txt.clear();
    try {
      await _svc.enviarMensaje(widget.idConversacion, t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se envió: $e')));
      }
    }
  }

  DateTime? _hora(Map<String, dynamic> m) => DateTime.tryParse('${m['enviado_en'] ?? ''}')?.toLocal();

  bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _etiquetaDia(DateTime f) {
    final hoy = DateTime.now();
    if (_mismoDia(f, hoy)) return 'HOY';
    if (_mismoDia(f, hoy.subtract(const Duration(days: 1)))) return 'AYER';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year}';
  }

  Widget _chipDia(DateTime f) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: EtiquetaPincel(texto: _etiquetaDia(f), color: Tg.rosa, colorTexto: Colors.white, angulo: -0.03)),
      );

  Widget _burbuja(Map<String, dynamic> m, bool mio) {
    final h = _hora(m);
    String dos(int n) => n.toString().padLeft(2, '0');
    final colorTexto = mio ? Tg.azulOscuro : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 6),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
      decoration: BoxDecoration(
        color: mio ? Tg.amarillo : Tg.azulOscuro,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mio ? 18 : 4),
          bottomRight: Radius.circular(mio ? 4 : 18),
        ),
        border: mio ? null : Border.all(color: Tg.azulClaro.withValues(alpha: 0.5), width: 1.4),
        boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(2, 3), blurRadius: 0)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${m['contenido']}',
            style: TextStyle(color: colorTexto, fontSize: 16.5, height: 1.15, fontWeight: FontWeight.w600)),
        if (h != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${dos(h.hour)}:${dos(h.minute)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mio ? Tg.azulOscuro.withValues(alpha: 0.6) : Colors.white54)),
            ),
          ),
      ]),
    );
  }

  // chat sin mensajes: invita a escribir con frases de tianguis
  Widget _vacio() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SelloTg(icono: Icons.waving_hand_rounded, color: Tg.amarillo, tam: 76),
            const SizedBox(height: 14),
            Text('¡Rómpele el hielo!', style: Tg.marcador(24)),
            const SizedBox(height: 6),
            const Text('Escribe el primer mensaje o toca una de estas:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final r in _rapidas)
                ActionChip(
                  label: Text(r, style: const TextStyle(fontWeight: FontWeight.w800)),
                  backgroundColor: Tg.azulOscuro,
                  side: BorderSide(color: Tg.azulClaro.withValues(alpha: 0.6), width: 1.5),
                  shape: const StadiumBorder(),
                  onPressed: () => setState(() {
                    _txt.text = r;
                    _txt.selection = TextSelection.collapsed(offset: r.length);
                  }),
                ),
            ]),
          ]),
        ),
      );

  Widget _barraEscribir() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Tg.azulOscuro.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: Colors.white24, width: 1.5)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _txt,
                inputFormatters: Entradas.texto(1000),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.black, fontSize: 16),
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(hintText: 'Escribe un mensaje…'),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Tg.amarillo,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _enviar,
                child: const Padding(
                  padding: EdgeInsets.all(13),
                  child: Icon(Icons.send_rounded, color: Tg.azulOscuro, size: 24),
                ),
              ),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(
          titleSpacing: 0,
          centerTitle: false,
          title: Row(children: [
            AvatarTg(nombre: _nombre ?? widget.titulo, fotoUrl: _foto, radio: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nombre ?? widget.titulo,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Tg.marcador(18)),
                if (_nombre != null)
                  Text(widget.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: Tg.azulClaro, height: 1)),
              ]),
            ),
          ]),
          actions: [
            if (_otro != null)
              PopupMenuButton<String>(
                onSelected: (v) => v == 'reportar' ? _reportar() : _alternarBloqueo(),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'reportar', child: Text('Reportar')),
                  PopupMenuItem(
                      value: 'bloquear',
                      child: Text(_bloqueado ? 'Desbloquear usuario' : 'Bloquear usuario')),
                ],
              ),
          ],
        ),
        body: Column(children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _svc.mensajes(widget.idConversacion),
              builder: (_, s) {
                if (s.hasError) {
                  return EstadoVacio(
                    icono: Icons.wifi_off_rounded,
                    color: Tg.rojo,
                    titulo: '¡Se cayó la señal!',
                    mensaje: 'No se pudieron cargar los mensajes.\n${s.error}',
                  );
                }
                if (!s.hasData) return const CargandoTg();
                final l = s.data!;
                if (l.isEmpty) return _vacio();
                return ListView.builder(
                  reverse: true, // el mensaje mas nuevo queda abajo
                  padding: const EdgeInsets.all(12),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final m = l[i];
                    final mio = m['id_remitente'] == _yo;
                    final h = _hora(m);
                    final anterior = i + 1 < l.length ? _hora(l[i + 1]) : null;
                    // la etiqueta del dia va arriba del primer mensaje de cada dia
                    final etiquetaDia = h != null && (anterior == null || !_mismoDia(h, anterior));
                    final burbuja = _burbuja(m, mio);
                    return Column(children: [
                      if (etiquetaDia) _chipDia(h!),
                      Align(
                        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
                        child: mio
                            ? burbuja
                            : GestureDetector(
                                onLongPress: () => _reportarMensaje(m),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Flexible(child: burbuja),
                                  IconButton(
                                    tooltip: 'Reportar mensaje',
                                    visualDensity: VisualDensity.compact,
                                    iconSize: 18,
                                    color: Colors.white38,
                                    icon: const Icon(Icons.flag_outlined),
                                    onPressed: () => _reportarMensaje(m),
                                  ),
                                ]),
                              ),
                      ),
                    ]);
                  },
                );
              },
            ),
          ),
          if (_bloqueado)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                color: Tg.azulOscuro,
                child: const Text('Bloqueaste a este usuario. Desbloquéalo para enviar mensajes.',
                    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            )
          else
            _barraEscribir(),
        ]),
      );
}
