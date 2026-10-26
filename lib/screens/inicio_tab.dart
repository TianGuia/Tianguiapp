import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/modelos.dart';
import '../services/catalogo_service.dart';
import '../services/inicio_service.dart';
import '../widgets/corazon.dart';
import '../widgets/pincel.dart';
import 'puesto_screen.dart';

/// Pantalla de inicio: categorías, resumen, puesto destacado y tendencias.
class InicioTab extends StatefulWidget {
  /// Se llama al tocar el contador de puestos abiertos.
  final VoidCallback onVerPuestos;
  const InicioTab({super.key, required this.onVerPuestos});
  @override
  State<InicioTab> createState() => _InicioTabState();
}

class _InicioTabState extends State<InicioTab> {
  final _catalogo = CatalogoService();
  final _svc = InicioService();

  List<Map<String, dynamic>> _cats = [];
  String? _catSel;
  int _abiertos = 0, _enEspera = 0;
  PuestoResumen? _destacado;
  List<PuestoResumen> _tendencias = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _catalogo.categorias().then((c) {
      if (mounted) setState(() => _cats = c);
    }).catchError((_) {});
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait<Object?>([
        _svc.resumen(),
        _svc.destacado(idCategoria: _catSel),
        _svc.tendencias(idCategoria: _catSel),
      ]);
      final resumen = r[0] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _abiertos = (resumen['abiertos'] as num?)?.toInt() ?? 0;
        _enEspera = (resumen['en_espera'] as num?)?.toInt() ?? 0;
        _destacado = r[1] as PuestoResumen?;
        _tendencias = r[2] as List<PuestoResumen>;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _cargando = false;
        });
      }
    }
  }

  void _elegirCategoria(String? id) {
    if (_catSel == id) return;
    _catSel = id;
    _cargar();
  }

  void _abrirPuesto(PuestoResumen p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PuestoScreen(puesto: p)));

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _chips(),
          const SizedBox(height: 14),
          _resumen(),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No se pudo cargar el inicio.\n$_error\n\n'
                  'Desliza hacia abajo para volver a intentar.'),
            )
          else if (_cargando && _destacado == null && _tendencias.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: Tg.amarillo)),
            )
          else ...[
            if (_destacado != null) _tarjetaDestacado(_destacado!),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TituloPincel('Tendencias y Novedades', icono: Icons.campaign),
            ),
            const SizedBox(height: 12),
            _tendenciasLista(),
          ],
        ],
      ),
    );
  }

  Widget _chips() => SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChipCategoria(
                  texto: 'Todos',
                  icono: Icons.storefront,
                  seleccionado: _catSel == null,
                  onTap: () => _elegirCategoria(null)),
            ),
            for (final c in _cats)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChipCategoria(
                    texto: c['nombre'] as String,
                    icono: iconoCategoria(c['nombre'] as String),
                    seleccionado: _catSel == c['id'],
                    onTap: () => _elegirCategoria(c['id'] as String)),
              ),
          ],
        ),
      );

  Widget _resumen() {
    Widget dato(IconData i, Color c, int n, String etiqueta, Color colorNum, VoidCallback? onTap) =>
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, color: c, size: 34),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('$n', style: Tg.marcador(34, color: colorNum)),
                  Text(etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 0.9)),
                ]),
              ]),
            ),
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Tg.azulOscuro.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Row(children: [
        dato(Icons.check_circle, const Color(0xFF2EAD5B), _abiertos, 'ABIERTOS AHORA',
            Tg.azulClaro, widget.onVerPuestos),
        Container(width: 1.5, height: 46, color: Colors.white24),
        dato(Icons.schedule, Tg.amarillo, _enEspera, 'EN ESPERA', Tg.amarillo, null),
      ]),
    );
  }

  Widget _tarjetaDestacado(PuestoResumen p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Tg.azulOscuro,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.6), width: 2),
      ),
      child: Stack(children: [
        Positioned.fill(child: ImagenPuesto(p.imagenUrl)),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.10), Tg.azulOscuro.withValues(alpha: 0.94)],
                stops: const [0.05, 0.72],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Flexible(
                    child: EtiquetaPincel(
                        texto: 'DESTACADO DE LA SEMANA', icono: Icons.workspace_premium, angulo: -0.03)),
                SizedBox(width: 56),
              ]),
              const SizedBox(height: 110),
              Text(p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Tg.marcador(40)),
              const SizedBox(height: 4),
              if (p.ubicacion.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: EtiquetaPincel(
                    texto: 'SE PONE EN: ${p.ubicacion}',
                    color: const Color(0xFF1E8E3E),
                    colorTexto: Colors.white,
                    icono: Icons.location_on,
                    angulo: -0.025,
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                _pildora(Icons.star, Tg.amarillo,
                    p.calificaciones == 0 ? 'Nuevo' : p.promedio.toStringAsFixed(1),
                    fondo: Tg.azulOscuro, borde: Tg.azulClaro),
                _pildora(Icons.favorite, Colors.white, '${p.guardados} Guardados',
                    fondo: Tg.rosa, borde: Tg.rosa),
              ]),
              if ((p.descripcion ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.descripcion!, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, height: 1.15)),
              ],
              const SizedBox(height: 16),
              Center(
                child: BotonPincel(texto: 'Ver Puesto Destacado', onPressed: () => _abrirPuesto(p)),
              ),
            ]),
          ),
        ),
        Positioned(top: 12, right: 12, child: BotonCorazon(idPuesto: p.id)),
      ]),
    );
  }

  Widget _pildora(IconData i, Color c, String t, {required Color fondo, required Color borde}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borde, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 20, color: c),
          const SizedBox(width: 5),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );

  Widget _tendenciasLista() {
    if (_tendencias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Text('Todavía no hay puestos para mostrar aquí.'),
      );
    }
    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tendencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _tarjetaTendencia(_tendencias[i]),
      ),
    );
  }

  static const _coloresCat = [Color(0xFF1976D2), Tg.rosa, Color(0xFFE65100), Color(0xFF6A1B9A), Color(0xFF00897B)];
  Color _colorCategoria(String n) =>
      _coloresCat[n.codeUnits.fold<int>(0, (a, b) => a + b) % _coloresCat.length];

  Widget _tarjetaTendencia(PuestoResumen p) {
    return GestureDetector(
      onTap: () => _abrirPuesto(p),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Tg.azulOscuro,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.55), width: 1.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: SizedBox(height: 124, width: double.infinity, child: ImagenPuesto(p.imagenUrl)),
            ),
            Positioned(top: 8, right: 8, child: BotonCorazon(idPuesto: p.id)),
            Positioned(
              left: 10,
              bottom: -22,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Tg.azulClaro, width: 2),
                  color: Tg.azulOscuro,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
          ]),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              if (p.categoria != null)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                  decoration: BoxDecoration(
                    color: _colorCategoria(p.categoria!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.categoria!.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E8E3E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF7CE0A0)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on, size: 16, color: Tg.rosa),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(p.ubicacion.isEmpty ? 'SIN UBICACIÓN' : p.ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Tg.amarillo,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _abrirPuesto(p),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(Icons.add, color: Tg.azulOscuro, size: 24),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
