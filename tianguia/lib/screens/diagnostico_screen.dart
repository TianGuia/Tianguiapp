import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';

/// Revisa tablas, políticas (RLS), funciones y storage de tu Supabase
/// con TU sesión, y muestra qué funciona y qué no.
class DiagnosticoScreen extends StatefulWidget {
  const DiagnosticoScreen({super.key});
  @override
  State<DiagnosticoScreen> createState() => _DiagnosticoScreenState();
}

class _Prueba {
  final String nombre;
  final Future<String> Function() correr;
  bool? ok;
  String detalle = 'Esperando…';
  _Prueba(this.nombre, this.correr);
}

class _DiagnosticoScreenState extends State<DiagnosticoScreen> {
  final _db = Supabase.instance.client;
  late final List<_Prueba> _pruebas;
  bool _corriendo = false;

  Future<String> _filas(String tabla, {String col = 'id'}) async {
    final r = await _db.from(tabla).select(col);
    return '${(r as List).length} filas';
  }

  @override
  void initState() {
    super.initState();
    final uid = _db.auth.currentUser?.id ?? '';
    _pruebas = [
      _Prueba('Sesión activa', () async => _db.auth.currentUser?.email ?? 'sin correo'),
      _Prueba('Tu fila en usuarios (trigger de alta)', () async {
        final r = await _db.from('usuarios').select('nombre_publico').eq('id', uid).maybeSingle();
        if (r == null) throw 'No existe: revisa handle_new_user';
        return 'nombre_publico = ${r['nombre_publico']}';
      }),
      _Prueba('Tus preferencias de notificación', () async {
        final r = await _db.from('preferencias_notificacion').select('id_usuario').eq('id_usuario', uid).maybeSingle();
        if (r == null) throw 'No existe la fila';
        return 'ok';
      }),
      _Prueba('Función terminos_pendientes()', () async {
        final r = await _db.rpc('terminos_pendientes') as List;
        return '${r.length} pendientes';
      }),
      _Prueba('Aceptaciones de términos tuyas', () async {
        final r = await _db.from('aceptaciones_terminos').select('id').eq('id_usuario', uid);
        return '${(r as List).length} aceptadas';
      }),
      _Prueba('Categorías (lectura)', () => _filas('categorias')),
      _Prueba('Tianguis (lectura)', () => _filas('tianguis')),
      _Prueba('Etiquetas de valoración', () => _filas('etiquetas_valoracion')),
      _Prueba('Puestos (lectura)', () => _filas('puestos')),
      _Prueba('Productos visibles', () => _filas('productos')),
      _Prueba('Búsqueda de texto en productos', () async {
        final r = await _db
            .from('productos')
            .select('id')
            .textSearch('busqueda', 'a', config: 'spanish', type: TextSearchType.websearch);
        return '${(r as List).length} resultados';
      }),
      _Prueba('Tu perfil de vendedor', () async {
        final r = await _db.from('perfiles_vendedor').select('id').eq('id_usuario', uid).maybeSingle();
        return r == null ? 'No habilitado (normal si eres solo comprador)' : 'id ${r['id']}';
      }),
      _Prueba('¿Eres administrador?', () async {
        final r = await _db.from('administradores').select('id_usuario').eq('id_usuario', uid).maybeSingle();
        return r == null ? 'No' : 'Sí';
      }),
      _Prueba('Tus conversaciones', () async {
        final r = await _db.from('conversaciones').select('id').or('id_iniciador.eq.$uid,id_receptor.eq.$uid');
        return '${(r as List).length} conversaciones';
      }),
      _Prueba('Tus favoritos', () async {
        final r = await _db.from('favoritos').select('id').eq('id_usuario', uid);
        return '${(r as List).length} favoritos';
      }),
      _Prueba('Tus notificaciones', () async {
        final r = await _db.from('notificaciones').select('id').eq('id_usuario', uid);
        return '${(r as List).length} notificaciones';
      }),
      _Prueba('Storage: bucket productos', () async {
        final r = await _db.storage.from('productos').list();
        return 'accesible (${r.length} elementos en la raíz)';
      }),
      _Prueba('Storage: bucket perfiles', () async {
        final r = await _db.storage.from('perfiles').list();
        return 'accesible (${r.length} elementos en la raíz)';
      }),
    ];
    _correr();
  }

  Future<void> _correr() async {
    setState(() {
      _corriendo = true;
      for (final p in _pruebas) {
        p.ok = null;
        p.detalle = 'Probando…';
      }
    });
    for (final p in _pruebas) {
      try {
        p.detalle = await p.correr();
        p.ok = true;
      } catch (e) {
        p.detalle = e is PostgrestException ? '${e.message} (${e.code})' : '$e';
        p.ok = false;
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _corriendo = false);
  }

  @override
  Widget build(BuildContext context) {
    final fallas = _pruebas.where((p) => p.ok == false).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico de conexión')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _corriendo ? null : _correr,
        icon: const Icon(Icons.refresh),
        label: const Text('Repetir'),
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _corriendo ? 'Probando…' : (fallas == 0 ? 'Todo respondió bien' : '$fallas prueba(s) con error'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: fallas == 0 ? Colors.greenAccent : Tg.amarillo,
            ),
          ),
        ),
        for (final p in _pruebas)
          ListTile(
            leading: p.ok == null
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(p.ok! ? Icons.check_circle : Icons.error, color: p.ok! ? Colors.greenAccent : Tg.rojo),
            title: Text(p.nombre),
            subtitle: Text(p.detalle),
          ),
      ]),
    );
  }
}
