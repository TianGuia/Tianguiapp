import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/enums.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/chat_service.dart';
import '../widgets/moderacion.dart';
import 'chat_screen.dart';
import '../widgets/mensaje.dart';

// aqui se cumplen rf-28 a rf-31, cada parte de abajo dice cual cumple
class EspaciosScreen extends StatefulWidget {
  final String idVendedor;
  const EspaciosScreen({super.key, required this.idVendedor});
  @override
  State<EspaciosScreen> createState() => _EspaciosScreenState();
}

class _EspaciosScreenState extends State<EspaciosScreen> {
  final _db = Supabase.instance.client;
  List<Tianguis> _tianguis = [];
  String? _fTianguis, _fAcuerdo;
  late Future<List<Map<String, dynamic>>> _futuro = _cargar();

  @override
  void initState() {
    super.initState();
    CatalogoService().tianguis().then((t) {
      if (mounted) setState(() => _tianguis = t);
    }).catchError((_) {});
  }

  void _msg(String t) => mostrarMensaje(context, t);
  void _recargar() => setState(() => _futuro = _cargar());

  // rf-29 se cumple aqui: el vendedor ve los anuncios de espacios y los filtra por tianguis y tipo de acuerdo
  Future<List<Map<String, dynamic>>> _cargar() async {
    var q = _db
        .from('anuncios_espacio')
        .select('*, perfiles_vendedor(id_usuario, nombre_negocio)')
        .eq('estado', Enums.anuncioAbierto)
        .eq('moderado', false);
    if (_fTianguis != null) q = q.eq('id_tianguis', _fTianguis!);
    if (_fAcuerdo != null) q = q.eq('acuerdo', _fAcuerdo!);
    final r = await q.order('creado_en', ascending: false);
    return List<Map<String, dynamic>>.from(r);
  }

  String _nombreTianguis(String id) => _tianguis.where((t) => t.id == id).firstOrNull?.nombre ?? '';
  String _etiquetaRol(String? r) => r == Enums.rolOfrezco ? 'OFREZCO' : 'BUSCO';

