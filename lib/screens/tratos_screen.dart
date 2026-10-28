import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/estados.dart';
import '../config/theme.dart';
import '../models/tratos.dart';
import '../services/tratos_service.dart';
import '../widgets/entradas.dart';

/// Bandeja de propuestas de precio y apartados (RF-17, 18, 31, 32).
/// [idVendedor] != null → lo que recibe el vendedor; null → lo que envié como comprador.
class TratosScreen extends StatefulWidget {
  final String? idVendedor;
  const TratosScreen({super.key, this.idVendedor});
  @override
  State<TratosScreen> createState() => _TratosScreenState();
}

class _TratosScreenState extends State<TratosScreen> {
  final _svc = TratosService();
  final _yo = Supabase.instance.client.auth.currentUser!.id;
  late Future<List<Propuesta>> _props;
  late Future<List<Apartado>> _aps;

  bool get _comoVendedor => widget.idVendedor != null;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  void _iniciar() {
    // primero se vencen los pendientes pasados de fecha, luego se listan
    final v = _svc.vencer();
    _props = v.then((_) => _svc.propuestas(idVendedor: widget.idVendedor));
    _aps = v.then((_) => _svc.apartados(idVendedor: widget.idVendedor));
  }

  void _recargar() {
    setState(() {
      _iniciar();
    });
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  String _error(Object e) => e is PostgrestException ? e.message : '$e';

  Future<void> _hacer(Future<void> Function() accion, String ok) async {
    try {
      await accion();
      if (mounted) _msg(ok);
    } catch (e) {
      if (mounted) _msg(_error(e));
    }
    if (mounted) _recargar();
  }

  Future<void> _contraofertar(Propuesta p) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contraoferta'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: Entradas.formatoDinero,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
              hintText: p.precioRef == null ? 'Monto en pesos' : 'Monto (precio: \$${p.precioRef})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    final monto = Entradas.leerDinero(c.text);
    if (monto == null || monto <= 0) return _msg('Escribe un monto válido (solo números, mayor a 0)');
    await _hacer(() => _svc.contraofertar(p.id, monto), 'Contraoferta enviada');
  }

