import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/fondo.dart';
import 'home_screen.dart';
import '../widgets/entradas.dart';

/// Panel de administración: RF-47 a RF-54.
///   Resumen · Reportes (RF-50) · Apelaciones (RF-51) · Tianguis (RF-47/48/49)
///   Términos (RF-52) · Consulta (RF-54)
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _i = 0;

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Salir del panel?'),
        content: const Text('Tendrás que volver a escribir la clave para entrar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SALIR')),
        ],
      ),
    );
    if (ok == true) await AuthService().salirAdmin();
  }

  @override
  Widget build(BuildContext context) {
    const titulos = ['Resumen', 'Reportes', 'Apelaciones', 'Tianguis', 'Términos', 'Consulta'];
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Admin · ${titulos[_i]}'),
          actions: [
            IconButton(
              tooltip: 'Ver la app como usuario',
              icon: const Icon(Icons.storefront),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const HomeScreen())),
            ),
            IconButton(
              tooltip: 'Administradores',
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const _AdministradoresScreen())),
            ),
            IconButton(
              tooltip: 'Categorías y etiquetas',
              icon: const Icon(Icons.category_outlined),
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const _CatalogosScreen())),
            ),
            IconButton(tooltip: 'Salir', icon: const Icon(Icons.logout), onPressed: _salir),
          ],
        ),
        body: IndexedStack(index: _i, children: [
          _ResumenTab(ir: (v) => setState(() => _i = v)),
          const _ReportesTab(),
          const _ApelacionesTab(),
          const _TianguisTab(),
          const _TerminosTab(),
          const _ConsultaTab(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Resumen'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'Reportes'),
            NavigationDestination(icon: Icon(Icons.gavel), label: 'Apelaciones'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Tianguis'),
            NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Términos'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Consulta'),
          ],
        ),
      ),
    );
  }
}

// ======================= utilidades =======================

void _aviso(BuildContext c, String t) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

String _fecha(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : d.toString().substring(0, 16);
}

Future<String?> _pedirTexto(BuildContext c, String titulo, String hint,
    {bool obligatorio = true}) {
  final ctl = TextEditingController();
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: ctl,
        maxLines: 3,
        minLines: 1,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCELAR')),
        FilledButton(
          onPressed: () {
            final t = ctl.text.trim();
            if (obligatorio && t.isEmpty) return;
            Navigator.pop(c, t);
          },
          child: const Text('ACEPTAR'),
        ),
      ],
    ),
  );
}

/// Diálogo con varios campos. [campos]: (etiqueta, ocultar). Devuelve los
/// textos en orden, o null si se cancela. Ningún campo puede ir vacío.
Future<List<String>?> _pedirCampos(BuildContext c, String titulo, List<(String, bool)> campos,
    {String? nota}) {
  final ctl = [for (final _ in campos) TextEditingController()];
  return showDialog<List<String>>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (nota != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(nota, style: const TextStyle(fontSize: 12))),
          for (var i = 0; i < campos.length; i++)
            TextField(
              controller: ctl[i],
              obscureText: campos[i].$2,
              decoration: InputDecoration(labelText: campos[i].$1),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCELAR')),
        FilledButton(
          onPressed: () {
            final v = [for (final x in ctl) x.text];
            if (v.any((t) => t.trim().isEmpty)) return;
            Navigator.pop(c, v);
          },
          child: const Text('ACEPTAR'),
        ),
      ],
    ),
  );
}

/// Lista con carga, error y "tirar para recargar".
class _ListaAsync extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> futuro;
  final Future<void> Function() onRecargar;
  final Widget Function(Map<String, dynamic>) item;
  final String vacio;
  const _ListaAsync(
      {required this.futuro, required this.onRecargar, required this.item, required this.vacio});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: futuro,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Error: ${s.error}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: onRecargar, child: const Text('REINTENTAR')),
              ]),
            ),
          );
        }
        final l = s.data!;
        return RefreshIndicator(
          onRefresh: onRecargar,
          child: l.isEmpty
              ? ListView(children: [
                  Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(vacio)))
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: l.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => item(l[i]),
                ),
        );
      },
    );
  }
}

// ======================= Administradores =======================

class _AdministradoresScreen extends StatefulWidget {
  const _AdministradoresScreen();
  @override
  State<_AdministradoresScreen> createState() => _AdministradoresScreenState();
}

class _AdministradoresScreenState extends State<_AdministradoresScreen> {
  static const _confirma = [('Tu clave', true), ('Tu respuesta secreta', true)];
  final _svc = AdminService();
  bool _guardando = false;
  late Future<({List<Map<String, dynamic>> admins, List<Map<String, dynamic>> bitacora})> _futuro = _cargar();

  Future<({List<Map<String, dynamic>> admins, List<Map<String, dynamic>> bitacora})> _cargar() async {
    final admins = await _svc.administradores();
    final bitacora = await _svc.bitacoraAdmins();
    return (admins: admins, bitacora: bitacora);
  }

  Future<void> _recargar() async {
    setState(() => _futuro = _cargar());
    try {
      await _futuro;
    } catch (_) {}
  }

