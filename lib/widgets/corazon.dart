import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/favoritos_cambios.dart';
import '../services/inicio_service.dart';

/// Botón de corazón que guarda/quita un puesto de favoritos.
class BotonCorazon extends StatefulWidget {
  final String idPuesto;
  const BotonCorazon({super.key, required this.idPuesto});
  @override
  State<BotonCorazon> createState() => _BotonCorazonState();
}

class _BotonCorazonState extends State<BotonCorazon> {
  final _svc = InicioService();
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    _refrescar();
    FavoritosCambios.version.addListener(_refrescar);
  }

  @override
  void dispose() {
    FavoritosCambios.version.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() {
    _svc.esFavoritoPuesto(widget.idPuesto).then((v) {
      if (mounted) setState(() => _fav = v);
    }).catchError((_) {});
  }

  Future<void> _alternar() async {
    final anterior = _fav;
    setState(() => _fav = !anterior); // respuesta inmediata
    try {
      final nuevo = await _svc.alternarFavoritoPuesto(widget.idPuesto);
      if (mounted) setState(() => _fav = nuevo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _fav = anterior);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tg.azulOscuro.withValues(alpha: 0.85),
      shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _alternar,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(_fav ? Icons.favorite : Icons.favorite_border,
              size: 22, color: _fav ? Tg.rosa : Colors.white),
        ),
      ),
    );
  }
}

/// Imagen de un puesto con respaldo si no tiene foto o falla la red.
class ImagenPuesto extends StatelessWidget {
  final String? url;
  const ImagenPuesto(this.url, {super.key});

  Widget _respaldo() => Container(
        color: Tg.azulOscuro,
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.55,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Image.asset('assets/icon/icon.png', fit: BoxFit.contain),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (url == null) return _respaldo();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _respaldo(),
    );
  }
}
