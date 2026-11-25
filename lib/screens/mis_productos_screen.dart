import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';
import '../widgets/entradas.dart';
import '../widgets/mensaje.dart';

// aqui se cumplen RF-23 a RF-26, cada parte de abajo dice cual cumple
class MisProductosScreen extends StatefulWidget {
  final String idVendedor;
  const MisProductosScreen({super.key, required this.idVendedor});
  @override
  State<MisProductosScreen> createState() => _MisProductosScreenState();
}

class _MisProductosScreenState extends State<MisProductosScreen> {
  final _svc = VendedorService();
  late Future<List<Producto>> _futuro = _svc.misProductos(widget.idVendedor);

  void _recargar() {
    setState(() {
      _futuro = _svc.misProductos(widget.idVendedor);
    });
  }

  void _msg(String t) => mostrarMensaje(context, t);

  Future<void> _stock(Producto p, int delta) async {
    final n = ((p.cantidad ?? 0) + delta).clamp(0, 100000);
    try {
      await _svc.actualizarStock(p.id, n);
      _recargar();
    } catch (e) {
      _msg('No se pudo cambiar el stock: $e');
    }
  }

  Future<void> _abrirFormulario({Producto? producto}) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(idVendedor: widget.idVendedor, producto: producto),
      ),
    );
    if (guardado == true) _recargar();
  }

  Future<void> _retirar(Producto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Retirar producto?'),
        content: Text('"${p.nombre}" dejará de mostrarse a los compradores.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Tg.rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // RF-25 se cumple aqui: el producto no se borra, solo se oculta para que ya no salga
      await _svc.retirarProducto(p.id);
      _recargar();
    } catch (e) {
      _msg('No se pudo retirar el producto: $e');
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Mis productos')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Producto'),
        ),
        body: FutureBuilder<List<Producto>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) return const CargandoTg();
            if (s.hasError) {
              return EstadoVacio(
                icono: Icons.wifi_off_rounded,
                color: Tg.rojo,
                titulo: '¡Se cayó la señal!',
                mensaje: 'No se pudieron cargar tus productos.\n${s.error}',
                accionTexto: 'Reintentar',
                accionIcono: Icons.refresh,
                onAccion: _recargar,
              );
            }
            final l = s.data!;
            if (l.isEmpty) {
              return EstadoVacio(
                icono: Icons.inventory_2_rounded,
                titulo: '¡Tu mercancía está en cero!',
                mensaje: 'Sube tu primer producto con foto y precio para que los compradores lo encuentren.',
                accionTexto: 'Agregar producto',
                accionIcono: Icons.add,
                onAccion: () => _abrirFormulario(),
              );
            }
            final agotados = l.where((p) => (p.cantidad ?? 0) <= 0).length;
            final ocultos = l.where((p) => !p.disponible).length;
            return ListView(padding: const EdgeInsets.only(bottom: 100), children: [
              CabeceraTg(
                titulo: 'Mi mercancía',
                subtitulo: 'Toca un producto para editarlo',
                icono: Icons.inventory_2_rounded,
                datos: [
                  DatoTg(Icons.sell, Tg.amarillo, '${l.length}', 'PRODUCTOS'),
                  DatoTg(Icons.production_quantity_limits, Tg.naranja, '$agotados', 'SIN STOCK'),
                  DatoTg(Icons.visibility_off, Tg.azulClaro, '$ocultos', 'NO DISPONIBLES'),
                ],
              ),
              for (final p in l) _tarjeta(p),
            ]);
          },
        ),
      );

  Widget _tarjeta(Producto p) {
    final sinStock = (p.cantidad ?? 0) <= 0;
    final foto = p.imagenes.isEmpty
        ? Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.image_not_supported, size: 34, color: Colors.white38),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(p.imagenes.first,
                width: 74,
                height: 74,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 74, height: 74, color: Colors.white12,
                    child: const Icon(Icons.broken_image, color: Colors.white38))),
          );
    return TarjetaTg(
      acento: !p.disponible ? Colors.grey : (sinStock ? Tg.naranja : const Color(0xFF2EAD5B)),
      onTap: () => _abrirFormulario(producto: p),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 8),
      child: Row(children: [
        foto,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.1)),
            const SizedBox(height: 2),
            Text(p.precio == null ? 'Sin precio' : '\$${p.precio}',
                style: Tg.marcador(20, color: Tg.amarillo)),
            const SizedBox(height: 3),
            Wrap(spacing: 6, runSpacing: 4, children: [
              PildoraTg(sinStock ? 'SIN STOCK' : 'STOCK ${p.cantidad ?? 0}',
                  color: sinStock ? Tg.naranja : const Color(0xFF1E8E3E),
                  colorTexto: sinStock ? Tg.azulOscuro : Colors.white),
              if (!p.disponible) const PildoraTg('NO DISPONIBLE', color: Colors.grey, colorTexto: Colors.white),
              if (p.imagenes.length > 1)
                PildoraTg('${p.imagenes.length} FOTOS',
                    color: Colors.white12, colorTexto: Colors.white70, icono: Icons.photo_library),
            ]),
          ]),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                tooltip: 'Quitar uno',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _stock(p, -1)),
            IconButton(
                tooltip: 'Agregar uno',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _stock(p, 1)),
          ]),
          IconButton(
            tooltip: 'Retirar producto',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, color: Tg.rojo),
            onPressed: () => _retirar(p),
          ),
        ]),
      ]),
    );
  }
}