  Future<void> _ejecutar(Future<void> Function() accion, String ok) async {
    setState(() => _guardando = true);
    try {
      await accion();
      if (mounted) {
        _aviso(context, ok);
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _nuevo() async {
    final v = await _pedirCampos(
        context,
        'Nuevo administrador',
        [('Nombre', false), ('Clave (mínimo 6)', true), ('Respuesta secreta', true), ..._confirma],
        nota: 'Confirma con tu propia clave y respuesta. Máximo 4 administradores.');
    if (v == null) return;
    await _ejecutar(
        () => _svc.guardarAdministrador(
            nombre: v[0].trim(), clave: v[1], respuesta: v[2].trim(), miClave: v[3], miRespuesta: v[4].trim()),
        'Administrador guardado');
  }

  Future<void> _cambiarClave(Map<String, dynamic> a) async {
    final v = await _pedirCampos(
        context,
        'Nueva clave de ${a['nombre']}',
        [('Nueva clave (mínimo 6)', true), ('Nueva respuesta secreta', true), ..._confirma],
        nota: 'Confirma con tu propia clave y respuesta.');
    if (v == null) return;
    await _ejecutar(
        () => _svc.guardarAdministrador(
            nombre: '${a['nombre']}', clave: v[0], respuesta: v[1].trim(), miClave: v[2], miRespuesta: v[3].trim()),
        'Clave actualizada');
  }

  Future<void> _quitar(Map<String, dynamic> a) async {
    final v = await _pedirCampos(context, 'Quitar a ${a['nombre']}', _confirma,
        nota: 'Se cerrará su sesión y ya no podrá entrar. Confirma con tu clave y respuesta.');
    if (v == null) return;
    await _ejecutar(
        () => _svc.quitarAdministrador('${a['nombre']}', miClave: v[0], miRespuesta: v[1].trim()),
        'Administrador quitado');
  }

  Widget _fila(Map<String, dynamic> a) {
    final yo = a['es_yo'] == true;
    final sesion = a['sesion_hasta'];
    return Card(
      child: ListTile(
        leading: Icon(yo ? Icons.verified_user_outlined : Icons.person_outline),
        title: Text('${a['nombre']}${yo ? ' (tú)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${sesion == null ? 'sin sesión activa' : 'sesión hasta ${_fecha(sesion)}'}'
            ' · clave: ${_fecha(a['actualizado_en'])}'),
        trailing: PopupMenuButton<String>(
          enabled: !_guardando,
          onSelected: (v) => v == 'clave' ? _cambiarClave(a) : _quitar(a),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'clave', child: Text('Cambiar clave')),
            if (!yo) const PopupMenuItem(value: 'quitar', child: Text('Quitar administrador')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Fondo(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Admin · Administradores')),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: _guardando ? null : _nuevo, icon: const Icon(Icons.add), label: const Text('NUEVO')),
          body: FutureBuilder<({List<Map<String, dynamic>> admins, List<Map<String, dynamic>> bitacora})>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
              }
              if (s.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Error: ${s.error}\n(¿ya corriste 10_administradores.sql?)', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _recargar, child: const Text('REINTENTAR')),
                    ]),
                  ),
                );
              }
              final admins = s.data!.admins;
              final bit = s.data!.bitacora;
              return RefreshIndicator(
                onRefresh: _recargar,
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                  if (_guardando) const LinearProgressIndicator(color: Tg.amarillo),
                  Text('Administradores (${admins.length} de 4)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final a in admins) ...[_fila(a), const SizedBox(height: 8)],
                  const SizedBox(height: 12),
                  const Text('Historial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (bit.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin movimientos')))
                  else
                    for (final b in bit)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${'${b['accion']}'.replaceAll('_', ' ')} · ${b['objetivo'] ?? ''}'),
                        subtitle: Text('por ${b['quien'] ?? '—'} · ${_fecha(b['creado_en'])}'),
                      ),
                ]),
              );
            },
          ),
        ),
      );
}

// ======================= Categorías y etiquetas =======================

class _CatalogosScreen extends StatefulWidget {
  const _CatalogosScreen();
  @override
  State<_CatalogosScreen> createState() => _CatalogosScreenState();
}

class _CatalogosScreenState extends State<_CatalogosScreen> {
  static const _tablas = {'categorias': 'Categorías', 'etiquetas': 'Etiquetas de valoración'};
  final _svc = AdminService();
  String _tabla = 'categorias';
  bool _guardando = false;
  late Future<List<Map<String, dynamic>>> _futuro = _svc.catalogo(_tabla);

  Future<void> _recargar() async {
    setState(() => _futuro = _svc.catalogo(_tabla));
    try {
      await _futuro;
    } catch (_) {}
  }

