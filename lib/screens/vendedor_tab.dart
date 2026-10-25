import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';

/// RF-19, RF-20, RF-27, RF-28, RF-41: panel del vendedor.
class VendedorTab extends StatefulWidget {
  const VendedorTab({super.key});
  @override
  State<VendedorTab> createState() => _VendedorTabState();
}

class _VendedorTabState extends State<VendedorTab> {
  final _svc = VendedorService();
  Map<String, dynamic>? _perfil;
  List<Puesto> _puestos = [];
  bool _cargando = true;

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
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _habilitar() async {
    try {
      await _svc.habilitarPerfil();
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _nuevoPuesto() async {
    final tianguis = await CatalogoService().tianguis();
    if (!mounted || tianguis.isEmpty) return _msg('No hay tianguis registrados');
    final nombre = TextEditingController();
    String sel = tianguis.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Nuevo puesto'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nombre, decoration: const InputDecoration(hintText: 'Nombre del puesto'), style: const TextStyle(color: Colors.black)),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: sel, isExpanded: true,
              items: [for (final t in tianguis) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
              onChanged: (v) => set(() => sel = v!),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true || nombre.text.trim().isEmpty) return;
    try {
      final id = _perfil!['id'] as String;
      // RF-20: se asocia el tianguis (ignora si ya existía)
      try { await _svc.agregarTianguis(id, sel); } catch (_) {}
      await _svc.crearPuesto(id, sel, nombre.text.trim());
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_perfil == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('¿Tienes un puesto en el tianguis?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _habilitar, child: const Text('HABILITAR PERFIL DE VENDEDOR')),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoPuesto, icon: const Icon(Icons.add), label: const Text('Puesto'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          if (_puestos.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Aún no tienes puestos. Crea uno con el botón +.')),
          for (final p in _puestos)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.circle, size: 14, color: p.abierto ? Tg.verde : Colors.grey),
                    const SizedBox(width: 8),
                    Text(p.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(p.abierto ? 'ABIERTO' : 'CERRADO'),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: p.abierto ? Tg.rojo : Tg.amarillo,
                        foregroundColor: p.abierto ? Colors.white : Tg.azulOscuro),
                    onPressed: () => _alternar(p),
                    child: Text(p.abierto ? 'CERRAR PUESTO' : 'YA LLEGUÉ · ABRIR'),
                  ),
                  if (p.abierto)
                    TextButton.icon(onPressed: () => _codigo(p), icon: const Icon(Icons.qr_code), label: const Text('Generar código de visita')),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