// crear o editar un producto, la primera foto es la portada
// RF-23 se cumple aqui: el vendedor agrega un producto con nombre, fotos y precio
// RF-24 se cumple aqui: el vendedor cambia los datos de un producto
// RF-26 se cumple aqui: el vendedor actualiza cuantos le quedan de un producto
class ProductoFormScreen extends StatefulWidget {
  final String idVendedor;
  final Producto? producto;
  const ProductoFormScreen({super.key, required this.idVendedor, this.producto});
  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  static const maxFotos = 6;
  static const _negro = TextStyle(color: Colors.black);
  static const _estados = {
    'nuevo': 'Nuevo',
    'usado': 'Usado',
    'reacondicionado': 'Reacondicionado',
  };

  final _svc = VendedorService();
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _desc = TextEditingController(text: widget.producto?.descripcion);
  late final _precio = TextEditingController(text: widget.producto?.precio?.toString());
  // vacio es sin control de cantidad, hay productos viejos sin ella
  late final _cant =
      TextEditingController(text: widget.producto?.cantidad?.toString() ?? (_edita ? '' : '1'));

  List<Map<String, dynamic>> _cats = [];
  List<Puesto> _puestos = [];
  String? _cat; // en edicion se resuelve por nombre al cargar las categorias
  late String? _puesto = widget.producto?.idPuesto;
  late String _estado = widget.producto?.estadoArticulo ?? 'nuevo';
  late bool _disponible = widget.producto?.disponibilidadManual ?? true;

  late final List<ImagenProducto> _existentes = [...?widget.producto?.fotos];
  final List<ImagenProducto> _quitadas = [];
  final List<File> _nuevas = [];
  bool _guardando = false;

  bool get _edita => widget.producto != null;
  int get _totalFotos => _existentes.length + _nuevas.length;