  Future<void> _guardar({Map<String, dynamic>? x, String? nombre, bool? activa}) async {
    setState(() => _guardando = true);
    try {
      await _svc.guardarCatalogo(_tabla,
          id: x?['id'] as String?,
          nombre: nombre ?? '${x?['nombre']}',
          activa: activa ?? (x?['activa'] as bool? ?? true));
      if (mounted) {
        _aviso(context, 'Guardado');
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _nuevo() async {
    final n = await _pedirTexto(
        context, _tabla == 'categorias' ? 'Nueva categoría' : 'Nueva etiqueta', 'Nombre');
    if (n != null) await _guardar(nombre: n);
  }

  Future<void> _renombrar(Map<String, dynamic> x) async {
    final n = await _pedirTexto(context, 'Renombrar', '${x['nombre']}');
    if (n != null) await _guardar(x: x, nombre: n);
  }

  Widget _fila(Map<String, dynamic> x) {
    final activa = x['activa'] == true;
    return Card(
      child: ListTile(
        title: Text('${x['nombre']}',
            style: TextStyle(fontWeight: FontWeight.w700, color: activa ? null : Colors.grey)),
        subtitle: Text('${x['usos']} en uso${activa ? '' : ' · desactivada'}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              tooltip: 'Renombrar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _guardando ? null : () => _renombrar(x)),
          Switch(value: activa, onChanged: _guardando ? null : (v) => _guardar(x: x, activa: v)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Fondo(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Admin · Catálogos')),
          floatingActionButton: FloatingActionButton.extended(
              onPressed: _guardando ? null : _nuevo, icon: const Icon(Icons.add), label: const Text('NUEVA')),
          body: Column(children: [
            if (_guardando) const LinearProgressIndicator(color: Tg.amarillo),
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
                for (final e in _tablas.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _tabla == e.key,
                      onSelected: (_) {
                        _tabla = e.key;
                        _recargar();
                      },
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: _ListaAsync(
                  futuro: _futuro, onRecargar: _recargar, vacio: 'Sin elementos', item: _fila),
            ),
          ]),
        ),
      );
}

// ======================= Resumen y medidas activas =======================

class _ResumenTab extends StatefulWidget {
  /// Cambia a otra pestaña del panel (índice de la barra inferior).
  final void Function(int) ir;
  const _ResumenTab({required this.ir});
  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab> {
  static const _objetivos = {
    'puesto': 'Puesto',
    'producto': 'Publicación',
    'vendedor': 'Perfil de vendedor',
    'perfil': 'Perfil',
    'mensaje': 'Mensaje',
    'calificacion': 'Calificación',
    'anuncio_espacio': 'Anuncio de espacio',
  };

  final _svc = AdminService();
  bool _guardando = false;
  late Future<({Map<String, int> datos, List<Map<String, dynamic>> medidas})> _futuro = _cargar();

  Future<({Map<String, int> datos, List<Map<String, dynamic>> medidas})> _cargar() async {
    final datos = await _svc.resumen();
    final medidas = await _svc.medidasActivas();
    return (datos: datos, medidas: medidas);
  }

  Future<void> _recargar() async {
    setState(() => _futuro = _cargar());
    try {
      await _futuro;
    } catch (_) {}
  }

  Future<void> _levantar(Map<String, dynamic> m) async {
    final motivo = await _pedirTexto(context, 'Motivo para levantar la medida', 'Motivo general');
    if (motivo == null) return;
    setState(() => _guardando = true);
    try {
      await _svc.levantarMedida(m['id'] as String, motivo);
      if (mounted) {
        _aviso(context, 'Medida levantada');
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo levantar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _dato(String etiqueta, int? v, IconData icono, {bool alerta = false, VoidCallback? onTap}) =>
      SizedBox(
        width: 156,
        child: Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icono, color: alerta && (v ?? 0) > 0 ? Tg.amarillo : null),
                const SizedBox(height: 6),
                Text('${v ?? 0}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                Text(etiqueta, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        ),
      );

  Widget _medida(Map<String, dynamic> m) {
    final objetivo = _objetivos['${m['tipo_objetivo']}'] ?? '${m['tipo_objetivo']}';
    final medida = '${m['tipo_medida']}'.replaceAll('_', ' ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        isThreeLine: true,
        title: Text('$objetivo · $medida', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${m['usuario_nombre'] ?? '—'} · ${_fecha(m['creada_en'])}\n'
            '${m['motivo_general'] ?? ''}${m['id_reporte'] == null ? ' (directa)' : ''}'),
        trailing: TextButton(onPressed: _guardando ? null : () => _levantar(m), child: const Text('LEVANTAR')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<({Map<String, int> datos, List<Map<String, dynamic>> medidas})>(
        future: _futuro,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
          }
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Error: ${s.error}\n(¿ya corriste 08_resumen_y_medidas_activas.sql?)',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _recargar, child: const Text('REINTENTAR')),
                ]),
              ),
            );
          }
          final d = s.data!.datos;
          final medidas = s.data!.medidas;
          return RefreshIndicator(
            onRefresh: _recargar,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
              if (_guardando) const LinearProgressIndicator(color: Tg.amarillo),
              const Text('Pendientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _dato('Reportes pendientes', d['reportes_pendientes'], Icons.flag_outlined,
                    alerta: true, onTap: () => widget.ir(1)),
                _dato('Apelaciones pendientes', d['apelaciones_pendientes'], Icons.gavel,
                    alerta: true, onTap: () => widget.ir(2)),
                _dato('Medidas activas', d['medidas_activas'], Icons.shield_outlined),
              ]),
              const SizedBox(height: 16),
              const Text('Plataforma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _dato('Usuarios', d['usuarios'], Icons.people_outline, onTap: () => widget.ir(5)),
                _dato('Cuentas suspendidas', d['usuarios_suspendidos'], Icons.block),
                _dato('Vendedores', d['vendedores'], Icons.store_mall_directory_outlined),
                _dato('Perfiles suspendidos', d['vendedores_suspendidos'], Icons.person_off_outlined),
                _dato('Puestos abiertos ahora', d['puestos_abiertos'], Icons.storefront),
                _dato('Puestos activos', d['puestos_activos'], Icons.storefront_outlined),
                _dato('Publicaciones activas', d['productos_activos'], Icons.inventory_2_outlined),
                _dato('Publicaciones ocultas', d['productos_ocultos'], Icons.visibility_off_outlined),
                _dato('Tianguis activos', d['tianguis_activos'], Icons.map_outlined, onTap: () => widget.ir(3)),
              ]),
              const SizedBox(height: 20),
              Text('Medidas activas (${medidas.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (medidas.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(20), child: Center(child: Text('No hay medidas activas')))
              else
                for (final m in medidas) ...[_medida(m), const SizedBox(height: 8)],
            ]),
          );
        },
      );
}

// ======================= Reportes (RF-50) =======================

class _ReportesTab extends StatefulWidget {
  const _ReportesTab();
  @override
  State<_ReportesTab> createState() => _ReportesTabState();
}

class _ReportesTabState extends State<_ReportesTab> {
  final _svc = AdminService();
  bool _soloPendientes = true;
  late Future<List<Map<String, dynamic>>> _futuro = _svc.reportes();

  Future<void> _recargar() async {
    setState(() {
      _futuro = _svc.reportes(soloPendientes: _soloPendientes);
    });
    await _futuro.catchError((_) => <Map<String, dynamic>>[]);
  }

  static const _acciones = <(String, String?)>[
    ('Mantener (sin medida)', null),
    ('Advertencia al usuario', 'advertencia'),
    ('Ocultar contenido', 'ocultar_contenido'),
    ('Retirar contenido', 'retirar_contenido'),
    ('Suspender cuenta', 'suspender_cuenta'),
  ];

  Future<void> _abrir(Map<String, dynamic> r) async {
    final resuelto = r['estado'] == 'resuelto';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reporte de ${r['tipo_objetivo']}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Reporta: ${r['reportante_nombre']}\nReportado: ${r['reportado_nombre']}\n'
                '${_fecha(r['creado_en'])}'),
            const SizedBox(height: 8),
            Text('Motivo: ${r['motivo']}'),
            if ('${r['contenido'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Contenido reportado',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                child: Text('${r['contenido']}'),
              ),
            ],
            if (resuelto) ...[
              const Divider(height: 28),
              Text('Resuelto: ${r['decision'] ?? ''}'),
            ] else ...[
              const Divider(height: 28),
              const Text('Decisión', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final a in _acciones)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a.$2 == null ? Icons.check_circle_outline : Icons.report_gmailerrorred),
                  title: Text(a.$1),
                  onTap: () async {
                    final motivo = await _pedirTexto(
                        ctx,
                        a.$2 == null ? 'Motivo para mantenerlo' : 'Motivo (lo verá el usuario)',
                        'Motivo general');
                    if (motivo == null) return;
                    try {
                      await _svc.resolverReporte(r, medida: a.$2, decision: motivo);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        _aviso(context, 'Reporte resuelto');
                        _recargar();
                      }
                    } catch (e) {
                      if (mounted) _aviso(context, 'No se pudo resolver: $e');
                    }
                  },
                ),
            ],
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Solo pendientes'),
              selected: _soloPendientes,
              onSelected: (v) {
                _soloPendientes = v;
                _recargar();
              },
            ),
          ),
        ),
        Expanded(
          child: _ListaAsync(
            futuro: _futuro,
            onRecargar: _recargar,
            vacio: 'No hay reportes',
            item: (r) => Card(
              child: ListTile(
                leading: Icon(r['estado'] == 'resuelto' ? Icons.check_circle : Icons.flag,
                    color: r['estado'] == 'resuelto' ? Tg.verde : Tg.rojo),
                title: Text('${r['tipo_objetivo']} · ${r['reportado_nombre']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '${r['motivo']}'
                    '${'${r['contenido'] ?? ''}'.isEmpty ? '' : '\n» ${r['contenido']}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _abrir(r),
              ),
            ),
          ),
        ),
      ]);
}

