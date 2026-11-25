import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/auth_service.dart';
import '../services/tratos_service.dart';
import '../services/vendedor_service.dart';
import 'horarios_screen.dart';
import 'mis_productos_screen.dart';
import 'ofertas_screen.dart';
import 'espacios_screen.dart';
import 'puesto_form_screen.dart';
import 'tratos_screen.dart';
import 'valoraciones_screen.dart';
import 'verificar_contacto_screen.dart';
import '../widgets/mensaje.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';

// aqui se cumplen rf-14, rf-15, rf-22, rf-23, rf-41, cada parte de abajo dice cual cumple
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

  void _msg(String t) => mostrarMensaje(context, t);

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
      _pendientes = 0; // el numero simplemente no se muestra
    }
    if (mounted) setState(() => _cargando = false);
  }

  // abre una pantalla y, al volver, refresca el contador de pendientes.
  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar();
  }

  Future<void> _habilitar() async {
    try {
      // rf-14 se cumple aqui: la persona activa su perfil de vendedor
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
        await _svc.marcarCerrado(p.id);
      } else {
        await _svc.marcarAbierto(p.id);
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
      final codigo = '${c['codigo']}';
      final hasta = DateTime.parse(c['expira_en']).toLocal().toString().substring(11, 16);
      showDialog(
        context: context,
        builder: (ctx) => DialogoTg(
          icono: Icons.qr_code_2,
          titulo: 'Código de visita',
          acciones: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('LISTO'))],
          child: Column(children: [
            const Text('Díctaselo al comprador para que confirme que está en tu puesto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, height: 1.15)),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final d in codigo.split(''))
                  Container(
                    width: 42,
                    height: 58,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Tg.amarillo, width: 2.5),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(2, 3), blurRadius: 0)],
                    ),
                    child: Text(d, style: Tg.marcador(32, color: Tg.azulOscuro)),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            PildoraTg('VÁLIDO HASTA LAS $hasta', color: Tg.amarillo, icono: Icons.schedule),
          ]),
        ),
      );
    } catch (e) {
      _msg('$e');
    }
  }

  // cierres con aviso y eliminacion

  // pide motivo y fecha de regreso si es temporal, null si cancela
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
            'También se retirarán sus productos y se terminarán sus ofertas activas. '
            'Las visitas y calificaciones se conservan.\n\n'
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

  Widget _bannerPuesto(Puesto p) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF123BB5), Tg.azulOscuro],
        ),
      ),
      child: const Center(child: Icon(Icons.storefront, size: 64, color: Colors.white24)),
    );
    return p.fotoUrl == null
        ? placeholder
        : Image.network(p.fotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder);
  }

  Widget _tarjetaPuesto(Puesto p) {
    final cierreEspecial = !p.abierto && p.cierreTipo != null;
    final colorEstado = p.abierto ? Tg.verde : (cierreEspecial ? Tg.naranja : Colors.grey.shade700);
    final radio = BorderRadius.circular(22);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        borderRadius: radio,
        boxShadow: const [BoxShadow(color: Color(0x59000000), offset: Offset(3, 4), blurRadius: 0)],
      ),
      child: Material(
        color: Tg.azulOscuro.withValues(alpha: 0.92),
        shape: RoundedRectangleBorder(
          borderRadius: radio,
          side: BorderSide(color: Tg.azulClaro.withValues(alpha: 0.5), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 130,
            child: Stack(fit: StackFit.expand, children: [
              _bannerPuesto(p),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.25), Tg.azulOscuro.withValues(alpha: 0.85)],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: PildoraTg(p.textoEstado,
                    color: colorEstado,
                    colorTexto: Colors.white,
                    icono: p.abierto ? Icons.check_circle : Icons.pause_circle),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: PopupMenuButton<_Accion>(
                    tooltip: 'Opciones del puesto',
                    onSelected: (a) => _accion(a, p),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: _Accion.editar, child: ListTile(leading: Icon(Icons.edit), title: Text('Editar puesto'))),
                      PopupMenuItem(value: _Accion.temporal, child: ListTile(leading: Icon(Icons.schedule), title: Text('Cerrar temporalmente'))),
                      PopupMenuItem(value: _Accion.indefinido, child: ListTile(leading: Icon(Icons.pause_circle_outline), title: Text('Cerrar hasta nuevo aviso'))),
                      PopupMenuItem(value: _Accion.eliminar, child: ListTile(leading: Icon(Icons.delete_outline, color: Tg.rojo), title: Text('Eliminar puesto'))),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: Text(p.nombre,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Tg.marcador(26)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((p.descripcion ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(p.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.15)),
                ),
              if (p.detalleCierre != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 18, color: Tg.naranja),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.detalleCierre!,
                          style: const TextStyle(color: Tg.naranja, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: p.abierto ? Tg.rojo : Tg.amarillo,
                    foregroundColor: p.abierto ? Colors.white : Tg.azulOscuro),
                onPressed: () => _alternar(p),
                icon: Icon(p.abierto ? Icons.lock_outline : Icons.storefront),
                label: Text(p.abierto ? 'CERRAR PUESTO' : 'YA LLEGUÉ · ABRIR'),
              ),
              if (p.abierto)
                Center(
                  child: TextButton.icon(
                      onPressed: () => _codigo(p),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Generar código de visita')),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _beneficio(IconData icono, Color color, String titulo, String texto) => TarjetaTg(
        margen: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          SelloTg(icono: icono, color: color, tam: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.1)),
              Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.1)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const CargandoTg();
    if (_perfil == null) {
      return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        const CabeceraTg(
          titulo: '¿Tienes un puesto en el tianguis?',
          subtitulo: 'Súbelo a TianGuía y que te encuentren',
          icono: Icons.store_mall_directory,
        ),
        _beneficio(Icons.inventory_2, Tg.amarillo, 'Publica tus productos', 'Con fotos, precio y cuántos te quedan.'),
        _beneficio(Icons.storefront, const Color(0xFF2EAD5B), 'Avisa cuando abres', 'Con un toque tu puesto sale en el mapa.'),
        _beneficio(Icons.handshake, Tg.rosa, 'Recibe propuestas y apartados', 'Contesta, contraoferta y cierra el trato.'),
        _beneficio(Icons.bolt, Tg.naranja, 'Lanza ofertas relámpago', 'Mueve tu mercancía antes de que se acabe el día.'),
        if (AuthService().esAnonimo)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Text('Te pediremos verificar tu correo para activar tu perfil de vendedor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 18),
        Center(child: BotonPincel(texto: 'Habilitar perfil de vendedor', icono: Icons.rocket_launch, onPressed: _habilitar)),
      ]);
    }
    final id = _perfil!['id'] as String;
    final negocio = (_perfil!['nombre_negocio'] as String?)?.trim();
    final abiertos = _puestos.where((p) => p.abierto).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(), icon: const Icon(Icons.add), label: const Text('Puesto'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
          CabeceraTg(
            titulo: (negocio ?? '').isEmpty ? 'Mi puesto' : negocio!,
            subtitulo: 'Panel de vendedor',
            icono: Icons.store_mall_directory,
            datos: [
              DatoTg(Icons.check_circle, const Color(0xFF2EAD5B), '$abiertos', 'ABIERTOS'),
              DatoTg(Icons.storefront, Tg.azulClaro, '${_puestos.length}', 'PUESTOS'),
              DatoTg(Icons.handshake, Tg.rosa, '$_pendientes', 'POR ATENDER',
                  onTap: () => _ir(TratosScreen(idVendedor: id))),
            ],
          ),
          const SeccionTg('Mi negocio'),
          RejillaMosaicos(hijos: [
            MosaicoTg(
              icono: Icons.inventory_2,
              color: Tg.amarillo,
              titulo: 'Mis productos',
              angulo: -0.012,
              onTap: () => _ir(MisProductosScreen(idVendedor: id)),
            ),
            MosaicoTg(
              icono: Icons.handshake,
              color: Tg.rosa,
              colorTexto: Colors.white,
              titulo: 'Propuestas y apartados',
              badge: _pendientes,
              angulo: 0.012,
              onTap: () => _ir(TratosScreen(idVendedor: id)),
            ),
            MosaicoTg(
              icono: Icons.bolt,
              color: Tg.naranja,
              titulo: 'Ofertas relámpago',
              angulo: 0.012,
              onTap: () => _ir(OfertasScreen(idVendedor: id)),
            ),
            MosaicoTg(
              icono: Icons.event_busy,
              color: Tg.azulClaro,
              titulo: 'Horario y ausencias',
              angulo: -0.012,
              onTap: () => _ir(HorariosScreen(
                idVendedor: id,
                tianguis: {for (final p in _puestos) p.idTianguis: p.nombre},
              )),
            ),
            MosaicoTg(
              icono: Icons.crop_free,
              color: const Color(0xFF1E8E3E),
              colorTexto: Colors.white,
              titulo: 'Espacios',
              angulo: -0.012,
              onTap: () => _ir(EspaciosScreen(idVendedor: id)),
            ),
            MosaicoTg(
              icono: Icons.star_rounded,
              color: Colors.white,
              titulo: 'Mis valoraciones',
              angulo: 0.012,
              onTap: () => _ir(ValoracionesScreen(idVendedor: id)),
            ),
          ]),
          const SeccionTg('Mis puestos'),
          if (_puestos.isEmpty)
            const TarjetaTg(
              acento: Tg.amarillo,
              child: Row(children: [
                SelloTg(icono: Icons.add_business, color: Tg.amarillo, tam: 46),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Aún no tienes puestos. Crea el primero con el botón + Puesto.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
                ),
              ]),
            ),
          for (final p in _puestos) _tarjetaPuesto(p),
        ]),
      ),
    );
  }
}
