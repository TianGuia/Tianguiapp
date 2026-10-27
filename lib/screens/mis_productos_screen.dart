import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';

/// RF-23 a RF-26: catálogo del vendedor con stock, fotos, edición y retiro.
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

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _stock(Producto p, int delta) async {
    final n = ((p.cantidad ?? 0) + delta).clamp(0, 100000);
    try {
      await _svc.actualizarProducto(
          p.id, {'cantidad_disponible': n, 'disponible': n > 0});
      _recargar();
    } catch (e) {
      _msg('Error: $e');
    }
  }

  /// Abre el formulario para crear (producto == null) o editar.
  Future<void> _abrirFormulario({Producto? producto}) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(
            idVendedor: widget.idVendedor, producto: producto),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
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
      await _svc.retirarProducto(p.id);
      _recargar();
    } catch (e) {
      _msg('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mis productos')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _abrirFormulario(),
          icon: const Icon(Icons.add),
          label: const Text('Producto'),
        ),
        body: FutureBuilder<List<Producto>>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Center(child: Text('Error: ${s.error}'));
            final l = s.data!;
            if (l.isEmpty) {
              return const Center(child: Text('Aún no tienes productos'));
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: l.length,
              itemBuilder: (_, i) {
                final p = l[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    onTap: () => _abrirFormulario(producto: p),
                    leading: p.imagenes.isEmpty
                        ? const Icon(Icons.image_not_supported, size: 40)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(p.imagenes.first,
                                width: 56, height: 56, fit: BoxFit.cover),
                          ),
                    title: Text(p.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '\$${p.precio ?? '-'} · stock ${p.cantidad ?? 0}'
                        '${p.imagenes.length > 1 ? ' · ${p.imagenes.length} fotos' : ''}'
                        '${p.disponible ? '' : ' · no disponible'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: 'Quitar uno',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _stock(p, -1)),
                      IconButton(
                          tooltip: 'Agregar uno',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _stock(p, 1)),
                      IconButton(
                        tooltip: 'Retirar producto',
                        icon: const Icon(Icons.delete_outline, color: Tg.rojo),
                        onPressed: () => _retirar(p),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      );
}

/// Crear o editar un producto (RF-23, RF-24, RF-26). Hasta [maxFotos] fotos;
/// la primera es la portada.
class ProductoFormScreen extends StatefulWidget {
  final String idVendedor;
  final Producto? producto;
  final VendedorService? vendedorService;
  final CatalogoService? catalogoService;
  const ProductoFormScreen(
      {super.key,
      required this.idVendedor,
      this.producto,
      this.vendedorService,
      this.catalogoService});
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

  late final _svc = widget.vendedorService ?? VendedorService();
  late final _nombre = TextEditingController(text: widget.producto?.nombre);
  late final _desc = TextEditingController(text: widget.producto?.descripcion);
  late final _precio =
      TextEditingController(text: widget.producto?.precio?.toString());
  // Vacío = sin control de cantidad (productos viejos pueden no tenerla).
  late final _cant = TextEditingController(
      text: widget.producto?.cantidad?.toString() ?? (_edita ? '' : '1'));

  List<Map<String, dynamic>> _cats = [];
  List<Puesto> _puestos = [];
  String? _cat; // en edición se resuelve por nombre al cargar las categorías
  late String? _puesto = widget.producto?.idPuesto;
  late String _estado = widget.producto?.estadoArticulo ?? 'nuevo';
  late bool _disponible = widget.producto?.disponible ?? true;

  late final List<ImagenProducto> _existentes = [...?widget.producto?.fotos];
  final List<ImagenProducto> _quitadas = [];
  final List<File> _nuevas = [];
  bool _guardando = false;
  bool _cargandoPuestos = true;
  String? _errorPuestos;

  bool get _edita => widget.producto != null;
  int get _totalFotos => _existentes.length + _nuevas.length;

  @override
  void initState() {
    super.initState();
    (widget.catalogoService ?? CatalogoService()).categorias().then((c) {
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
      if (mounted) {
        setState(() {
          _puestos = p;
          _cargandoPuestos = false;
        });
      }
    }).catchError((Object e) {
      if (mounted) {
        setState(() {
          _cargandoPuestos = false;
          _errorPuestos = 'No se pudieron cargar tus puestos: $e';
        });
      }
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _desc.dispose();
    _precio.dispose();
    _cant.dispose();
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _agregarFotos() async {
    final cupo = maxFotos - _totalFotos;
    if (cupo <= 0) return _msg('Máximo $maxFotos fotos por producto');
    final xs =
        await ImagePicker().pickMultiImage(imageQuality: 70, maxWidth: 1280);
    if (xs.isEmpty) return;
    if (xs.length > cupo) {
      _msg('Solo caben $cupo foto(s) más; se agregaron las primeras.');
    }
    setState(() => _nuevas.addAll(xs.take(cupo).map((x) => File(x.path))));
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      return _msg('Escribe el nombre del producto');
    }
    if (_puesto == null || !_puestos.any((p) => p.id == _puesto)) {
      return _msg('Selecciona un puesto activo para el producto');
    }
    final precioTxt = _precio.text.trim().replaceAll(',', '.');
    final precio = precioTxt.isEmpty ? null : num.tryParse(precioTxt);
    if (precioTxt.isNotEmpty && (precio == null || precio < 0)) {
      return _msg('Precio no válido');
    }
    final cantTxt = _cant.text.trim();
    final cantidad = cantTxt.isEmpty ? null : int.tryParse(cantTxt);
    if (cantTxt.isNotEmpty && (cantidad == null || cantidad < 0)) {
      return _msg('La cantidad debe ser 0 o más');
    }
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    final disponible = _disponible && (cantidad == null || cantidad > 0);

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
          'disponible': disponible,
        });
        for (final img in _quitadas) {
          await _svc.eliminarImagen(img);
        }
      } else {
        final producto = await _svc.crearProducto(
          idVendedor: widget.idVendedor,
          idPuesto: _puesto!,
          idCategoria: _cat,
          nombre: _nombre.text.trim(),
          descripcion: desc,
          estadoArticulo: _estado,
          precio: precio,
          cantidad: cantidad,
        );
        id = producto.id;
        if (!disponible) {
          await _svc.actualizarProducto(id, {'disponible': false});
        }
      }
      // Las fotos nuevas van al final del orden actual.
      var orden = _existentes.isEmpty
          ? 0
          : _existentes.map((e) => e.orden).reduce((a, b) => a > b ? a : b) + 1;
      for (final f in _nuevas) {
        await _svc.subirImagen(id, f, orden: orden++);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _msg('No se guardó: $e');
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _miniatura(
          {required Widget imagen,
          required VoidCallback onQuitar,
          bool portada = false}) =>
      Stack(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(width: 96, height: 96, child: imagen)),
        if (portada)
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Tg.amarillo, borderRadius: BorderRadius.circular(8)),
              child: const Text('PORTADA',
                  style: TextStyle(
                      color: Tg.azulOscuro,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onQuitar,
            child: const CircleAvatar(
                radius: 12,
                backgroundColor: Tg.rojo,
                child: Icon(Icons.close, size: 16, color: Colors.white)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final puestosOk = _puestos.any((p) => p.id == _puesto);
    final catOk = _cats.any((c) => c['id'] == _cat);
    return Scaffold(
      appBar:
          AppBar(title: Text(_edita ? 'Editar producto' : 'Nuevo producto')),
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
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, size: 30),
                      const SizedBox(height: 4),
                      Text('$_totalFotos/$maxFotos',
                          style: const TextStyle(fontSize: 12)),
                    ]),
              ),
            ),
            for (var i = 0; i < _existentes.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _miniatura(
                  portada: i == 0,
                  imagen: Image.network(_existentes[i].url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image)),
                  onQuitar: () =>
                      setState(() => _quitadas.add(_existentes.removeAt(i))),
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
            decoration: const InputDecoration(hintText: 'Nombre')),
        const SizedBox(height: 10),
        TextField(
            controller: _desc,
            style: _negro,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Descripción')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _precio,
              style: _negro,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'Precio'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _cant,
              style: _negro,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Cantidad'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        DropdownButton<String>(
          isExpanded: true,
          value: catOk ? _cat : null,
          hint: const Text('Categoría'),
          items: [
            for (final c in _cats)
              DropdownMenuItem(
                  value: c['id'] as String, child: Text(c['nombre']))
          ],
          onChanged: (v) => setState(() => _cat = v),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: puestosOk ? _puesto : null,
          hint: const Text('Puesto donde lo vendes'),
          items: [
            for (final p in _puestos)
              DropdownMenuItem(value: p.id, child: Text(p.nombre))
          ],
          onChanged: (v) => setState(() => _puesto = v),
        ),
        if (_errorPuestos != null) Text(_errorPuestos!),
        if (!_cargandoPuestos && _errorPuestos == null && _puestos.isEmpty)
          const Text(
              'Crea un puesto desde Mi puesto antes de guardar un producto.'),
        DropdownButton<String>(
          isExpanded: true,
          value: _estados.containsKey(_estado) ? _estado : null,
          hint: const Text('Estado del artículo'),
          items: [
            for (final e in _estados.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value))
          ],
          onChanged: (v) => setState(() => _estado = v ?? 'nuevo'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disponible para los compradores'),
          value: _disponible,
          onChanged: (v) => setState(() => _disponible = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _guardando || _cargandoPuestos || _puestos.isEmpty
              ? null
              : _guardar,
          child: Text(_edita ? 'GUARDAR CAMBIOS' : 'GUARDAR PRODUCTO'),
        ),
      ]),
    );
  }
}