// ======================= Apelaciones (RF-51) =======================

class _ApelacionesTab extends StatefulWidget {
  const _ApelacionesTab();
  @override
  State<_ApelacionesTab> createState() => _ApelacionesTabState();
}

class _ApelacionesTabState extends State<_ApelacionesTab> {
  final _svc = AdminService();
  bool _soloPendientes = true;
  late Future<List<Map<String, dynamic>>> _futuro = _svc.apelaciones();

  Future<void> _recargar() async {
    setState(() {
      _futuro = _svc.apelaciones(soloPendientes: _soloPendientes);
    });
    await _futuro.catchError((_) => <Map<String, dynamic>>[]);
  }

  static const _opciones = <(String, String, String)>[
    ('mantenida', 'Mantener la medida', 'La medida original se queda igual'),
    ('modificada', 'Modificar la medida', 'Se ajusta; explícalo en el comentario'),
    ('revertida', 'Revertir la medida', 'Se desactiva y se restaura contenido o cuenta'),
  ];

  Future<void> _resolver(Map<String, dynamic> a) async {
    if (a['estado'] == 'resuelta') {
      _aviso(context, 'Resuelta: ${a['resolucion']} · ${a['comentario_resolucion'] ?? ''}');
      return;
    }
    final resolucion = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Resolver apelación'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('${a['usuario_nombre']}: ${a['motivo']}'),
          ),
          for (final o in _opciones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, o.$1),
              child: ListTile(
                  dense: true, contentPadding: EdgeInsets.zero, title: Text(o.$2), subtitle: Text(o.$3)),
            ),
        ],
      ),
    );
    if (resolucion == null || !mounted) return;
    final comentario = await _pedirTexto(context, 'Comentario para el usuario', 'Explica la decisión');
    if (comentario == null) return;
    try {
      await _svc.resolverApelacion(a, resolucion: resolucion, comentario: comentario);
      if (mounted) {
        _aviso(context, 'Apelación resuelta');
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo resolver: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Solo pendientes'),
              selected: _soloPendientes,
              onSelected: (v) {
                _soloPendientes = v;
                _recargar();
              },
            ),
          ),
        ),
        Expanded(
          child: _ListaAsync(
            futuro: _futuro,
            onRecargar: _recargar,
            vacio: 'No hay apelaciones',
            item: (a) {
              final tipo = a['id_medida'] != null
                  ? 'medida'
                  : a['id_reporte'] != null
                      ? 'reporte'
                      : 'calificación';
              return Card(
                child: ListTile(
                  leading: Icon(a['estado'] == 'resuelta' ? Icons.check_circle : Icons.gavel,
                      color: a['estado'] == 'resuelta' ? Tg.verde : Tg.naranja),
                  title: Text('${a['usuario_nombre']} · $tipo',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${a['motivo']}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Text(_fecha(a['creada_en']).split(' ').first),
                  onTap: () => _resolver(a),
                ),
              );
            },
          ),
        ),
      ]);
}

