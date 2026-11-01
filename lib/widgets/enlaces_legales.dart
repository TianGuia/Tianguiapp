import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../screens/documento_screen.dart';

/// Enlaces "Ver condiciones de uso" y "Ver aviso de privacidad" que se ponen
/// junto a la casilla de aceptación, para que se pueda leer a qué se está aceptando.
class EnlacesLegales extends StatelessWidget {
  const EnlacesLegales({super.key});

  void _abrir(BuildContext c, String tipo, String titulo) => Navigator.of(c)
      .push(MaterialPageRoute(builder: (_) => DocumentoScreen(tipo: tipo, titulo: titulo)));

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, color: Tg.amarillo);
    return Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
      TextButton(
        onPressed: () => _abrir(context, 'terminos', 'Condiciones de uso'),
        child: const Text('Ver condiciones de uso', style: estilo),
      ),
      TextButton(
        onPressed: () => _abrir(context, 'privacidad', 'Aviso de privacidad'),
        child: const Text('Ver aviso de privacidad', style: estilo),
      ),
    ]);
  }
}