  Future<bool> _confirmar(String titulo, String texto) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    return r == true;
  }

  // ---- piezas de interfaz ----

  ({String texto, Color color}) _chip(String estado) {
    switch (estado) {
      case Est.pendiente:
        return (texto: 'PENDIENTE', color: Tg.naranja);
      case Est.propAceptada:
      case Est.apAceptado:
        return (texto: 'ACEPTADA', color: Tg.verde);
      case Est.propRechazada:
      case Est.apRechazado:
        return (texto: 'RECHAZADA', color: Tg.rojo);
      case Est.propContra:
        return (texto: 'CONTRAOFERTADA', color: Tg.azulClaro);
      case Est.apCancelado:
        return (texto: 'CANCELADO', color: Colors.grey);
      case Est.apExpirado:
        return (texto: 'VENCIDO', color: Colors.grey);
      default:
        return (texto: estado.toUpperCase(), color: Colors.grey);
    }
  }

  Widget _etiqueta(String estado) {
    final c = _chip(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.color, borderRadius: BorderRadius.circular(10)),
      child: Text(c.texto,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _boton(String texto, VoidCallback onPressed, {Color? color, Color? texto2}) => FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: color,
          foregroundColor: texto2,
        ),
        onPressed: onPressed,
        child: Text(texto),
      );

  Widget _tarjeta({
    required String titulo,
    required String estado,
    required List<String> lineas,
    List<Widget> acciones = const [],
    bool atenuada = false,
  }) =>
      Opacity(
        opacity: atenuada ? 0.6 : 1,
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(titulo,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                _etiqueta(estado),
              ]),
              const SizedBox(height: 6),
              for (final l in lineas) Text(l, style: const TextStyle(fontSize: 15)),
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: acciones),
              ],
            ]),
          ),
        ),
      );

  Widget _tarjetaPropuesta(Propuesta p) {
    final otro = _comoVendedor ? p.compradorNombre : p.vendedorNombre;
    final yoEnvie = p.idEmisor == _yo;
    final puedoResponder = p.pendiente && !yoEnvie;
    return _tarjeta(
      titulo: p.productoNombre ?? 'Producto',
      estado: p.estado,
      atenuada: p.estado == Est.propContra,
      lineas: [
        '${yoEnvie ? 'Tú ofreciste' : (p.esContraoferta ? 'Contraoferta de' : 'Te ofrece')}: '
            '\$${p.monto}${p.precioRef != null ? '  (precio \$${p.precioRef})' : ''}',
        if (otro != null) '${_comoVendedor ? 'Comprador' : 'Vendedor'}: $otro',
        fmtFecha(p.creada),
        if (p.pendiente && yoEnvie) 'Esperando respuesta…',
      ],
      acciones: puedoResponder
          ? [
              _boton('Aceptar', () => _hacer(() => _svc.aceptarPropuesta(p.id), 'Propuesta aceptada'),
                  color: Tg.verde, texto2: Colors.white),
              _boton('Contraofertar', () => _contraofertar(p)),
              _boton('Rechazar', () => _hacer(() => _svc.rechazarPropuesta(p.id), 'Propuesta rechazada'),
                  color: Tg.rojo, texto2: Colors.white),
            ]
          : const [],
    );
  }

  Widget _tarjetaApartado(Apartado a) {
    final otro = _comoVendedor ? a.compradorNombre : a.vendedorNombre;
    final acciones = <Widget>[];
    if (_comoVendedor && a.pendiente) {
      acciones.addAll([
        _boton('Aceptar', () => _hacer(() => _svc.aceptarApartado(a.id), 'Apartado aceptado'),
            color: Tg.verde, texto2: Colors.white),
        _boton('Rechazar', () => _hacer(() => _svc.rechazarApartado(a.id), 'Apartado rechazado'),
            color: Tg.rojo, texto2: Colors.white),
      ]);
    }
    final puedeCancelar = _comoVendedor ? a.aceptado : (a.pendiente || a.aceptado);
    if (puedeCancelar) {
      acciones.add(_boton('Cancelar apartado', () async {
        if (await _confirmar('¿Cancelar apartado?',
            a.aceptado ? 'Las piezas apartadas volverán a quedar disponibles.' : 'Se cancelará la solicitud.')) {
          await _hacer(() => _svc.cancelarApartado(a.id), 'Apartado cancelado');
        }
      }));
    }
    return _tarjeta(
      titulo: a.productoNombre ?? 'Producto',
      estado: a.estado,
      lineas: [
        'Cantidad: ${a.cantidad}',
        if (otro != null) '${_comoVendedor ? 'Comprador' : 'Vendedor'}: $otro',
        if (a.expira != null && (a.pendiente || a.aceptado)) 'Vence: ${fmtFecha(a.expira)}',
        if (!_comoVendedor && a.aceptado) 'Pasa por él antes de que venza. El pago es directo con el vendedor.',
      ],
      acciones: acciones,
    );
  }

  Widget _lista<T>(Future<List<T>> futuro, Widget Function(T) tarjeta, String vacio) =>
      RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: FutureBuilder<List<T>>(
          future: futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
            }
            if (s.hasError) {
              return ListView(children: [
                Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${s.error}')),
              ]);
            }
            final l = s.data!;
            if (l.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(child: Text(vacio)),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 30),
              itemCount: l.length,
              itemBuilder: (_, i) => tarjeta(l[i]),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_comoVendedor ? 'Propuestas y apartados' : 'Mis propuestas y apartados'),
            bottom: const TabBar(
              indicatorColor: Tg.amarillo,
              tabs: [Tab(text: 'Propuestas'), Tab(text: 'Apartados')],
            ),
          ),
          body: TabBarView(children: [
            _lista<Propuesta>(_props, _tarjetaPropuesta,
                _comoVendedor ? 'Aún no te llegan propuestas' : 'Aún no has enviado propuestas'),
            _lista<Apartado>(_aps, _tarjetaApartado,
                _comoVendedor ? 'Aún no te llegan apartados' : 'Aún no has solicitado apartados'),
          ]),
        ),
      );
}
