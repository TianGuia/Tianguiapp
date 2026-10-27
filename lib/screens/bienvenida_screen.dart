import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';

/// Primera pantalla: logo, lema y botón COMENZAR.
class BienvenidaScreen extends StatelessWidget {
  final VoidCallback onComenzar;
  const BienvenidaScreen({super.key, required this.onComenzar});

  @override
  Widget build(BuildContext context) {
    return Fondo(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: Image.asset('assets/icon/icon.png', width: 280, height: 280),
                ),
                const SizedBox(height: 20),
                Transform.rotate(
                  angle: -0.1,
                  child: Text('COMIDA, ANTOJITOS\nY MÁS…',
                      textAlign: TextAlign.center,
                      style: Tg.marcador(22)),
                ),
                const SizedBox(height: 40),
                BotonPincel(texto: 'COMENZAR', onPressed: onComenzar),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