// ======================= Tianguis (RF-47, RF-48, RF-49) =======================

class _TianguisTab extends StatefulWidget {
  const _TianguisTab();
  @override
  State<_TianguisTab> createState() => _TianguisTabState();
}

class _TianguisTabState extends State<_TianguisTab> {
  final _svc = AdminService();
  late Future<List<Map<String, dynamic>>> _futuro = _svc.tianguis();

  Future<void> _recargar() async {
    setState(() {
      _futuro = _svc.tianguis();
    });
    await _futuro.catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _abrir([Map<String, dynamic>? t]) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => _TianguisForm(tianguis: t)));
    _recargar();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        _ListaAsync(
          futuro: _futuro,
          onRecargar: _recargar,
          vacio: 'No hay tianguis registrados',
          item: (t) => Card(
            child: ListTile(
              leading: Icon(Icons.storefront, color: t['activo'] == true ? Tg.verde : Colors.grey),
              title: Text('${t['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t['activo'] == true
                  ? '${t['direccion'] ?? 'Sin dirección'}'
                  : 'Desactivado · ${t['direccion'] ?? ''}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrir(t),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _abrir(),
            icon: const Icon(Icons.add),
            label: const Text('Tianguis'),
          ),
        ),
      ]);
}

class _TianguisForm extends StatefulWidget {
  final Map<String, dynamic>? tianguis;
  const _TianguisForm({this.tianguis});
  @override
  State<_TianguisForm> createState() => _TianguisFormState();
}

class _TianguisFormState extends State<_TianguisForm> {
  static const _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  final _svc = AdminService();
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _id;
  bool _activo = true, _guardando = false;
  List<Map<String, dynamic>> _horarios = [], _zonas = [];

