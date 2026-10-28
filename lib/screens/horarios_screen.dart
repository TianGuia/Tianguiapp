import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';
import '../widgets/entradas.dart';

/// RF-21 y RF-22: horario habitual y ausencias programadas del vendedor.
class HorariosScreen extends StatefulWidget {
  final String idVendedor;

  /// id de tianguis -> nombre del puesto (se usa para elegir el tianguis).
  final Map<String, String> tianguis;
  const HorariosScreen({super.key, required this.idVendedor, required this.tianguis});
  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  static const _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  final _svc = VendedorService();
  List<Map<String, dynamic>> _horarios = [], _ausencias = [];
  Map<String, String> _nombres = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _cargar() async {
    try {
      final h = await _svc.horarios(widget.idVendedor);
      final a = await _svc.ausencias(widget.idVendedor);
      final t = await CatalogoService().tianguis();
      if (mounted) {
        setState(() {
          _horarios = h;
          _ausencias = a;
          _nombres = {for (final x in t) x.id: x.nombre};
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _cargando = false); _msg('$e'); }
    }
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _tianguisDe(Map<String, dynamic> f) => _nombres[f['id_tianguis']] ?? '';

  Future<String?> _elegirTianguis() async {
    if (widget.tianguis.isEmpty) {
      _msg('Primero crea un puesto en un tianguis');
      return null;
    }
    if (widget.tianguis.length == 1) return widget.tianguis.keys.first;
    return showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('¿En qué tianguis?'),
        children: [
          for (final e in widget.tianguis.entries)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, e.key), child: Text(_nombres[e.key] ?? 'Tianguis de ${e.value}')),
        ],
      ),
    );
  }

  Future<void> _agregarHorario() async {
    final idT = await _elegirTianguis();
    if (idT == null || !mounted) return;
    int dia = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, set) => AlertDialog(
          title: const Text('Día de operación'),
          content: DropdownButton<int>(
            value: dia,
            isExpanded: true,
            items: [for (var i = 0; i < 7; i++) DropdownMenuItem(value: i, child: Text(_dias[i]))],
            onChanged: (v) => set(() => dia = v ?? 0),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Siguiente')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final ini = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), helpText: 'HORA DE LLEGADA');
    if (ini == null || !mounted) return;
    final fin = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 15, minute: 0), helpText: 'HORA DE CIERRE');
    if (fin == null) return;
    try {
      await _svc.agregarHorario(widget.idVendedor, idT, dia, _hhmm(ini), _hhmm(fin));
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _agregarAusencia() async {
    final idT = await _elegirTianguis();
    if (idT == null || !mounted) return;
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: hoy.add(const Duration(days: 1)),
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 365)),
      helpText: 'DÍA QUE NO ASISTIRÉ',
    );
    if (fecha == null || !mounted) return;
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motivo (opcional)'),
        content: TextField(controller: motivo, maxLength: 80, decoration: const InputDecoration(hintText: 'Vacaciones, lluvia…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.registrarAusencia(widget.idVendedor, idT, fecha,
          motivo: motivo.text.trim().isEmpty ? null : motivo.text.trim());
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  Future<void> _borrar(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargar();
    } catch (e) {
      _msg('$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Horario y ausencias')),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: Tg.amarillo))
            : ListView(padding: const EdgeInsets.all(14), children: [
                Text('Horario habitual', style: Tg.marcador(18)),
                const SizedBox(height: 6),
                if (_horarios.isEmpty) const Text('Aún no registras horarios'),
                for (final h in _horarios)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule, color: Tg.amarillo),
                      title: Text(_dias[(h['dia_semana'] as num).toInt() % 7]),
                      subtitle: Text('${(h['hora_inicio'] as String).substring(0, 5)} – '
                          '${(h['hora_fin'] as String).substring(0, 5)}  ${_tianguisDe(h)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _borrar(() => _svc.eliminarHorario(h['id'])),
                      ),
                    ),
                  ),
                TextButton.icon(
                    onPressed: _agregarHorario, icon: const Icon(Icons.add), label: const Text('Agregar horario')),
                const SizedBox(height: 18),
                Text('Ausencias programadas', style: Tg.marcador(18)),
                const SizedBox(height: 6),
                if (_ausencias.isEmpty) const Text('No tienes ausencias próximas'),
                for (final a in _ausencias)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_busy, color: Tg.rosa),
                      title: Text('${a['fecha']}'),
                      subtitle: Text([_tianguisDe(a), if ((a['motivo'] ?? '') != '') a['motivo']].join(' · ')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _borrar(() => _svc.eliminarAusencia(a['id'])),
                      ),
                    ),
                  ),
                TextButton.icon(
                    onPressed: _agregarAusencia, icon: const Icon(Icons.add), label: const Text('Avisar ausencia')),
              ]),
      );
}
