import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../widgets/mensaje.dart';

// rf-10: permite elegir tipos de avisos, categorías de interés y silenciar tianguis y vendedores.
class PreferenciasNotificacionScreen extends StatefulWidget {
  const PreferenciasNotificacionScreen({super.key});
  @override
  State<PreferenciasNotificacionScreen> createState() => _PrefsState();
}

class _PrefsState extends State<PreferenciasNotificacionScreen> {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  static const _tipos = <String, String>{
    'ofertas': 'Ofertas de mis productos y tianguis',
    'ausencias': 'Ausencias de puestos que me interesan',
    // rf-09: aquí está el interruptor; el backend genera los recordatorios
    'recordatorios_tianguis': 'Recordatorios de días de tianguis',
    'mensajes': 'Mensajes nuevos',
    'apartados_propuestas': 'Apartados y propuestas de precio',
  };

  Map<String, dynamic> _prefs = {};
  List<Map<String, dynamic>> _silencios = [];
  List<Tianguis> _tianguis = [];
  List<Map<String, dynamic>> _categorias = [];
  Set<String> _intereses = {};
  Map<String, String> _vendedores = {}; // id del perfil de vendedor -> nombre
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) => mostrarMensaje(context, t);

  Future<void> _cargar() async {
    try {
      var p = await _db.from('preferencias_notificacion').select().eq('id_usuario', _uid).maybeSingle();
      if (p == null) {
        await _db.from('preferencias_notificacion').insert({'id_usuario': _uid});
        p = await _db.from('preferencias_notificacion').select().eq('id_usuario', _uid).maybeSingle();
      }
      final s = await _db.from('silencios_notificacion').select().eq('id_usuario', _uid);
      final t = await CatalogoService().tianguis();
      final cats = await CatalogoService().categorias();
      final ints = await _db.from('intereses_categoria').select('id_categoria').eq('id_usuario', _uid);
      final silencios = List<Map<String, dynamic>>.from(s);
      final idsVend = [for (final x in silencios) if (x['id_vendedor'] != null) x['id_vendedor'] as String];
      final nombres = <String, String>{};
      if (idsVend.isNotEmpty) {
        final v = await _db.from('perfiles_vendedor').select('id, nombre_negocio').inFilter('id', idsVend);
        for (final x in v) {
          final n = (x['nombre_negocio'] as String?)?.trim();
          nombres[x['id'] as String] = (n == null || n.isEmpty) ? 'Vendedor' : n;
        }
      }
      if (mounted) {
        setState(() {
          _prefs = p ?? {};
          _silencios = silencios;
          _tianguis = t;
          _categorias = List<Map<String, dynamic>>.from(cats);
          _intereses = {for (final x in ints) x['id_categoria'] as String};
          _vendedores = nombres;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _cargando = false); _msg('$e'); }
    }
  }

  Future<void> _cambiar(String campo, bool v) async {
    final antes = _prefs[campo];
    setState(() => _prefs[campo] = v);
    try {
      await _db.from('preferencias_notificacion').update({campo: v}).eq('id_usuario', _uid);
    } catch (e) {
      if (mounted) setState(() => _prefs[campo] = antes);
      _msg('$e');
    }
  }

  Future<void> _silenciarTianguis() async {
    final yaSilenciados = {for (final s in _silencios) if (s['id_tianguis'] != null) s['id_tianguis']};
    final opciones = _tianguis.where((t) => !yaSilenciados.contains(t.id)).toList();
    if (opciones.isEmpty) return;
    final t = await showDialog<Tianguis>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Silenciar tianguis'),
        children: [for (final t in opciones) SimpleDialogOption(onPressed: () => Navigator.pop(context, t), child: Text(t.nombre))],
      ),
    );
    if (t == null) return;
    try {
      await _db.from('silencios_notificacion').insert({'id_usuario': _uid, 'id_tianguis': t.id});
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  // rf-10: categorías de las que quiere recibir avisos de ofertas.
  Future<void> _alternarInteres(String idCategoria, bool activo) async {
    final antes = {..._intereses};
    setState(() => activo ? _intereses.add(idCategoria) : _intereses.remove(idCategoria));
    try {
      if (activo) {
        await _db.from('intereses_categoria').upsert({'id_usuario': _uid, 'id_categoria': idCategoria});
      } else {
        await _db.from('intereses_categoria').delete().eq('id_usuario', _uid).eq('id_categoria', idCategoria);
      }
    } catch (e) {
      if (mounted) setState(() => _intereses = antes);
      _msg('$e');
    }
  }

  // rf-10: silencia a un vendedor concreto, elegido de una lista con buscador.
  Future<void> _silenciarVendedor() async {
    final yaSilenciados = {for (final s in _silencios) if (s['id_vendedor'] != null) s['id_vendedor']};
    List<Map<String, dynamic>> todos;
    try {
      final r = await _db
          .from('perfiles_vendedor')
          .select('id, nombre_negocio, id_usuario')
          .eq('estado', 'activo')
          .order('nombre_negocio');
      todos = List<Map<String, dynamic>>.from(r);
    } catch (e) {
      _msg('$e');
      return;
    }
    // no tiene sentido silenciarse a uno mismo
    final opciones = todos
        .where((v) => !yaSilenciados.contains(v['id']) && v['id_usuario'] != _uid)
        .toList();
    if (!mounted) return;
    if (opciones.isEmpty) {
      _msg('No hay más vendedores para silenciar');
      return;
    }
    final elegido = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ElegirVendedor(opciones: opciones),
    );
    if (elegido == null) return;
    try {
      await _db.from('silencios_notificacion').insert({'id_usuario': _uid, 'id_vendedor': elegido['id']});
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _quitarSilencio(dynamic id) async {
    try {
      await _db.from('silencios_notificacion').delete().eq('id', id);
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  static const _iconos = <String, (IconData, Color)>{
    'ofertas': (Icons.bolt, Tg.naranja),
    'ausencias': (Icons.event_busy, Tg.rosa),
    'recordatorios_tianguis': (Icons.event, Tg.azulClaro),
    'mensajes': (Icons.chat_bubble_rounded, Tg.amarillo),
    'apartados_propuestas': (Icons.handshake_rounded, Color(0xFF2EAD5B)),
  };

  // renglon de un silencio con su boton para quitarlo
  Widget _silencio(String nombre, dynamic id) => TarjetaTg(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        margen: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          const SelloTg(icono: Icons.notifications_off, color: Colors.white70, tam: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(
            tooltip: 'Quitar silencio',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _quitarSilencio(id),
          ),
        ]),
      );

  Widget _vacio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
        child: Text(texto, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
      );

  Widget _agregar(String texto, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: onTap, icon: const Icon(Icons.add_circle), label: Text(texto)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final t in _tianguis) t.id: t.nombre};
    final sTianguis = _silencios.where((s) => s['id_tianguis'] != null).toList();
    final sVendedores = _silencios.where((s) => s['id_vendedor'] != null).toList();
    return ScaffoldTg(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _cargando
          ? const CargandoTg()
          : ListView(padding: const EdgeInsets.only(bottom: 30), children: [
              const CabeceraTg(
                titulo: 'Qué te avisamos',
                subtitulo: 'Tú decides qué te llega',
                icono: Icons.notifications_rounded,
                color: Tg.naranja,
              ),
              const SeccionTg('Quiero recibir'),
              for (final e in _tipos.entries)
                InterruptorTg(
                  icono: _iconos[e.key]?.$1 ?? Icons.notifications,
                  color: _iconos[e.key]?.$2 ?? Tg.amarillo,
                  texto: e.value,
                  valor: _prefs[e.key] == true,
                  onChanged: (v) => _cambiar(e.key, v),
                ),
              const SeccionTg('Categorías que me interesan'),
              _vacio('Te avisamos de las ofertas de estas categorías.'),
              if (_categorias.isEmpty) _vacio('No hay categorías disponibles'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in _categorias)
                    FichaTg(
                      texto: '${c['nombre']}',
                      elegida: _intereses.contains(c['id']),
                      onCambio: (v) => _alternarInteres(c['id'] as String, v),
                    ),
                ]),
              ),
              const SeccionTg('Tianguis silenciados'),
              if (sTianguis.isEmpty) _vacio('Ninguno'),
              for (final s in sTianguis) _silencio(nombres[s['id_tianguis']] ?? 'Tianguis', s['id']),
              _agregar('Silenciar un tianguis', _silenciarTianguis),
              const SeccionTg('Vendedores silenciados'),
              if (sVendedores.isEmpty) _vacio('Ninguno'),
              for (final s in sVendedores) _silencio(_vendedores[s['id_vendedor']] ?? 'Vendedor', s['id']),
              _agregar('Silenciar un vendedor', _silenciarVendedor),
            ]),
    );
  }
}

// diálogo con buscador para elegir al vendedor que se quiere silenciar
class _ElegirVendedor extends StatefulWidget {
  final List<Map<String, dynamic>> opciones;
  const _ElegirVendedor({required this.opciones});
  @override
  State<_ElegirVendedor> createState() => _ElegirVendedorState();
}

class _ElegirVendedorState extends State<_ElegirVendedor> {
  String _texto = '';

  String _nombre(Map<String, dynamic> v) {
    final n = (v['nombre_negocio'] as String?)?.trim();
    return (n == null || n.isEmpty) ? 'Vendedor sin nombre' : n;
  }

  @override
  Widget build(BuildContext context) {
    final t = _texto.trim().toLowerCase();
    final lista = widget.opciones.where((v) => t.isEmpty || _nombre(v).toLowerCase().contains(t)).toList();
    return AlertDialog(
      title: const Text('Silenciar vendedor'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar por nombre'),
            onChanged: (v) => setState(() => _texto = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Sin resultados'))
                : ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(_nombre(lista[i])),
                      onTap: () => Navigator.pop(context, lista[i]),
                    ),
                  ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}