  @override
  void initState() {
    super.initState();
    final t = widget.tianguis;
    if (t != null) {
      _id = t['id'] as String;
      _nombre.text = '${t['nombre'] ?? ''}';
      _descripcion.text = '${t['descripcion'] ?? ''}';
      _direccion.text = '${t['direccion'] ?? ''}';
      _lat.text = t['latitud'] == null ? '' : '${t['latitud']}';
      _lng.text = t['longitud'] == null ? '' : '${t['longitud']}';
      _activo = t['activo'] != false;
      _cargarHijos();
    }
  }

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _direccion, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarHijos() async {
    final id = _id;
    if (id == null) return;
    try {
      final h = await _svc.horarios(id);
      final z = await _svc.zonas(id);
      if (mounted) {
        setState(() {
          _horarios = h;
          _zonas = z;
        });
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudieron cargar horarios y zonas: $e');
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return _aviso(context, 'Escribe el nombre del tianguis');
    final latTxt = _lat.text.trim(), lngTxt = _lng.text.trim();
    final lat = latTxt.isEmpty ? null : Entradas.leerCoordenada(latTxt, max: 90);
    final lng = lngTxt.isEmpty ? null : Entradas.leerCoordenada(lngTxt, max: 180);
    if ((latTxt.isNotEmpty && lat == null) || (lngTxt.isNotEmpty && lng == null)) {
      return _aviso(context, 'Latitud (-90 a 90) y longitud (-180 a 180) deben ser números válidos');
    }
    if ((lat == null) != (lng == null)) {
      return _aviso(context, 'Captura latitud y longitud juntas, o deja ambas vacías');
    }
    setState(() => _guardando = true);
    try {
      final nuevo = _id == null;
      _id = await _svc.guardarTianguis(_id, {
        'nombre': nombre,
        'descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'direccion': _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        'latitud': lat,
        'longitud': lng,
        'activo': _activo,
      });
      if (!mounted) return;
      _aviso(context, nuevo ? 'Tianguis creado. Ahora agrega horarios y zonas.' : 'Cambios guardados');
      setState(() {});
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregarHorario() async {
    final id = _id;
    if (id == null) return;
    var dia = 0;
    var inicio = const TimeOfDay(hour: 8, minute: 0);
    var fin = const TimeOfDay(hour: 15, minute: 0);
    String fmt(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Horario general'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: dia,
              items: [for (var i = 0; i < 7; i++) DropdownMenuItem(value: i, child: Text(_dias[i]))],
              onChanged: (v) => set(() => dia = v ?? dia),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Abre: ${inicio.format(ctx)}'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: inicio);
                if (t != null) set(() => inicio = t);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Cierra: ${fin.format(ctx)}'),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: fin);
                if (t != null) set(() => fin = t);
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('AGREGAR')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (fmt(fin).compareTo(fmt(inicio)) <= 0) {
      if (mounted) _aviso(context, 'La hora de cierre debe ser después de la de apertura');
      return;
    }
    try {
      await _svc.agregarHorario(id, dia, fmt(inicio), fmt(fin));
      await _cargarHijos();
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo agregar: $e');
    }
  }

  Future<void> _agregarZona() async {
    final id = _id;
    if (id == null) return;
    final nombre = TextEditingController();
    final geo = TextEditingController();
    var tipo = 'zona';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Zona, pasillo o espacio'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nombre, decoration: const InputDecoration(hintText: 'Nombre')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tipo,
                items: const [
                  DropdownMenuItem(value: 'zona', child: Text('Zona')),
                  DropdownMenuItem(value: 'pasillo', child: Text('Pasillo')),
                  DropdownMenuItem(value: 'espacio', child: Text('Espacio')),
                ],
                onChanged: (v) => set(() => tipo = v ?? tipo),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: geo,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(hintText: 'Geometría GeoJSON (opcional)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('AGREGAR')),
          ],
        ),
      ),
    );
    final n = nombre.text.trim();
    final g = geo.text.trim();
    nombre.dispose();
    geo.dispose();
    if (ok != true) return;
    if (n.isEmpty) return _aviso(context, 'Escribe el nombre');
    Object? geometria;
    if (g.isNotEmpty) {
      try {
        geometria = jsonDecode(g);
      } catch (_) {
        return _aviso(context, 'La geometría no es un JSON válido');
      }
    }
    try {
      await _svc.agregarZona(id, n, tipo, geometria: geometria, orden: _zonas.length);
      await _cargarHijos();
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo agregar: $e');
    }
  }

  Future<void> _borrar(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargarHijos();
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const negro = TextStyle(color: Colors.black);
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.tianguis == null && _id == null ? 'Nuevo tianguis' : 'Tianguis')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: _nombre,
              style: negro,
              inputFormatters: Entradas.texto(80),
              decoration: const InputDecoration(hintText: 'Nombre')),
          const SizedBox(height: 10),
          TextField(
              controller: _descripcion,
              style: negro,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Descripción')),
          const SizedBox(height: 10),
          TextField(
              controller: _direccion, style: negro, decoration: const InputDecoration(hintText: 'Dirección')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _lat,
                style: negro,
                inputFormatters: Entradas.formatoCoordenada,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(hintText: 'Latitud'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _lng,
                style: negro,
                inputFormatters: Entradas.formatoCoordenada,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(hintText: 'Longitud'),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo (visible en la app)'),
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
          ),
          FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'GUARDANDO…' : 'GUARDAR')),
          const SizedBox(height: 24),
          if (_id == null)
            const Text('Guarda el tianguis para poder agregar horarios y zonas.',
                style: TextStyle(color: Colors.white70))
          else ...[
            Row(children: [
              const Expanded(
                  child: Text('Horarios generales',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton.icon(
                  onPressed: _agregarHorario, icon: const Icon(Icons.add), label: const Text('Agregar')),
            ]),
            if (_horarios.isEmpty) const Text('Sin horarios'),
            for (final h in _horarios)
              Card(
                child: ListTile(
                  title: Text(_dias[(h['dia_semana'] as num).toInt() % 7]),
                  subtitle: Text(
                      '${'${h['hora_inicio']}'.substring(0, 5)} – ${'${h['hora_fin']}'.substring(0, 5)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _borrar(() => _svc.eliminarHorario(h['id'] as String)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(
                  child: Text('Zonas, pasillos y espacios',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton.icon(
                  onPressed: _agregarZona, icon: const Icon(Icons.add), label: const Text('Agregar')),
            ]),
            if (_zonas.isEmpty) const Text('Sin zonas'),
            for (final z in _zonas)
              Card(
                child: ListTile(
                  title: Text('${z['nombre']}'),
                  subtitle: Text('${z['tipo']}${z['geometria'] == null ? '' : ' · con geometría'}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _borrar(() => _svc.eliminarZona(z['id'] as String)),
                  ),
                ),
              ),
          ],
        ]),
      ),
    );
  }
}

// ======================= Términos (RF-52) =======================

class _TerminosTab extends StatefulWidget {
  const _TerminosTab();
  @override
  State<_TerminosTab> createState() => _TerminosTabState();
}

