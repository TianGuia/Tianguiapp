import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/inicio_service.dart';
import '../widgets/corazon.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';
import '../widgets/visita_flow.dart';
import 'producto_detalle_screen.dart';

/// Detalle de un puesto: foto, ubicación, calificación y sus productos.
class PuestoScreen extends StatefulWidget {
  final PuestoResumen puesto;
  const PuestoScreen({super.key, required this.puesto});
  @override
  State<PuestoScreen> createState() => _PuestoScreenState();
}

class _PuestoScreenState extends State<PuestoScreen> {
  final _svc = InicioService();
  late Future<List<Producto>> _productos = _svc.productosDePuesto(widget.puesto.id);
  late Future<Puesto?> _estado = _svc.puestoPorId(widget.puesto.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.puesto;
    return Fondo(
      pinceladas: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _productos = _svc.productosDePuesto(p.id);
              _estado = _svc.puestoPorId(p.id);
            });
            await _productos;
          },
          child: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 260,
              backgroundColor: Tg.azulOscuro,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Tg.azulOscuro.withValues(alpha: 0.85),
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              actions: [Padding(padding: const EdgeInsets.all(8), child: BotonCorazon(idPuesto: p.id))],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  ImagenPuesto(p.imagenUrl),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Tg.azulOscuro.withValues(alpha: 0.95)],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nombre, style: Tg.marcador(34)),
                  const SizedBox(height: 8),
                  FutureBuilder<Puesto?>(
                    future: _estado,
                    builder: (_, s) {
                      // Si aún no carga (o falla), se usa el estado del resumen.
                      final real = s.data;
                      final abierto = real?.abierto ?? p.abierto;
                      final cierreEspecial = !abierto && real?.cierreTipo != null;
                      final texto = real?.textoEstado ?? (p.abierto ? 'ABIERTO AHORA' : 'CERRADO');
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          EtiquetaPincel(
                            texto: abierto ? 'ABIERTO AHORA' : texto,
                            color: abierto
                                ? const Color(0xFF1E8E3E)
                                : (cierreEspecial ? Tg.naranja : Colors.grey.shade700),
                            colorTexto: Colors.white,
                            icono: abierto
                                ? Icons.check_circle
                                : (cierreEspecial ? Icons.pause_circle : Icons.schedule),
                            angulo: -0.02,
                          ),
                          if (p.ubicacion.isNotEmpty)
                            EtiquetaPincel(
                                texto: p.ubicacion,
                                color: Tg.rosa,
                                colorTexto: Colors.white,
                                icono: Icons.location_on,
                                angulo: 0.02),
                        ]),
                        if (real?.detalleCierre != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(real!.detalleCierre!,
                                style: const TextStyle(
                                    color: Tg.amarillo, fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                      ]);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.star, color: Tg.amarillo),
                    const SizedBox(width: 4),
                    Text(
                      p.calificaciones == 0
                          ? 'Sin calificaciones'
                          : '${p.promedio.toStringAsFixed(1)}  (${p.calificaciones})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.favorite, color: Tg.rosa, size: 20),
                    const SizedBox(width: 4),
                    Text('${p.guardados} guardados',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ]),
                  if ((p.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(p.descripcion!, style: const TextStyle(fontSize: 16)),
                  ],
                  const SizedBox(height: 16),
                  BotonPincel(
                    texto: 'Ya visité este puesto',
                    icono: Icons.verified,
                    onPressed: () => confirmarVisita(context),
                  ),
                  const SizedBox(height: 22),
                  const TituloPincel('Productos', icono: Icons.shopping_bag, colorIcono: Tg.amarillo),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
            FutureBuilder<List<Producto>>(
              future: _productos,
              builder: (_, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator(color: Tg.amarillo)),
                    ),
                  );
                }
                if (s.hasError) {
                  return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: Text('Error: ${s.error}')));
                }
                final l = s.data!;
                if (l.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Este puesto aún no publica productos.'),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  sliver: SliverList.separated(
                    itemCount: l.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => TarjetaProducto(
                      producto: l[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductoDetalleScreen(producto: l[i])),
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta blanca de producto (como la lista de "Tacos" del diseño).
class TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  const TarjetaProducto({super.key, required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: p.imagenes.isEmpty
                    ? Container(
                        color: const Color(0xFFE8ECF8),
                        child: const Icon(Icons.image_not_supported, color: Tg.azul, size: 34),
                      )
                    : Image.network(p.imagenes.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE8ECF8),
                              child: const Icon(Icons.broken_image, color: Tg.azul),
                            )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Tg.azulOscuro, fontWeight: FontWeight.w800, fontSize: 18)),
                if ((p.descripcion ?? '').isNotEmpty)
                  Text(p.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.05)),
                const SizedBox(height: 2),
                Text(p.precio == null ? 'Precio a tratar' : '\$${p.precio}',
                    style: const TextStyle(
                        color: Tg.azulOscuro, fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Tg.amarillo,
              child: Icon(Icons.add, color: Tg.azulOscuro),
            ),
          ]),
        ),
      ),
    );
  }
}
