import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../services/chat_service.dart';
import '../widgets/urbano.dart';
import 'chat_screen.dart';

class _Datos {
  final List<Map<String, dynamic>> lista;
  final Map<String, ({String nombre, String? foto})> perfiles;
  final Map<String, Map<String, dynamic>> ultimos;
  const _Datos(this.lista, this.perfiles, this.ultimos);
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _svc = ChatService();
  final _yo = Supabase.instance.client.auth.currentUser!.id;
  late Future<_Datos> _futuro = _cargar();

  String? _otroId(Map<String, dynamic> c) =>
      (c['id_iniciador'] == _yo ? c['id_receptor'] : c['id_iniciador']) as String?;

  Future<_Datos> _cargar() async {
    final lista = await _svc.misConversaciones();
    final perfiles = await _svc.perfilesPublicos([
      for (final c in lista)
        if (_otroId(c) != null) _otroId(c)!
    ]);
    final ultimos = await _svc.ultimosMensajes([for (final c in lista) c['id'] as String]);
    return _Datos(lista, perfiles, ultimos);
  }

  void _recargar() {
    setState(() {
      _futuro = _cargar();
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

  Widget _tarjeta(Map<String, dynamic> c, _Datos d) {
    final id = c['id'] as String;
    final otroId = _otroId(c);
    final perfil = otroId == null ? null : d.perfiles[otroId];
    final nombre = (perfil?.nombre ?? '').isNotEmpty ? perfil!.nombre : 'Persona del tianguis';
    final producto = (c['productos'] as Map?)?['nombre'];
    final anuncio = (c['anuncios_espacio'] as Map?)?['titulo'];
    final asunto = '${producto ?? anuncio ?? 'Conversación'}';
    final esEspacio = producto == null && anuncio != null;
    final u = d.ultimos[id];
    final texto = u == null
        ? 'Aún no hay mensajes, ¡rómpele el hielo!'
        : '${u['id_remitente'] == _yo ? 'Tú: ' : ''}${u['contenido']}';
    final fecha = DateTime.tryParse('${u?['enviado_en'] ?? c['ultimo_mensaje_en'] ?? ''}')?.toLocal();
    final color = esEspacio ? Tg.verde : Tg.amarillo;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: const FondoBorrar(),
      // la tarjeta no se quita sola, primero se pregunta y luego se recarga la lista
      confirmDismiss: (_) async {
        await _borrar(id, asunto);
        return false;
      },
      child: TarjetaTg(
        acento: color,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                idConversacion: id,
                titulo: asunto,
                nombre: perfil?.nombre.isNotEmpty == true ? perfil!.nombre : null,
                fotoUrl: perfil?.foto,
              ),
            ),
          );
          if (mounted) _recargar();
        },
        onLongPress: () => _borrar(id, asunto),
        child: Row(children: [
          AvatarTg(nombre: nombre, fotoUrl: perfil?.foto, radio: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                ),
                const SizedBox(width: 8),
                Text(fechaRelativa(fecha),
                    style: GoogleFonts.baloo2(
                        color: Tg.amarillo, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(esEspacio ? Icons.crop_free : Icons.sell, size: 14, color: Tg.azulClaro),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(asunto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Tg.azulClaro, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Mis mensajes')),
        body: FutureBuilder<_Datos>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const CargandoTg();
            if (s.hasError) {
              return EstadoVacio(
                icono: Icons.wifi_off_rounded,
                color: Tg.rojo,
                titulo: '¡Se cayó la señal!',
                mensaje: 'No pudimos traer tus chats.\n${s.error}',
                accionTexto: 'Reintentar',
                accionIcono: Icons.refresh,
                onAccion: _recargar,
              );
            }
            final d = s.data!;
            if (d.lista.isEmpty) {
              return const EstadoVacio(
                icono: Icons.forum_rounded,
                titulo: '¡Aquí no hay chisme todavía!',
                mensaje: 'Cuando le escribas a un vendedor desde un producto, tu plática aparece aquí.',
              );
            }
            final deProducto = d.lista.where((c) => c['productos'] != null).length;
            final deEspacio = d.lista.where((c) => c['anuncios_espacio'] != null).length;
            return RefreshIndicator(
              onRefresh: () async => _recargar(),
              child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                CabeceraTg(
                  titulo: 'Tus pláticas',
                  subtitulo: 'Desliza a la izquierda para borrar una',
                  icono: Icons.forum_rounded,
                  datos: [
                    DatoTg(Icons.chat_bubble, Tg.amarillo, '${d.lista.length}', 'CHATS'),
                    DatoTg(Icons.sell, Tg.azulClaro, '$deProducto', 'DE PRODUCTOS'),
                    DatoTg(Icons.crop_free, const Color(0xFF2EAD5B), '$deEspacio', 'DE ESPACIOS'),
                  ],
                ),
                for (final c in d.lista) _tarjeta(c, d),
              ]),
            );
          },
        ),
      );
}
