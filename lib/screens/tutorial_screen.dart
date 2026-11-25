import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/tutorial.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';

class _Paso {
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;
  const _Paso(this.icono, this.color, this.titulo, this.texto);
}

// recorrido corto de como funciona TianGuia; sale la primera vez y despues desde Perfil > Cómo funciona
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  static const _pasos = <_Paso>[
    _Paso(Icons.map_rounded, Tg.verde, 'Encuentra puestos abiertos',
        'En Inicio y en el mapa ves qué puestos están abiertos hoy y dónde se pusieron. También puedes buscar productos y guardar tus favoritos.'),
    _Paso(Icons.chat_bubble_rounded, Tg.amarillo, 'Platica con el vendedor',
        'Escríbele, propón un precio o pide que te aparte un producto. En TianGuía no se paga: el trato se cierra en persona, directo con el vendedor.'),
    _Paso(Icons.star_rounded, Tg.rosa, 'Visita y califica',
        'Cuando llegues al puesto, el vendedor te da un código. Con él confirmas tu visita y dejas tus estrellas y etiquetas. Tu comentario solo lo lee el vendedor.'),
    _Paso(Icons.storefront_rounded, Tg.naranja, '¿Tú también vendes?',
        'En Mi puesto creas tu puesto, subes tus productos y pulsas «Ya llegué» al abrir. Así los compradores saben que sí estás.'),
  ];

  final _control = PageController();
  int _i = 0;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _terminar() async {
    await Tutorial.marcarVisto();
    if (mounted) Navigator.pop(context);
  }

  void _siguiente() {
    if (_i == _pasos.length - 1) {
      _terminar();
    } else {
      _control.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Widget _pagina(_Paso p) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 10, 28, 10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 20),
          SelloTg(icono: p.icono, color: p.color, tam: 150, angulo: -0.08),
          const SizedBox(height: 34),
          Text(p.titulo, textAlign: TextAlign.center, style: Tg.marcador(28)),
          const SizedBox(height: 14),
          Text(p.texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, height: 1.2, fontWeight: FontWeight.w700, color: Colors.white70)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final ultimo = _i == _pasos.length - 1;
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 12, 0),
                child: TextButton(
                  onPressed: _terminar,
                  child: Text(ultimo ? '' : 'SALTAR', style: Tg.marcador(15, color: Tg.amarillo)),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _control,
                onPageChanged: (v) => setState(() => _i = v),
                children: [for (final p in _pasos) Center(child: _pagina(p))],
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < _pasos.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: k == _i ? 26 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: k == _i ? Tg.amarillo : Colors.white30,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
              child: BotonPincel(
                texto: ultimo ? '¡A TIANGUEAR!' : 'SIGUIENTE',
                icono: ultimo ? Icons.check_rounded : Icons.arrow_forward,
                onPressed: _siguiente,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
