import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';

/// RF-15: tipos de notificación que quiero recibir y tianguis silenciados.
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
    'recordatorios_tianguis': 'Recordatorios de días de tianguis',
    'mensajes': 'Mensajes nuevos',
    'apartados_propuestas': 'Apartados y propuestas de precio',
  };

  Map<String, dynamic> _prefs = {};
  List<Map<String, dynamic>> _silencios = [];
  List<Tianguis> _tianguis = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _cargar() async {
    try {
      var p = await _db.from('preferencias_notificacion').select().eq('id_usuario', _uid).maybeSingle();
      if (p == null) {
        await _db.from('preferencias_notificacion').insert({'id_usuario': _uid});
        p = await _db.from('preferencias_notificacion').select().eq('id_usuario', _uid).maybeSingle();
      }
      final s = await _db.from('silencios_notificacion').select().eq('id_usuario', _uid);
      final t = await CatalogoService().tianguis();
      if (mounted) {
        setState(() {
          _prefs = p ?? {};
          _silencios = List<Map<String, dynamic>>.from(s);
          _tianguis = t;
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

  Future<void> _quitarSilencio(dynamic id) async {
    try {
      await _db.from('silencios_notificacion').delete().eq('id', id);
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {for (final t in _tianguis) t.id: t.nombre};
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Tg.amarillo))
          : ListView(padding: const EdgeInsets.all(14), children: [
              Text('Quiero recibir', style: Tg.marcador(18)),
              for (final e in _tipos.entries)
                SwitchListTile(
                  title: Text(e.value),
                  value: _prefs[e.key] == true,
                  onChanged: (v) => _cambiar(e.key, v),
                ),
              const SizedBox(height: 14),
              Text('Tianguis silenciados', style: Tg.marcador(18)),
              if (_silencios.where((s) => s['id_tianguis'] != null).isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Ninguno')),
              for (final s in _silencios.where((s) => s['id_tianguis'] != null))
                ListTile(
                  leading: const Icon(Icons.notifications_off_outlined),
                  title: Text(nombres[s['id_tianguis']] ?? 'Tianguis'),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => _quitarSilencio(s['id'])),
                ),
              TextButton.icon(
                  onPressed: _silenciarTianguis, icon: const Icon(Icons.add), label: const Text('Silenciar un tianguis')),
            ]),
    );
  }
}