class _TerminosTabState extends State<_TerminosTab> {
  final _svc = AdminService();
  late Future<List<Map<String, dynamic>>> _futuro = _svc.versiones();

  Future<void> _recargar() async {
    setState(() {
      _futuro = _svc.versiones();
    });
    await _futuro.catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _publicar() async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => const _PublicarVersion()));
    if (ok == true) _recargar();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        _ListaAsync(
          futuro: _futuro,
          onRecargar: _recargar,
          vacio: 'Aún no hay versiones publicadas',
          item: (v) => Card(
            child: ListTile(
              leading: Icon(v['tipo'] == 'privacidad' ? Icons.privacy_tip_outlined : Icons.description_outlined),
              title: Text(
                  '${v['tipo'] == 'privacidad' ? 'Aviso de privacidad' : 'Condiciones de uso'} · v${v['version']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${_fecha(v['publicado_en'])}'
                  '${v['requiere_reaceptacion'] == true ? ' · pide reaceptación' : ''}'),
              trailing: v['vigente'] == true
                  ? const Chip(label: Text('VIGENTE'))
                  : const Text('anterior'),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _publicar,
            icon: const Icon(Icons.publish),
            label: const Text('Publicar versión'),
          ),
        ),
      ]);
}

class _PublicarVersion extends StatefulWidget {
  const _PublicarVersion();
  @override
  State<_PublicarVersion> createState() => _PublicarVersionState();
}

class _PublicarVersionState extends State<_PublicarVersion> {
  final _svc = AdminService();
  final _version = TextEditingController();
  final _contenido = TextEditingController();
  String _tipo = 'terminos';
  bool _reacepta = true, _guardando = false;

  @override
  void dispose() {
    _version.dispose();
    _contenido.dispose();
    super.dispose();
  }

  Future<void> _publicar() async {
    if (_version.text.trim().isEmpty || _contenido.text.trim().isEmpty) {
      return _aviso(context, 'Escribe la versión y el contenido');
    }
    setState(() => _guardando = true);
    try {
      await _svc.publicarVersion(
        tipo: _tipo,
        version: _version.text.trim(),
        contenido: _contenido.text.trim(),
        requiereReaceptacion: _reacepta,
      );
      if (!mounted) return;
      _aviso(context, 'Versión publicada');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo publicar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const negro = TextStyle(color: Colors.black);
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Publicar versión')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          DropdownButtonFormField<String>(
            value: _tipo,
            items: const [
              DropdownMenuItem(value: 'terminos', child: Text('Condiciones de uso')),
              DropdownMenuItem(value: 'privacidad', child: Text('Aviso de privacidad')),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _version,
              style: negro,
              decoration: const InputDecoration(hintText: 'Versión (ej. 1.1)')),
          const SizedBox(height: 10),
          TextField(
            controller: _contenido,
            style: negro,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(hintText: 'Texto completo'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pedir que los usuarios la acepten de nuevo'),
            value: _reacepta,
            onChanged: (v) => setState(() => _reacepta = v),
          ),
          FilledButton(
              onPressed: _guardando ? null : _publicar,
              child: Text(_guardando ? 'PUBLICANDO…' : 'PUBLICAR')),
        ]),
      ),
    );
  }
}

// ======================= Consulta (RF-54) =======================

class _ConsultaTab extends StatefulWidget {
  const _ConsultaTab();
  @override
  State<_ConsultaTab> createState() => _ConsultaTabState();
}

class _ConsultaTabState extends State<_ConsultaTab> {
  static const _entidades = {
    'usuarios': 'Usuarios',
    'vendedores': 'Vendedores',
    'productos': 'Publicaciones',
    'puestos': 'Puestos',
    'calificaciones': 'Calificaciones',
    'anuncios': 'Anuncios de espacio',
    'ofertas': 'Ofertas',
  };
  final _svc = AdminService();
  final _texto = TextEditingController();
  String _entidad = 'usuarios';
  List<Map<String, dynamic>> _ultimos = [];
  bool _guardando = false;
  late Future<List<Map<String, dynamic>>> _futuro = _cargar();