  // rf-30 se cumple aqui: el vendedor abre un chat con otro vendedor desde un anuncio
  Future<void> _contactar(Map<String, dynamic> a) async {
    final dueno = (a['perfiles_vendedor'] as Map?)?['id_usuario'] as String?;
    if (dueno == null) return;
    try {
      final id = await ChatService().iniciarConversacion(idAnuncio: a['id'] as String, idUsuarioReceptor: dueno);
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ChatScreen(idConversacion: id, titulo: '${a['titulo']}')));
    } catch (e) {
      _msg('$e');
    }
  }

  // rf-44 se cumple aqui: se manda un reporte cuando algo rompe las reglas
  Future<void> _reportar(Map<String, dynamic> a) async {
    final dueno = (a['perfiles_vendedor'] as Map?)?['id_usuario'] as String?;
    await reportarContenido(
      context,
      tipoObjetivo: TipoReporte.anuncioEspacio,
      idObjetivo: a['id'] as String,
      idUsuarioReportado: dueno,
    );
  }

  // rf-28 se cumple aqui: el vendedor publica que ofrece o busca un espacio
  Future<void> _formulario({Map<String, dynamic>? anuncio}) async {
    if (_tianguis.isEmpty) {
      _msg('No hay tianguis disponibles');
      return;
    }
    final titulo = TextEditingController(text: anuncio?['titulo'] ?? '');
    final desc = TextEditingController(text: anuncio?['descripcion'] ?? '');
    String idT = anuncio?['id_tianguis'] ?? _fTianguis ?? _tianguis.first.id;
    String rol = anuncio?['rol'] ?? Enums.rolOfrezco;
    String acuerdo = anuncio?['acuerdo'] ?? Enums.acuerdos.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, set) => AlertDialog(
          title: Text(anuncio == null ? 'Nuevo anuncio' : 'Editar anuncio'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: Enums.rolOfrezco, label: Text('Ofrezco')),
                  ButtonSegment(value: Enums.rolBusco, label: Text('Busco')),
                ],
                selected: {rol},
                onSelectionChanged: (v) => set(() => rol = v.first),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: acuerdo,
                isExpanded: true,
                items: [for (final a in Enums.acuerdos) DropdownMenuItem(value: a, child: Text(a))],
                onChanged: (v) => set(() => acuerdo = v ?? acuerdo),
              ),
              DropdownButton<String>(
                value: idT,
                isExpanded: true,
                items: [for (final t in _tianguis) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
                onChanged: (v) => set(() => idT = v ?? idT),
              ),
              TextField(controller: titulo, maxLength: 80, decoration: const InputDecoration(hintText: 'Título')),
              TextField(controller: desc, maxLines: 3, maxLength: 300, decoration: const InputDecoration(hintText: 'Detalles (opcional)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || titulo.text.trim().isEmpty) return;
    final datos = {
      'id_tianguis': idT,
      'rol': rol,
      'acuerdo': acuerdo,
      'titulo': titulo.text.trim(),
      'descripcion': desc.text.trim().isEmpty ? null : desc.text.trim(),
    };
    try {
      if (anuncio == null) {
        await _db.from('anuncios_espacio').insert({...datos, 'id_vendedor': widget.idVendedor});
      } else {
        await _db.from('anuncios_espacio').update(datos).eq('id', anuncio['id']);
      }
      _recargar();
    } catch (e) {
      _msg('$e');
    }
  }

  // rf-31 se cumple aqui: el vendedor cambia o cierra su anuncio cuando el espacio ya no esta
  Future<void> _cerrar(Map<String, dynamic> a) async {
    try {
      await _db.from('anuncios_espacio').update({'estado': Enums.anuncioCerrado}).eq('id', a['id']);
      _recargar();
    } catch (e) {
      _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Espacios')),
        floatingActionButton:
            FloatingActionButton.extended(onPressed: () => _formulario(), icon: const Icon(Icons.add), label: const Text('Anuncio')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: DropdownButton<String?>(
                  value: _fTianguis,
                  isExpanded: true,
                  hint: const Text('Todos los tianguis'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos los tianguis')),
                    for (final t in _tianguis) DropdownMenuItem(value: t.id, child: Text(t.nombre)),
                  ],
                  onChanged: (v) { _fTianguis = v; _recargar(); },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String?>(
                  value: _fAcuerdo,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Cualquier acuerdo')),
                    for (final a in Enums.acuerdos) DropdownMenuItem(value: a, child: Text(a)),
                  ],
                  onChanged: (v) { _fAcuerdo = v; _recargar(); },
                ),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futuro,
              builder: (_, s) {
                if (s.connectionState != ConnectionState.done) return const CargandoTg();
                if (s.hasError) {
                  return EstadoVacio(
                    icono: Icons.wifi_off_rounded,
                    color: Tg.rojo,
                    titulo: '¡Se cayó la señal!',
                    mensaje: 'No se pudieron cargar los anuncios.\n${s.error}',
                  );
                }
                final l = s.data!;
                if (l.isEmpty) {
                  return EstadoVacio(
                    icono: Icons.crop_free_rounded,
                    color: const Color(0xFF2EAD5B),
                    titulo: '¡No hay anuncios por ahora!',
                    mensaje: 'Aquí los vendedores se avisan de lugares libres, relevos y espacios para compartir. Publica el primero.',
                    accionTexto: 'Publicar anuncio',
                    accionIcono: Icons.add,
                    onAccion: () => _formulario(),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final a = l[i];
                    final mio = a['id_vendedor'] == widget.idVendedor;
                    final negocio = (a['perfiles_vendedor'] as Map?)?['nombre_negocio'];
                    final desc = (a['descripcion'] ?? '') as String;
                    return TarjetaTg(
                      acento: mio ? Tg.amarillo : const Color(0xFF2EAD5B),
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SelloTg(
                            icono: Icons.crop_free,
                            color: mio ? Tg.amarillo : const Color(0xFF2EAD5B),
                            colorIcono: mio ? Tg.azulOscuro : Colors.white,
                            tam: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              PildoraTg(_etiquetaRol(a['rol']).toUpperCase(),
                                  color: Tg.azulClaro, colorTexto: Tg.azulOscuro),
                              PildoraTg('${a['acuerdo']}'.toUpperCase(),
                                  color: Colors.white12, colorTexto: Colors.white70),
                              if (mio) const PildoraTg('TUYO', color: Tg.amarillo),
                            ]),
                            const SizedBox(height: 4),
                            Text('${a['titulo']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.place, size: 15, color: Tg.rosa),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                    '${_nombreTianguis(a['id_tianguis'])}${negocio != null ? ' · $negocio' : ''}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ),
                            ]),
                            if (desc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(desc,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14.5, height: 1.15)),
                              ),
                          ]),
                        ),
                        mio
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'editar' ? _formulario(anuncio: a) : _cerrar(a),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                                  PopupMenuItem(value: 'cerrar', child: Text('Cerrar anuncio')),
                                ],
                              )
                            : Column(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  tooltip: 'Contactar',
                                  onPressed: () => _contactar(a),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (_) => _reportar(a),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'reportar', child: Text('Reportar anuncio')),
                                  ],
                                ),
                              ]),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
