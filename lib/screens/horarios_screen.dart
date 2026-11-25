import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';
import '../widgets/mensaje.dart';

// RF-21 se cumple aqui: el vendedor guarda que dias y a que hora trabaja
// RF-22 se cumple aqui: el vendedor avisa con tiempo que un dia no va a ir
class HorariosScreen extends StatefulWidget {
  final String idVendedor;

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

  void _msg(String t) => mostrarMensaje(context, t);

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
      await _svc.registrarHorario(widget.idVendedor, idT, dia, _hhmm(ini), _hhmm(fin));
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
        content: TextField(controller: motivo, maxLength: 80, style: const TextStyle(color: Colors.black), decoration: const InputDecoration(hintText: 'Vacaciones, lluvia…')),
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
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Horario y ausencias')),
        body: _cargando
            ? const CargandoTg()
            : ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                CabeceraTg(
                  titulo: 'Tu horario',
                  subtitulo: 'Avísale a tu clientela cuándo te pones y cuándo no',
                  icono: Icons.schedule_rounded,
                  color: Tg.azulClaro,
                  datos: [
                    DatoTg(Icons.schedule, Tg.amarillo, '${_horarios.length}', 'HORARIOS'),
                    DatoTg(Icons.event_busy, Tg.rosa, '${_ausencias.length}', 'AUSENCIAS'),
                  ],
                ),
                const SeccionTg('Horario habitual'),
                if (_horarios.isEmpty)
                  const TarjetaTg(
                    acento: Tg.amarillo,
                    child: Text('Aún no registras horarios. Agrega los días y horas en que sueles ponerte.',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.15)),
                  ),
                for (final h in _horarios)
                  TarjetaTg(
                    acento: Tg.amarillo,
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(children: [
                      const SelloTg(icono: Icons.schedule, color: Tg.amarillo, tam: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_dias[(h['dia_semana'] as num).toInt() % 7],
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                          Text('${(h['hora_inicio'] as String).substring(0, 5)} – '
                              '${(h['hora_fin'] as String).substring(0, 5)}  ${_tianguisDe(h)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _borrar(() => _svc.eliminarHorario(h['id'])),
                      ),
                    ]),
                  ),
                Center(
                  child: TextButton.icon(
                      onPressed: _agregarHorario, icon: const Icon(Icons.add), label: const Text('Agregar horario')),
                ),
                const SeccionTg('Ausencias programadas'),
                if (_ausencias.isEmpty)
                  const TarjetaTg(
                    acento: Tg.rosa,
                    child: Text('No tienes ausencias próximas. Si vas a faltar, avísalo aquí y tu gente lo sabrá.',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.15)),
                  ),
                for (final a in _ausencias)
                  TarjetaTg(
                    acento: Tg.rosa,
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(children: [
                      const SelloTg(icono: Icons.event_busy, color: Tg.rosa, colorIcono: Colors.white, tam: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${a['fecha']}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
                          Text([_tianguisDe(a), if ((a['motivo'] ?? '') != '') a['motivo']].join(' · '),
                              style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
                        ]),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _borrar(() => _svc.eliminarAusencia(a['id'])),
                      ),
                    ]),
                  ),
                Center(
                  child: TextButton.icon(
                      onPressed: _agregarAusencia, icon: const Icon(Icons.add), label: const Text('Avisar ausencia')),
                ),
              ]),
      );
}
