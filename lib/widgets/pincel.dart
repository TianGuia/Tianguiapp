import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Botón amarillo estilo pincel con flecha (COMENZAR →, Ver puesto destacado →).
class BotonPincel extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;
  final bool cargando;
  const BotonPincel({
    super.key,
    required this.texto,
    this.icono = Icons.arrow_forward,
    this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.018,
      child: Material(
        color: Tg.amarillo,
        elevation: 4,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: cargando ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(texto,
                      overflow: TextOverflow.ellipsis,
                      style: Tg.marcador(19, color: Tg.azulOscuro)),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Tg.azulOscuro,
                  child: cargando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Tg.amarillo))
                      : Icon(icono, size: 19, color: Tg.amarillo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta inclinada (DESTACADO DE LA SEMANA, SE PONE EN: …).
class EtiquetaPincel extends StatelessWidget {
  final String texto;
  final Color color;
  final Color colorTexto;
  final double angulo;
  final IconData? icono;
  const EtiquetaPincel({
    super.key,
    required this.texto,
    this.color = Tg.amarillo,
    this.colorTexto = Tg.azulOscuro,
    this.angulo = -0.04,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angulo,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[
            Icon(icono, size: 18, color: colorTexto),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: Tg.marcador(13, color: colorTexto)),
          ),
        ]),
      ),
    );
  }
}

/// Título de sección con subrayado amarillo ("Tendencias y Novedades").
class TituloPincel extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Color colorIcono;
  const TituloPincel(this.texto, {super.key, this.icono, this.colorIcono = Tg.rosa});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (icono != null) ...[
        Icon(icono, color: colorIcono, size: 38),
        const SizedBox(width: 8),
      ],
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texto, style: Tg.marcador(23)),
          Container(
            height: 4,
            width: 170,
            decoration: BoxDecoration(
              color: Tg.amarillo,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// Chip de categoría: amarillo cuando está elegido, contorno azul si no.
class ChipCategoria extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final bool seleccionado;
  final VoidCallback onTap;
  const ChipCategoria({
    super.key,
    required this.texto,
    this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = seleccionado ? Tg.azulOscuro : Colors.white;
    return Material(
      color: seleccionado ? Tg.amarillo : Tg.azulOscuro.withValues(alpha: 0.45),
      shape: StadiumBorder(
        side: BorderSide(color: seleccionado ? Tg.amarillo : Tg.azulClaro.withValues(alpha: 0.55), width: 1.6),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icono != null) ...[Icon(icono, size: 20, color: fg), const SizedBox(width: 6)],
            Text(texto,
                style: GoogleFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 15, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Icono según el nombre de la categoría (Chacharas, Comida, Frutas, Ropa, Servicios…).
IconData iconoCategoria(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('chachar') || n.contains('antig')) return Icons.handyman;
  if (n.contains('comida') || n.contains('antojit')) return Icons.restaurant;
  if (n.contains('fruta') || n.contains('verdura')) return Icons.eco;
  if (n.contains('ropa') || n.contains('calzado')) return Icons.checkroom;
  if (n.contains('servicio')) return Icons.settings;
  return Icons.sell;
}
