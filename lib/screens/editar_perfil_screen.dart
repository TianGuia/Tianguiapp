import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../widgets/fondo.dart';

/// RF-05: consultar y modificar el perfil básico (nombre público y fotografía).
class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});
  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _auth = AuthService();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  String? _nombreOriginal, _telefonoOriginal, _fotoActual, _errorNombre;
  File? _foto;
  bool _cargando = true, _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _cargar() async {
    try {
      final p = await _auth.miPerfil();
      _nombreOriginal = (p?['nombre_publico'] as String?) ?? '';
      _telefonoOriginal = (p?['telefono'] as String?) ?? '';
      _fotoActual = p?['foto_url'] as String?;
      _nombre.text = _nombreOriginal!;
      _telefono.text = _telefonoOriginal!;
    } catch (e) {
      if (mounted) _msg('No se pudo cargar tu perfil: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFoto() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (x != null) setState(() => _foto = File(x.path));
  }

  Future<void> _guardar() async {
    final n = _nombre.text.trim();
    final tel = _telefono.text.trim();
    if (n.isEmpty) return setState(() => _errorNombre = 'Escribe un nombre');
    setState(() {
      _guardando = true;
      _errorNombre = null;
    });
    try {
      final cambioNombre = n != _nombreOriginal;
      if (cambioNombre && !await _auth.nombreDisponible(n)) {
        setState(() => _errorNombre = 'Este nombre de usuario ya existe, elige otro');
        return;
      }
      final url = _foto == null ? null : await _auth.subirFotoPerfil(_foto!);
      await _auth.actualizarPerfil(
        nombre: cambioNombre ? n : null,
        telefono: tel != _telefonoOriginal && tel.isNotEmpty ? tel : null,
        fotoUrl: url,
      );
      if (!mounted) return;
      _msg('Perfil actualizado');
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (mounted) setState(() => _errorNombre = 'Este nombre de usuario ya existe, elige otro');
      } else {
        _msg('No se pudo guardar: ${e.message}');
      }
    } catch (e) {
      _msg('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const negro = TextStyle(color: Colors.black);
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Editar perfil')),
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: Tg.amarillo))
            : ListView(padding: const EdgeInsets.all(20), children: [
                Center(
                  child: GestureDetector(
                    onTap: _guardando ? null : _elegirFoto,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration:
                            const BoxDecoration(shape: BoxShape.circle, color: Tg.amarillo),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: Tg.azulOscuro,
                          backgroundImage: _foto != null
                              ? FileImage(_foto!) as ImageProvider
                              : (_fotoActual != null ? NetworkImage(_fotoActual!) : null),
                          child: (_foto == null && _fotoActual == null)
                              ? const Icon(Icons.person, size: 56)
                              : null,
                        ),
                      ),
                      const CircleAvatar(
                        radius: 18,
                        backgroundColor: Tg.rosa,
                        child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombre,
                  maxLength: 30,
                  style: negro,
                  onChanged: (_) {
                    if (_errorNombre != null) setState(() => _errorNombre = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Nombre público',
                    counterText: '',
                    errorText: _errorNombre,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  style: negro,
                  decoration: const InputDecoration(hintText: 'Teléfono (opcional)'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'GUARDANDO…' : 'GUARDAR'),
                ),
              ]),
      ),
    );
  }
}