  Future<List<Map<String, dynamic>>> _cargar() =>
      _svc.consultar(_entidad, _texto.text).then((l) => _ultimos = l);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _futuro = _cargar();
    });
    await _futuro.catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _cambiarEstado(Map<String, dynamic> u, String estado) async {
    setState(() => _guardando = true);
    try {
      await _svc.cambiarEstadoCuenta(u['id'] as String, estado);
      // La fila cambia de inmediato; enseguida se vuelve a pedir al servidor
      // para confirmar el estado real.
      final nuevos = [
        for (final x in _ultimos) x['id'] == u['id'] ? {...x, 'estado_cuenta': estado} : x
      ];
      _ultimos = nuevos;
      if (mounted) {
        setState(() {
      _futuro = Future.value(nuevos);
    });
        _aviso(context,
            '${u['nombre_publico']}: ${estado == 'suspendida' ? 'cuenta suspendida' : 'cuenta reactivada'}');
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo cambiar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Oculta/suspende o levanta la medida de un puesto, publicación o vendedor.
  Future<void> _moderar(String tipo, Map<String, dynamic> x, String nombre) async {
    final idMedida = x['medida_id'] as String?;
    final levantar = idMedida != null;
    final motivo = await _pedirTexto(
        context,
        levantar ? 'Motivo para levantar la medida' : 'Motivo (lo verá el usuario)',
        'Motivo general');
    if (motivo == null) return;
    setState(() => _guardando = true);
    try {
      if (levantar) {
        await _svc.levantarMedida(idMedida, motivo);
      } else {
        await _svc.aplicarMedida(tipoObjetivo: tipo, id: x['id'] as String, motivo: motivo);
      }
      if (mounted) {
        _aviso(context, levantar ? '$nombre: medida levantada' : '$nombre: medida aplicada');
        _recargar();
      }
    } catch (e) {
      if (mounted) _aviso(context, 'No se pudo completar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _menuMedida(String tipo, Map<String, dynamic> x, String nombre, String accion) {
    final hay = x['medida_id'] != null;
    return PopupMenuButton<String>(
      onSelected: (_) => _moderar(tipo, x, nombre),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'm', child: Text(hay ? 'Levantar medida' : accion)),
      ],
    );
  }

  Widget _fila(Map<String, dynamic> x) {
    switch (_entidad) {
      case 'usuarios':
        final suspendida = x['estado_cuenta'] != 'activa';
        return Card(
          child: ListTile(
            leading: Icon(suspendida ? Icons.block : Icons.person, color: suspendida ? Tg.rojo : null),
            title: Text('${x['nombre_publico']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${x['correo'] ?? 'sin correo'} · ${x['estado_cuenta']}'),
            trailing: PopupMenuButton<String>(
              onSelected: (e) => _cambiarEstado(x, e),
              itemBuilder: (_) => [
                if (!suspendida)
                  const PopupMenuItem(value: 'suspendida', child: Text('Suspender cuenta')),
                if (suspendida) const PopupMenuItem(value: 'activa', child: Text('Reactivar cuenta')),
              ],
            ),
          ),
        );
      case 'vendedores':
        final u = x['usuarios'] as Map?;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.store_mall_directory),
            title: Text('${x['nombre_negocio'] ?? u?['nombre_publico'] ?? 'Sin nombre'}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${u?['nombre_publico'] ?? ''} · ${u?['correo'] ?? 'sin correo'} · '
                '${u?['estado_cuenta'] ?? ''}'
                '${x['estado'] == 'suspendido' ? ' · perfil suspendido' : ''}'),
            trailing: _menuMedida('vendedor', x,
                '${x['nombre_negocio'] ?? u?['nombre_publico'] ?? 'Vendedor'}', 'Suspender perfil de vendedor'),
          ),
        );
      case 'productos':
        final p = x['puestos'] as Map?;
        return Card(
          child: ListTile(
            leading: Icon(x['moderado'] == true ? Icons.visibility_off : Icons.inventory_2_outlined),
            title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${p?['nombre'] ?? 'Sin puesto'}'
                '${x['precio_referencia'] == null ? '' : ' · \$${x['precio_referencia']}'}'
                '${x['moderado'] == true ? ' · oculto por moderación' : ''}'
                '${x['activo'] == false ? ' · retirado' : ''}'),
            trailing: _menuMedida('producto', x, '${x['nombre']}', 'Ocultar publicación'),
          ),
        );
      case 'calificaciones':
      case 'anuncios':
      case 'ofertas':
        final mod = x['moderado'] == true;
        final tipoMod = _entidad == 'calificaciones'
            ? 'calificacion'
            : _entidad == 'anuncios'
                ? 'anuncio_espacio'
                : 'oferta';
        final accionMod = _entidad == 'calificaciones'
            ? 'Ocultar calificación'
            : _entidad == 'anuncios'
                ? 'Ocultar anuncio'
                : 'Cancelar oferta';
        return Card(
          child: ListTile(
            isThreeLine: true,
            leading: Icon(mod ? Icons.visibility_off : Icons.article_outlined, color: mod ? Tg.rojo : null),
            title: Text('${x['titulo'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${x['usuario_nombre'] ?? '—'} · ${_fecha(x['fecha'])}\n'
                '${x['detalle'] ?? ''}${mod ? ' · oculto por moderación' : ''}',
                maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: _menuMedida(tipoMod, x, '${x['titulo'] ?? ''}', accionMod),
          ),
        );
      default:
        final t = x['tianguis'] as Map?;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.storefront),
            title: Text('${x['nombre']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${t?['nombre'] ?? ''} · ${x['estado']}${x['activo'] == false ? ' · inactivo' : ''}'),
            trailing: _menuMedida('puesto', x, '${x['nombre']}', 'Desactivar puesto'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (_guardando) const LinearProgressIndicator(color: Tg.amarillo),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _texto,
            style: const TextStyle(color: Colors.black),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _recargar(),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre…',
              prefixIcon: const Icon(Icons.search, color: Tg.azul),
              suffixIcon:
                  IconButton(icon: const Icon(Icons.arrow_forward, color: Tg.azul), onPressed: _recargar),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), children: [
            for (final e in _entidades.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _entidad == e.key,
                  onSelected: (_) {
                    _entidad = e.key;
                    _recargar();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: _ListaAsync(
            futuro: _futuro,
            onRecargar: _recargar,
            vacio: 'Sin resultados',
            item: _fila,
          ),
        ),
      ]);
}
