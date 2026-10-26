import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/auth_service.dart';
import '../services/tratos_service.dart';
import '../services/vendedor_service.dart';
import 'mis_productos_screen.dart';
import 'ofertas_screen.dart';
import 'puesto_form_screen.dart';
import 'tratos_screen.dart';
import 'verificar_contacto_screen.dart';

/// RF-19, RF-20, RF-27, RF-28, RF-41: panel del vendedor.
class VendedorTab extends StatefulWidget {
  const VendedorTab({super.key});
  @override
  State<VendedorTab> createState() => _VendedorTabState();
}

enum _Accion { editar, temporal, indefinido, eliminar }

class _VendedorTabState extends State<VendedorTab> {
  final _svc = VendedorService();
  Map<String, dynamic>? _perfil;
  List<Puesto> _puestos = [];
  bool _cargando = true;
  int _pendientes = 0; // propuestas y apartados por atender

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      _perfil = await _svc.miPerfil();
      _puestos = _perfil == null ? [] : await _svc.misPuestos(_perfil!['id']);
    } catch (e) {
      _msg('$e');
    }
    try {
      _pendientes = _perfil == null ? 0 : await TratosService().pendientes(_perfil!['id'] as String);
    } catch (_) {
      _pendientes = 0; // el número simplemente no se muestra
    }
    if (mounted) setState(() => _cargando = false);
  }

  /// Abre una pantalla y, al volver, refresca el contador de pendientes.
  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar();
  }

  Future<void> _habilitar() async {
    try {
      // RF-19: para vender hay que verificar el correo (la cuenta anónima se liga).
      if (AuthService().esAnonimo) {
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const VerificarContactoScreen()),
        );
        if (ok != true) return;
      }
      await _svc.habilitarPerfil();
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _abrirFormulario({Puesto? puesto}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PuestoFormScreen(idVendedor: _perfil!['id'] as String, puesto: puesto),
      ),
    );
    if (ok == true) await _cargar();
  }

  Future<void> _alternar(Puesto p) async {
    try {
      if (p.abierto) {
        await _svc.cerrarPuesto(p.id);
      } else {
        await _svc.abrirPuesto(p.id);
      }
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _codigo(Puesto p) async {
    try {
      final c = await _svc.generarCodigoVisita(p.id);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Código de visita'),
          content: Text('${c['codigo']}\n\nVálido hasta ${DateTime.parse(c['expira_en']).toLocal().toString().substring(11, 16)}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        ),
      );
    } catch (e) {
      _msg('$e');
    }
  }

  // ---- Cierres con aviso y eliminación ----

  /// Pide motivo (y fecha de regreso si es temporal). Devuelve null si cancela.
  Future<({String? motivo, DateTime? fecha})?> _preguntarCierre(Puesto p, {required bool temporal}) {
    final motivo = TextEditingController();
    DateTime? fecha;
    return showDialog<({String? motivo, DateTime? fecha})>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(temporal ? 'Cerrar temporalmente' : 'Cerrar hasta nuevo aviso'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(temporal
                ? 'Los compradores verán "${p.nombre}" como cerrado temporalmente.'
                : 'Los compradores verán "${p.nombre}" cerrado hasta nuevo aviso. '
                    'Lo abres cuando quieras con "YA LLEGUÉ · ABRIR".'),
            const SizedBox(height: 12),
            TextField(
              controller: motivo,
              style: const TextStyle(color: Colors.black),
              maxLength: 80,
              decoration: const InputDecoration(hintText: 'Motivo (opcional): vacaciones, lluvia…'),
            ),
            if (temporal)
              TextButton.icon(
                icon: const Icon(Icons.event),
                label: Text(fecha == null
                    ? 'Fecha en que regresas (opcional)'
                    : 'Regreso: ${fecha!.day.toString().padLeft(2, '0')}/${fecha!.month.toString().padLeft(2, '0')}/${fecha!.year}'),
                onPressed: () async {
                  final hoy = DateTime.now();
                  final f = await showDatePicker(
                    context: ctx,
                    initialDate: fecha ?? hoy.add(const Duration(days: 1)),
                    firstDate: hoy,
                    lastDate: hoy.add(const Duration(days: 365)),
                  );
                  if (f != null) set(() => fecha = f);
                },
              ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (motivo: motivo.text, fecha: fecha)),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(Puesto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar puesto?'),
        content: Text('"${p.nombre}" dejará de mostrarse a los compradores. '
            'Tus productos se conservan en tu catálogo, sin puesto asignado.\n\n'
            'Si solo te ausentas un tiempo, mejor usa "Cerrar temporalmente".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Tg.rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.eliminarPuesto(p.id);
      _msg('Puesto eliminado');
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _accion(_Accion a, Puesto p) async {
    try {
      switch (a) {
        case _Accion.editar:
          await _abrirFormulario(puesto: p);
        case _Accion.temporal:
          final r = await _preguntarCierre(p, temporal: true);
          if (r == null) return;
          await _svc.cerrarTemporalmente(p.id, reabreEn: r.fecha, motivo: r.motivo);
          await _cargar();
        case _Accion.indefinido:
          final r = await _preguntarCierre(p, temporal: false);
          if (r == null) return;
          await _svc.cerrarHastaNuevoAviso(p.id, motivo: r.motivo);
          await _cargar();
        case _Accion.eliminar:
          await _confirmarEliminar(p);
      }
    } catch (e) {
      _msg('$e');
    }
  }

  Widget _tarjetaPuesto(Puesto p) {
    final cierreEspecial = !p.abierto && p.cierreTipo != null;
    final colorPunto = p.abierto ? Tg.verde : (cierreEspecial ? Tg.naranja : Colors.grey);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (p.fotoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(p.fotoUrl!, width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48)),
                ),
              ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(children: [
                  Icon(Icons.circle, size: 12, color: colorPunto),
                  const SizedBox(width: 6),
                  Flexible(child: Text(p.textoEstado, style: const TextStyle(fontSize: 13))),
                ]),
              ]),
            ),
            PopupMenuButton<_Accion>(
              tooltip: 'Opciones del puesto',
              onSelected: (a) => _accion(a, p),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Accion.editar, child: ListTile(leading: Icon(Icons.edit), title: Text('Editar puesto'))),
                PopupMenuItem(value: _Accion.temporal, child: ListTile(leading: Icon(Icons.schedule), title: Text('Cerrar temporalmente'))),
                PopupMenuItem(value: _Accion.indefinido, child: ListTile(leading: Icon(Icons.pause_circle_outline), title: Text('Cerrar hasta nuevo aviso'))),
                PopupMenuItem(value: _Accion.eliminar, child: ListTile(leading: Icon(Icons.delete_outline, color: Tg.rojo), title: Text('Eliminar puesto'))),
              ],
            ),
          ]),
          if ((p.descripcion ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(p.descripcion!, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          if (p.detalleCierre != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(p.detalleCierre!, style: const TextStyle(color: Tg.naranja, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: p.abierto ? Tg.rojo : Tg.amarillo,
                foregroundColor: p.abierto ? Colors.white : Tg.azulOscuro),
            onPressed: () => _alternar(p),
            child: Text(p.abierto ? 'CERRAR PUESTO' : 'YA LLEGUÉ · ABRIR'),
          ),
          if (p.abierto)
            TextButton.icon(
                onPressed: () => _codigo(p),
                icon: const Icon(Icons.qr_code),
                label: const Text('Generar código de visita')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_perfil == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('¿Tienes un puesto en el tianguis?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (AuthService().esAnonimo) ...[
              const SizedBox(height: 8),
              const Text('Te pediremos verificar tu correo para activar tu perfil de vendedor.',
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _habilitar, child: const Text('HABILITAR PERFIL DE VENDEDOR')),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(), icon: const Icon(Icons.add), label: const Text('Puesto'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          FilledButton.icon(
            onPressed: () => _ir(MisProductosScreen(idVendedor: _perfil!['id'] as String)),
            icon: const Icon(Icons.inventory_2),
            label: const Text('MIS PRODUCTOS'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _ir(TratosScreen(idVendedor: _perfil!['id'] as String)),
            icon: Badge(
              isLabelVisible: _pendientes > 0,
              backgroundColor: Tg.rosa,
              label: Text('$_pendientes'),
              child: const Icon(Icons.handshake_outlined),
            ),
            label: const Text('PROPUESTAS Y APARTADOS'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _ir(OfertasScreen(idVendedor: _perfil!['id'] as String)),
            icon: const Icon(Icons.bolt),
            label: const Text('OFERTAS RELÁMPAGO'),
          ),
          const SizedBox(height: 8),
          if (_puestos.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes puestos. Crea uno con el botón +.')),
          for (final p in _puestos) Padding(padding: const EdgeInsets.only(bottom: 8), child: _tarjetaPuesto(p)),
        ]),
      ),
    );
  }
}