  @override
  void initState() {
    super.initState();
    CatalogoService().categorias().then((c) {
      if (!mounted) return;
      setState(() {
        _cats = c;
        final nombre = widget.producto?.categoria;
        if (_cat == null && nombre != null) {
          for (final x in c) {
            if (x['nombre'] == nombre) _cat = x['id'] as String;
          }
        }
      });
    }).catchError((_) {});
    _svc.misPuestos(widget.idVendedor).then((p) {
      if (mounted) setState(() => _puestos = p);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    _desc.dispose();
    _precio.dispose();
    _cant.dispose();
    super.dispose();
  }

  void _msg(String t) => mostrarMensaje(context, t);

  Future<void> _agregarFotos() async {
    final cupo = maxFotos - _totalFotos;
    if (cupo <= 0) return _msg('Máximo $maxFotos fotos por producto');
    final xs = await ImagePicker().pickMultiImage(imageQuality: 70, maxWidth: 1280);
    if (xs.isEmpty) return;
    if (xs.length > cupo) _msg('Solo caben $cupo foto(s) más; se agregaron las primeras.');
    setState(() => _nuevas.addAll(xs.take(cupo).map((x) => File(x.path))));
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) return _msg('Escribe el nombre del producto');
    if (!_puestos.any((p) => p.id == _puesto)) {
      return _msg(_puestos.isEmpty
          ? 'Primero crea un puesto en "Mi puesto" para poder publicar productos'
          : 'Elige el puesto donde vendes este producto');
    }
    final precioTxt = _precio.text.trim();
    final precio = precioTxt.isEmpty ? null : Entradas.leerDinero(precioTxt);
    if (precioTxt.isNotEmpty && (precio == null || precio <= 0)) {
      return _msg('Precio no válido. Usa solo números, por ejemplo 150 o 150.50');
    }
    final cantTxt = _cant.text.trim();
    final cantidad = cantTxt.isEmpty ? null : Entradas.leerEntero(cantTxt);
    if (cantTxt.isNotEmpty && cantidad == null) {
      return _msg('La cantidad debe ser un número entero de 0 a 99999');
    }
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();

    setState(() => _guardando = true);
    try {
      String id;
      if (_edita) {
        id = widget.producto!.id;
        await _svc.actualizarProducto(id, {
          'nombre': _nombre.text.trim(),
          'descripcion': desc,
          'id_categoria': _cat,
          'id_puesto': _puesto,
          'estado_articulo': _estado,
          'precio_referencia': precio,
          'cantidad_disponible': cantidad,
          'disponibilidad_manual': _disponible,
        });
        for (final img in _quitadas) {
          await _svc.eliminarImagen(img);
        }
      } else {
        id = await _svc.crearProducto(
          idVendedor: widget.idVendedor,
          idPuesto: _puesto,
          idCategoria: _cat,
          nombre: _nombre.text.trim(),
          descripcion: desc,
          estadoArticulo: _estado,
          precio: precio,
          cantidad: cantidad,
          disponibilidadManual: _disponible,
        );
      }
      var orden = _existentes.isEmpty ? 0 : _existentes.map((e) => e.orden).reduce((a, b) => a > b ? a : b) + 1;
      for (final f in _nuevas) {
        await _svc.subirImagen(id, f, orden: orden++);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg('No se guardó: $e');
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _miniatura({required Widget imagen, required VoidCallback onQuitar, bool portada = false}) =>
      Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 96, height: 96, child: imagen)),
        if (portada)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Tg.amarillo, borderRadius: BorderRadius.circular(8)),
              child: const Text('PORTADA',
                  style: TextStyle(color: Tg.azulOscuro, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onQuitar,
            child: const CircleAvatar(radius: 12, backgroundColor: Tg.rojo, child: Icon(Icons.close, size: 16, color: Colors.white)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final puestosOk = _puestos.any((p) => p.id == _puesto);
    final catOk = _cats.any((c) => c['id'] == _cat);
    return ScaffoldTg(
      appBar: AppBar(title: Text(_edita ? 'Editar producto' : 'Nuevo producto')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 100,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            GestureDetector(
              onTap: _agregarFotos,
              child: Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: Tg.azulOscuro,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_a_photo, size: 30),
                  const SizedBox(height: 4),
                  Text('$_totalFotos/$maxFotos', style: const TextStyle(fontSize: 12)),
                ]),
              ),
            ),
            for (var i = 0; i < _existentes.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _miniatura(
                  portada: i == 0,
                  imagen: Image.network(_existentes[i].url, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
                  onQuitar: () => setState(() => _quitadas.add(_existentes.removeAt(i))),
                ),
              ),
            for (var i = 0; i < _nuevas.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _miniatura(
                  portada: _existentes.isEmpty && i == 0,
                  imagen: Image.file(_nuevas[i], fit: BoxFit.cover),
                  onQuitar: () => setState(() => _nuevas.removeAt(i)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _nombre,
            style: _negro,
            inputFormatters: Entradas.texto(80),
            decoration: const InputDecoration(hintText: 'Nombre')),
        const SizedBox(height: 10),
        TextField(
            controller: _desc,
            style: _negro,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Descripción')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _precio, style: _negro,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: Entradas.formatoDinero,
              decoration: const InputDecoration(hintText: 'Precio'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _cant, style: _negro, keyboardType: TextInputType.number,
              inputFormatters: Entradas.formatoEntero(5),
              decoration: const InputDecoration(hintText: 'Cantidad'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButton<String>(
          isExpanded: true,
          value: catOk ? _cat : null,
          hint: const Text('Categoría'),
          items: [for (final c in _cats) DropdownMenuItem(value: c['id'] as String, child: Text(c['nombre']))],
          onChanged: (v) => setState(() => _cat = v),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: puestosOk ? _puesto : null,
          hint: const Text('Puesto donde lo vendes *'),
          items: [for (final p in _puestos) DropdownMenuItem(value: p.id, child: Text(p.nombre))],
          onChanged: (v) => setState(() => _puesto = v),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: _estados.containsKey(_estado) ? _estado : null,
          hint: const Text('Estado del artículo'),
          items: [for (final e in _estados.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _estado = v ?? 'nuevo'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar en el catálogo'),
          subtitle: const Text('Con cero piezas, el producto se oculta hasta que repongas stock.'),
          value: _disponible,
          onChanged: (v) => setState(() => _disponible = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_edita ? 'GUARDAR CAMBIOS' : 'GUARDAR PRODUCTO'),
        ),
      ]),
    );
  }
}
