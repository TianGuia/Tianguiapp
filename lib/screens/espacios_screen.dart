import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/enums.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/chat_service.dart';
import '../widgets/moderacion.dart';
import 'chat_screen.dart';
import '../widgets/entradas.dart';

/// RF-33 a RF-36: anuncios de espacios (renta, préstamo o traspaso) entre vendedores.
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

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
  void _recargar() => setState(() => _futuro = _cargar());

  /// RF-34: consulta y filtro por tianguis y tipo de acuerdo.
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

  /// RF-35: conversación privada desde el anuncio.
  Future<void> _contactar(Map<String, dynamic> a) async {
    final dueno = (a['perfiles_vendedor'] as Map?)?['id_usuario'] as String?;
    if (dueno == null) return;
    try {
      final id = await ChatService().conversacionDeAnuncio(a['id'] as String, dueno);
      if (!mounted) return;
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => ChatScreen(idConversacion: id, titulo: '${a['titulo']}')));
    } catch (e) {
      _msg('$e');
    }
  }

  /// RF-44: reportar un anuncio de espacio.
  Future<void> _reportar(Map<String, dynamic> a) async {
    final dueno = (a['perfiles_vendedor'] as Map?)?['id_usuario'] as String?;
    await reportarContenido(
      context,
      tipoObjetivo: TipoReporte.anuncioEspacio,
      idObjetivo: a['id'] as String,
      idUsuarioReportado: dueno,
    );
  }

  /// RF-33 (nuevo) y RF-36 (editar).
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

  /// RF-36: cerrar cuando el espacio deja de estar disponible.
  Future<void> _cerrar(Map<String, dynamic> a) async {
    try {
      await _db.from('anuncios_espacio').update({'estado': Enums.anuncioCerrado}).eq('id', a['id']);
      _recargar();
    } catch (e) {
      _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
                }
                if (s.hasError) return Center(child: Text('Error: ${s.error}'));
                final l = s.data!;
                if (l.isEmpty) return const Center(child: Text('No hay anuncios por ahora'));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                  itemCount: l.length,
                  itemBuilder: (_, i) {
                    final a = l[i];
                    final mio = a['id_vendedor'] == widget.idVendedor;
                    final negocio = (a['perfiles_vendedor'] as Map?)?['nombre_negocio'];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        isThreeLine: true,
                        leading: const Icon(Icons.crop_free, color: Tg.amarillo),
                        title: Text('${_etiquetaRol(a['rol'])} · ${a['titulo']}',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${a['acuerdo']} · ${_nombreTianguis(a['id_tianguis'])}'
                            '${negocio != null ? ' · $negocio' : ''}'
                            '${(a['descripcion'] ?? '') != '' ? '\n${a['descripcion']}' : ''}'),
                        trailing: mio
                            ? PopupMenuButton<String>(
                                onSelected: (v) => v == 'editar' ? _formulario(anuncio: a) : _cerrar(a),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                                  PopupMenuItem(value: 'cerrar', child: Text('Cerrar anuncio')),
                                ],
                              )
                            : Row(mainAxisSize: MainAxisSize.min, children: [
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
