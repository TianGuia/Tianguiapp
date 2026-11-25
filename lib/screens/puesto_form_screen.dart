import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/vendedor_service.dart';
import '../widgets/entradas.dart';
import '../widgets/mensaje.dart';

// RF-20 se cumple aqui: el vendedor dice en que tianguis pone su puesto
// si [puesto] viene, se edita; si no, se crea uno nuevo.
class PuestoFormScreen extends StatefulWidget {
  final String idVendedor;
  final Puesto? puesto;
  const PuestoFormScreen({super.key, required this.idVendedor, this.puesto});
  @override
  State<PuestoFormScreen> createState() => _PuestoFormScreenState();
}

class _PuestoFormScreenState extends State<PuestoFormScreen> {
  final _svc = VendedorService();
  late final _nombre = TextEditingController(text: widget.puesto?.nombre);
  late final _codigo = TextEditingController(text: widget.puesto?.codigo);
  late final _desc = TextEditingController(text: widget.puesto?.descripcion);
  List<Tianguis> _tianguis = [];
  String? _idTianguis;
  File? _foto;
  bool _guardando = false;
  String? _idNuevoPuesto;

  bool get _edita => widget.puesto != null;
  static const _negro = TextStyle(color: Colors.black);

  @override
  void initState() {
    super.initState();
    _idTianguis = widget.puesto?.idTianguis;
    CatalogoService().tianguis().then((t) {
      if (!mounted) return;
      setState(() {
        _tianguis = t;
        _idTianguis ??= t.isEmpty ? null : t.first.id;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _nombre.dispose();
    _codigo.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _msg(String t) => mostrarMensaje(context, t);

  Future<void> _elegirFoto() async {
    if (_guardando) return;

    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1280,
    );

    if (x != null && mounted && !_guardando) {
      setState(() => _foto = File(x.path));
    }
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final nombre = _nombre.text.trim();
    final idTianguis = _idTianguis;
    final foto = _foto;

    if (nombre.isEmpty) {
      return _msg('Escribe el nombre del puesto');
    }

    if (idTianguis == null) {
      return _msg('Elige el tianguis');
    }

    final codigo = _codigo.text.trim().isEmpty
        ? null
        : _codigo.text.trim();

    final desc = _desc.text.trim().isEmpty
        ? null
        : _desc.text.trim();

    setState(() => _guardando = true);

    try {
      final String idPuesto;

      if (_edita) {
        idPuesto = widget.puesto!.id;

        await _svc.actualizarPuesto(idPuesto, {
          'nombre': nombre,
          'codigo': codigo,
          'descripcion': desc,
        });
      } else {
        _idNuevoPuesto ??= const Uuid().v4();

        idPuesto = await _svc.crearPuesto(
          widget.idVendedor,
          idTianguis,
          nombre,
          idPuesto: _idNuevoPuesto!,
          codigo: codigo,
          descripcion: desc,
        );
      }

      // En este punto el puesto ya fue guardado.

      if (foto != null) {
        try {
          await _svc.subirFotoPuesto(
            idPuesto,
            foto,
            rutaAnterior: widget.puesto?.fotoRuta,
          );
        } catch (e, stackTrace) {
          debugPrint('Error al guardar fotografía: $e');
          debugPrintStack(stackTrace: stackTrace);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El puesto se guardó, pero no se pudo '
                  'confirmar el guardado de su fotografía.',
                ),
              ),
            );

            Navigator.pop(context, true);
          }

          return;
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }

    } catch (e, stackTrace) {
      debugPrint('Error al guardar puesto: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _msg('No se pudo confirmar el guardado del puesto.');
      }

    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoActual = widget.puesto?.fotoUrl;
    return ScaffoldTg(
      appBar: AppBar(title: Text(_edita ? 'Editar puesto' : 'Nuevo puesto')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GestureDetector(
          onTap: _guardando ? null : _elegirFoto,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Tg.azulOscuro,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _foto != null
                  ? Image.file(_foto!, fit: BoxFit.cover, width: double.infinity)
                  : fotoActual != null
                      ? Image.network(fotoActual, fit: BoxFit.cover, width: double.infinity)
                      : const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add_a_photo, size: 44),
                          SizedBox(height: 6),
                          Text('Foto del puesto (opcional)'),
                        ])),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _nombre,
            style: _negro,
            inputFormatters: Entradas.texto(60),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Nombre del puesto')),
        const SizedBox(height: 10),
        TextField(
            controller: _desc,
            style: _negro,
            maxLines: 3,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Descripción: qué vendes, tu estilo…')),
        TextField(
            controller: _codigo,
            style: _negro,
            inputFormatters: Entradas.texto(10),
            decoration: const InputDecoration(hintText: 'Número o letra de tu lugar (opcional)')),
        const SizedBox(height: 10),
        if (_edita)
          // cambiar de tianguis implicaria reasignar horarios; se deja fijo.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Icons.place, color: Tg.amarillo),
              const SizedBox(width: 8),
              Text(
                _tianguis.where((t) => t.id == _idTianguis).map((t) => t.nombre).firstOrNull ??
                    'Tianguis',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ]),
          )
        else
          DropdownButton<String>(
            isExpanded: true,
            value: _tianguis.any((t) => t.id == _idTianguis) ? _idTianguis : null,
            hint: const Text('Tianguis donde estás'),
            items: [for (final t in _tianguis) DropdownMenuItem(value: t.id, child: Text(t.nombre))],
            onChanged: _guardando || _idNuevoPuesto != null ? null : (v) => setState(() => _idTianguis = v),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_edita ? 'GUARDAR CAMBIOS' : 'CREAR PUESTO'),
        ),
      ]),
    );
  }
}
