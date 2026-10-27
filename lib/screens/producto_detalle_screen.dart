import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../models/tratos.dart';
import '../services/chat_service.dart';
import '../services/favoritos_cambios.dart';
import '../widgets/ubicacion_producto.dart';
import 'chat_screen.dart';

/// RF-08, RF-11, RF-16, RF-17, RF-18.
class ProductoDetalleScreen extends StatefulWidget {
  final Producto producto;
  const ProductoDetalleScreen({super.key, required this.producto});
  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  final _cat = CatalogoService();
  final _chat = ChatService();
  bool _ocupado = false;
  bool _fav = false;
  Producto get p => widget.producto;
  late final Future<OfertaVigente?> _oferta =
      _cat.ofertaVigente(p.id, p.precio).catchError((_) => null);

  @override
  void initState() {
    super.initState();
    _refrescarFav();
    FavoritosCambios.version.addListener(_refrescarFav);
  }

  @override
  void dispose() {
    FavoritosCambios.version.removeListener(_refrescarFav);
    super.dispose();
  }

  void _refrescarFav() {
    _cat.esFavorito(p.id).then((v) {
      if (mounted) setState(() => _fav = v);
    }).catchError((_) {});
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _ocupado = true);
    try {
      await f();
      if (mounted) _msg(ok);
    } catch (e) {
      if (mounted) _msg('Error: $e');
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _abrirChat() async {
    setState(() => _ocupado = true);
    try {
      final uidV = await _cat.usuarioDeVendedor(p.idVendedor);
      if (uidV == null) throw 'Vendedor no encontrado';
      if (uidV == Supabase.instance.client.auth.currentUser!.id) throw 'Este producto es tuyo';
      final id = await _chat.conversacionDeProducto(p.id, uidV);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(idConversacion: id, titulo: p.nombre)),
      );
    } catch (e) {
      if (mounted) _msg('$e');
    }
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _proponer() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proponer precio'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(hintText: 'Monto en pesos'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    final monto = num.tryParse(c.text);
    if (ok != true || monto == null || !mounted) return;
    await _run(
      () => _chat.proponerPrecio(idProducto: p.id, idVendedor: p.idVendedor, monto: monto),
      'Propuesta enviada',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(p.nombre),
          actions: [
            IconButton(
              icon: Icon(_fav ? Icons.favorite : Icons.favorite_border, color: Tg.rosa),
              onPressed: () async {
                try {
                  await _cat.alternarFavoritoProducto(p.id);
                  if (mounted) setState(() => _fav = !_fav);
                } catch (e) {
                  if (mounted) _msg('Error: $e');
                }
              },
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (p.imagenes.isNotEmpty)
            SizedBox(
              height: 220,
              child: PageView(children: [
                for (final u in p.imagenes)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(u, fit: BoxFit.cover),
                  ),
              ]),
            )
          else
            const SizedBox(height: 120, child: Icon(Icons.image_not_supported, size: 64)),
          const SizedBox(height: 16),
          Text(p.nombre, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          FutureBuilder<OfertaVigente?>(
            future: _oferta,
            builder: (_, s) {
              final o = s.data;
              if (o != null) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('\$${o.precio}',
                        style: const TextStyle(fontSize: 28, color: Tg.amarillo, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    if (p.precio != null)
                      Text('\$${p.precio}',
                          style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              decoration: TextDecoration.lineThrough)),
                  ]),
                  Text('⚡ ${o.titulo ?? 'Oferta'} · hasta ${fmtFecha(o.fin)}',
                      style: const TextStyle(color: Tg.rosa, fontWeight: FontWeight.w800)),
                ]);
              }
              if (p.precio == null) return const SizedBox.shrink();
              return Text('\$${p.precio}',
                  style: const TextStyle(fontSize: 24, color: Tg.amarillo, fontWeight: FontWeight.w900));
            },
          ),
          const SizedBox(height: 8),
          Text([p.categoria, p.estadoArticulo, p.puestoNombre].whereType<String>().join(' · ')),
          if (p.cantidad != null) Text('Disponibles: ${p.cantidad}'),
          const SizedBox(height: 12),
          Text(p.descripcion ?? 'Sin descripción'),
          const SizedBox(height: 14),
          UbicacionProducto(idPuesto: p.idPuesto),
          const SizedBox(height: 8),
          const Text('TianGuía no procesa pagos: el trato es directo con el vendedor.',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _ocupado ? null : _abrirChat,
            icon: const Icon(Icons.chat),
            label: const Text('CHATEAR CON EL VENDEDOR'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _ocupado ? null : _proponer,
            icon: const Icon(Icons.local_offer),
            label: const Text('PROPONER PRECIO'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _ocupado
                ? null
                : () => _run(
                      () => _chat.solicitarApartado(idProducto: p.id, idVendedor: p.idVendedor),
                      'Apartado solicitado. El vendedor debe aceptarlo (lo ves en Perfil > Mis propuestas y apartados).',
                    ),
            icon: const Icon(Icons.bookmark_add),
            label: const Text('SOLICITAR APARTADO'),
          ),
        ]),
      );
}
