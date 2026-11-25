import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../models/modelos.dart';
import '../services/datos_en_vivo.dart';
import '../widgets/aviso_sincronizacion.dart';
import '../widgets/mensaje.dart';
import '../services/catalogo_service.dart';
import '../services/favoritos_cambios.dart';
import 'producto_detalle_screen.dart';
import 'puesto_screen.dart';

// RF-11 se cumple aqui: se guardan productos, puestos y tianguis como favoritos para verlos despues
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});
  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  final _db = Supabase.instance.client;
  late final _datos = DatosEnVivo(
    _cargar,
    tablas: {'puestos': null, 'productos': null, 'tianguis': null},
  );

  Map<String, String> get _tianguis => _datos.datos?.tianguis ?? {};

  @override
  void dispose() {
    _datos.dispose();
    super.dispose();
  }

  Future<({List<Map<String, dynamic>> favoritos, Map<String, String> tianguis})> _cargar() async {
    final (t, favoritos) = await (
      CatalogoService().tianguis(),
      _db
          .from('favoritos')
          .select('id, id_puesto, id_producto, id_tianguis, '
              'puestos(id, nombre, estado, id_tianguis, descripcion), '
              'productos(id, nombre, precio_referencia)')
          .eq('id_usuario', _db.auth.currentUser!.id)
          .order('creado_en', ascending: false),
    ).wait;
    return (favoritos: favoritos, tianguis: {for (final x in t) x.id: x.nombre});
  }

  Future<void> _quitar(Map<String, dynamic> f) async {
    try {
      await _db.from('favoritos').delete().eq('id', f['id']);
      FavoritosCambios.avisar();
      if (mounted) await _datos.recargar();
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo quitar este favorito');
    }
  }

  Future<void> _abrir(Map<String, dynamic> f) async {
    final p = f['puestos'] as Map?;
    if (p != null) {
      final res = PuestoResumen.fromMap({
        'id': p['id'],
        'nombre': p['nombre'],
        'id_tianguis': p['id_tianguis'],
        'tianguis_nombre': _tianguis[p['id_tianguis']],
        'descripcion': p['descripcion'],
        'abierto': p['estado'] == 'abierto',
      });
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PuestoScreen(puesto: res)));
    } else if (f['id_producto'] != null) {
      final prod = await CatalogoService().porId(f['id_producto'] as String);
      if (prod != null && mounted) {
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: prod)));
      }
    }
    if (mounted) await _datos.recargar();
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Mis favoritos')),
        body: ListenableBuilder(
          listenable: _datos,
          builder: (_, __) {
            final aviso = _datos.desactualizado
                ? AvisoSincronizacion(hayDatos: _datos.hayDatos, onReintentar: _datos.recargar)
                : null;
            final l = _datos.datos?.favoritos;
            if (l == null) {
              return aviso == null
                  ? const CargandoTg()
                  : Align(alignment: Alignment.topCenter, child: aviso);
            }
            return Column(children: [
              if (aviso != null) aviso,
              Expanded(child: RefreshIndicator(onRefresh: _datos.recargar, child: _lista(l))),
            ]);
          },
        ),
      );

  Widget _lista(List<Map<String, dynamic>> l) {
    if (l.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
        SizedBox(
            height: 340,
            child: EstadoVacio(
              icono: Icons.favorite_rounded,
              color: Tg.rosa,
              titulo: '¡Aquí falta corazón!',
              mensaje:
                  'Toca el corazón en un puesto o producto que te guste y lo guardamos aquí para que no se te pierda.',
            ))
      ]);
    }
    final nPuestos = l.where((f) => f['puestos'] != null).length;
    final nProd = l.where((f) => f['puestos'] == null && f['id_tianguis'] == null).length;
    final nTian = l.where((f) => f['id_tianguis'] != null).length;
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          CabeceraTg(
            titulo: 'Tus favoritos',
            subtitulo: 'Lo que te late del tianguis',
            icono: Icons.favorite_rounded,
            color: Tg.rosa,
            datos: [
              DatoTg(Icons.storefront, Tg.amarillo, '$nPuestos', 'PUESTOS'),
              DatoTg(Icons.shopping_bag, Tg.azulClaro, '$nProd', 'PRODUCTOS'),
              DatoTg(Icons.place, const Color(0xFF2EAD5B), '$nTian', 'TIANGUIS'),
            ],
          ),
          for (final f in l) _tarjeta(f),
        ]);
  }

  Widget _tarjeta(Map<String, dynamic> f) {
    final puesto = f['puestos'] as Map?;
    final prod = f['productos'] as Map?;
    final esTianguis = f['id_tianguis'] != null;
    final IconData icono;
    final Color color;
    final String titulo;
    final String sub;
    final String tipo;
    if (puesto != null) {
      icono = Icons.storefront;
      color = Tg.amarillo;
      tipo = 'PUESTO';
      titulo = '${puesto['nombre']}';
      sub = puesto['estado'] == 'abierto' ? 'Abierto ahora' : 'Cerrado por ahora';
    } else if (esTianguis) {
      icono = Icons.place;
      color = const Color(0xFF2EAD5B);
      tipo = 'TIANGUIS';
      titulo = _tianguis[f['id_tianguis']] ?? 'Tianguis';
      sub = 'Tianguis guardado';
    } else {
      icono = Icons.shopping_bag_outlined;
      color = Tg.azulClaro;
      tipo = 'PRODUCTO';
      titulo = '${prod?['nombre'] ?? 'Producto'}';
      sub = prod?['precio_referencia'] != null
          ? '\$${prod!['precio_referencia']}'
          : 'Sin precio de referencia';
    }
    final abierto = puesto != null && puesto['estado'] == 'abierto';
    return TarjetaTg(
      acento: color,
      onTap: esTianguis ? null : () => _abrir(f),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(children: [
        SelloTg(icono: icono, color: color, tam: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PildoraTg(tipo, color: Colors.white12, colorTexto: Colors.white70),
            const SizedBox(height: 3),
            Text(titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
            Row(children: [
              if (puesto != null)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(Icons.circle,
                      size: 11, color: abierto ? const Color(0xFF2EAD5B) : Colors.grey),
                ),
              Flexible(
                child: Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ]),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.favorite, color: Tg.rosa),
          tooltip: 'Quitar de favoritos',
          onPressed: () => _quitar(f),
        ),
      ]),
    );
  }
}
