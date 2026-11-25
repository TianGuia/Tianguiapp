import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import 'fondo.dart';
import 'pincel.dart';

// kit de diseño urbano: las piezas que repiten todas las pantallas de usuario y vendedor
// mismo fondo pintado y mismos colores del home, con sombras duras tipo sticker

const List<BoxShadow> _sombraDura = [
  BoxShadow(color: Color(0x59000000), offset: Offset(3, 4), blurRadius: 0),
];

// fecha corta para listas: hora si es de hoy, "Ayer" o dia/mes
String fechaRelativa(DateTime? f) {
  if (f == null) return '';
  final ahora = DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final dia = DateTime(f.year, f.month, f.day);
  final dif = hoy.difference(dia).inDays;
  if (dif == 0) return '${dos(f.hour)}:${dos(f.minute)}';
  if (dif == 1) return 'Ayer';
  return '${dos(f.day)}/${dos(f.month)}';
}

// scaffold con el mismo fondo pintado que el home, para pantallas que se abren encima
class ScaffoldTg extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;
  const ScaffoldTg({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Theme(
      data: tema.copyWith(
        appBarTheme: tema.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: Fondo(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        ),
      ),
    );
  }
}

// cinta verde, blanco y rojo, firma de la app
class CintaTricolor extends StatelessWidget {
  final double alto;
  const CintaTricolor({super.key, this.alto = 5});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: alto,
        child: const Row(children: [
          Expanded(child: ColoredBox(color: Tg.verde, child: SizedBox.expand())),
          Expanded(child: ColoredBox(color: Colors.white, child: SizedBox.expand())),
          Expanded(child: ColoredBox(color: Tg.rojo, child: SizedBox.expand())),
        ]),
      );
}

// cuadrito de color con icono, ligeramente chueco como calcomania
class SelloTg extends StatelessWidget {
  final IconData icono;
  final Color color;
  final double tam;
  final Color colorIcono;
  final double angulo;
  const SelloTg({
    super.key,
    required this.icono,
    required this.color,
    this.tam = 46,
    this.colorIcono = Tg.azulOscuro,
    this.angulo = -0.07,
  });

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angulo,
        child: Container(
          width: tam,
          height: tam,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(tam * 0.27),
            border: Border.all(color: Tg.azulOscuro, width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(2, 3), blurRadius: 0)],
          ),
          child: Icon(icono, size: tam * 0.56, color: colorIcono),
        ),
      );
}

// tarjeta base: fondo azul oscuro, borde claro, sombra dura y franja de color opcional
class TarjetaTg extends StatelessWidget {
  final Widget child;
  final Color? acento;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margen;
  const TarjetaTg({
    super.key,
    required this.child,
    this.acento,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(14),
    this.margen = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(18);
    return Padding(
      padding: margen,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radio, boxShadow: _sombraDura),
        child: Material(
          color: Tg.azulOscuro.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: radio,
            side: BorderSide(color: Tg.azulClaro.withValues(alpha: 0.45), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(children: [
              Padding(
                padding: padding.add(EdgeInsets.only(left: acento != null ? 7 : 0)),
                child: child,
              ),
              if (acento != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 7,
                  child: ColoredBox(color: acento!),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Card con el mismo look de sticker (sombra dura y borde claro) para listas con ListTile
class CardTg extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  const CardTg({super.key, required this.child, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(18);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radio, boxShadow: _sombraDura),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Tg.azulOscuro.withValues(alpha: 0.9),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: radio,
            side: BorderSide(color: Tg.azulClaro.withValues(alpha: 0.45), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class DatoTg {
  final IconData icono;
  final Color color;
  final String valor;
  final String etiqueta;
  final VoidCallback? onTap;
  const DatoTg(this.icono, this.color, this.valor, this.etiqueta, {this.onTap});
}

// banner de arriba de cada pantalla: sello, titulo a mano, subtitulo y numeritos
class CabeceraTg extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icono;
  final Color color;
  final List<DatoTg> datos;
  const CabeceraTg({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.icono,
    this.color = Tg.amarillo,
    this.datos = const [],
  });

  Widget _dato(DatoTg d) => InkWell(
        onTap: d.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(d.icono, color: d.color, size: 28),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(d.valor, style: Tg.marcador(26, color: d.color)),
              Text(d.etiqueta,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, height: 0.9)),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Tg.azulOscuro.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.5), width: 1.5),
        boxShadow: _sombraDura,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(children: [
            SelloTg(icono: icono, color: color, tam: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tg.marcador(24)),
                if (subtitulo != null)
                  Text(subtitulo!,
                      style: GoogleFonts.baloo2(
                          color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14, height: 1.1)),
              ]),
            ),
          ]),
        ),
        if (datos.isNotEmpty)
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12, width: 1.5))),
            child: Row(children: [
              for (var i = 0; i < datos.length; i++) ...[
                if (i > 0) Container(width: 1.5, height: 40, color: Colors.white24),
                Expanded(child: _dato(datos[i])),
              ],
            ]),
          ),
        const CintaTricolor(),
      ]),
    );
  }
}

// rotulo de seccion: texto a mano y una raya
class SeccionTg extends StatelessWidget {
  final String texto;
  const SeccionTg(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Row(children: [
          Text(texto.toUpperCase(), style: Tg.marcador(15, color: Tg.amarillo)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ]),
      );
}

// renglon de menu: sello de color, titulo, subtitulo y flecha
class OpcionTg extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? subtitulo;
  final int badge;
  final VoidCallback? onTap;
  const OpcionTg({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    this.subtitulo,
    this.badge = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => TarjetaTg(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        margen: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(children: [
          SelloTg(icono: icono, color: color, tam: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.1)),
              if (subtitulo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitulo!,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.1)),
                ),
            ]),
          ),
          if (badge > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(color: Tg.rosa, borderRadius: BorderRadius.circular(12)),
              child: Text('$badge', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          const Icon(Icons.chevron_right, color: Colors.white54),
        ]),
      );
}

// cuadro grande de color para accesos rapidos, va dentro de un GridView de 2 columnas
class MosaicoTg extends StatelessWidget {
  final IconData icono;
  final Color color;
  final Color colorTexto;
  final String titulo;
  final int badge;
  final double angulo;
  final VoidCallback? onTap;
  const MosaicoTg({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    this.colorTexto = Tg.azulOscuro,
    this.badge = 0,
    this.angulo = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(20);
    return Transform.rotate(
      angle: angulo,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radio, boxShadow: _sombraDura),
        child: Material(
          color: color,
          borderRadius: radio,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(children: [
              // adorno de fondo nitido: circulo grande y puntitos, sin iconos borrosos
              Positioned(
                right: -26,
                bottom: -30,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorTexto.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // sello azul oscuro con borde blanco y icono blanco: se ve en cualquier color de tarjeta
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Tg.azulOscuro,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66000000), offset: Offset(2, 3), blurRadius: 0),
                        ],
                      ),
                      child: Icon(icono, size: 26, color: Colors.white),
                    ),
                    const Spacer(),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                        decoration: BoxDecoration(
                          color: Tg.rosa,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('$badge',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                  ]),
                  const Spacer(),
                  Text(titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Tg.marcador(16, color: colorTexto).copyWith(height: 1.05)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// cuadricula de mosaicos que no hace scroll por si sola
class RejillaMosaicos extends StatelessWidget {
  final List<Widget> hijos;
  const RejillaMosaicos({super.key, required this.hijos});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.3,
        children: hijos,
      );
}

// circulo con la inicial de la persona, o su foto si la tiene
class AvatarTg extends StatelessWidget {
  final String nombre;
  final String? fotoUrl;
  final double radio;
  const AvatarTg({super.key, required this.nombre, this.fotoUrl, this.radio = 24});

  static const _colores = [Tg.amarillo, Tg.rosa, Tg.naranja, Tg.azulClaro, Color(0xFF2EAD5B)];

  @override
  Widget build(BuildContext context) {
    final n = nombre.trim();
    final inicial = n.isEmpty ? '?' : String.fromCharCode(n.runes.first).toUpperCase();
    final color = _colores[n.codeUnits.fold<int>(0, (a, b) => a + b) % _colores.length];
    final foto = (fotoUrl ?? '').isEmpty ? null : fotoUrl;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      child: CircleAvatar(
        radius: radio,
        backgroundColor: color,
        backgroundImage: foto == null ? null : NetworkImage(foto),
        onBackgroundImageError: foto == null ? null : (_, __) {},
        child: foto == null
            ? Text(inicial, style: Tg.marcador(radio * 0.95, color: Tg.azulOscuro))
            : null,
      ),
    );
  }
}

// pastillita de estado o dato corto
class PildoraTg extends StatelessWidget {
  final String texto;
  final Color color;
  final Color colorTexto;
  final IconData? icono;
  const PildoraTg(this.texto,
      {super.key, this.color = Tg.amarillo, this.colorTexto = Tg.azulOscuro, this.icono});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[Icon(icono, size: 14, color: colorTexto), const SizedBox(width: 4)],
          Flexible(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorTexto, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
      );
}

// fondo rojo que sale al deslizar para borrar
class FondoBorrar extends StatelessWidget {
  final EdgeInsetsGeometry margen;
  const FondoBorrar({super.key, this.margen = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});

  @override
  Widget build(BuildContext context) => Container(
        margin: margen,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: Tg.rojo, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      );
}

// pantalla vacia (o con error) con personalidad: sello grande, titulo a mano y una accion opcional
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Color color;
  final String? accionTexto;
  final IconData accionIcono;
  final VoidCallback? onAccion;
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.mensaje,
    this.color = Tg.amarillo,
    this.accionTexto,
    this.accionIcono = Icons.arrow_forward,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 170,
              height: 140,
              child: Stack(alignment: Alignment.center, children: [
                Transform.rotate(
                  angle: 0.14,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: _sombraDura,
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Tg.azulOscuro,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(icono, size: 54, color: color),
                  ),
                ),
                Positioned(top: 4, right: 14, child: Icon(Icons.star_rounded, color: Tg.rosa, size: 26)),
                Positioned(bottom: 8, left: 10, child: Icon(Icons.circle, color: Tg.verde, size: 14)),
              ]),
            ),
            const SizedBox(height: 14),
            Text(titulo, textAlign: TextAlign.center, style: Tg.marcador(24)),
            const SizedBox(height: 8),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, color: Colors.white70, height: 1.2, fontWeight: FontWeight.w600)),
            if (accionTexto != null && onAccion != null) ...[
              const SizedBox(height: 22),
              BotonPincel(texto: accionTexto!, icono: accionIcono, onPressed: onAccion),
            ],
          ]),
        ),
      );
}

// carga con el circulo amarillo de siempre
class CargandoTg extends StatelessWidget {
  const CargandoTg({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Tg.amarillo));
}

// ventana emergente con el look de la app: sello de color, titulo a mano y botones abajo
class DialogoTg extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final Widget child;
  final List<Widget> acciones;
  const DialogoTg({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
    this.color = Tg.amarillo,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Tg.azulOscuro,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Tg.azulClaro.withValues(alpha: 0.6), width: 2),
            boxShadow: _sombraDura,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    SelloTg(icono: icono, color: color, tam: 44),
                    const SizedBox(width: 12),
                    Expanded(child: Text(titulo, style: Tg.marcador(21))),
                  ]),
                  const SizedBox(height: 14),
                  child,
                ]),
              ),
            ),
            if (acciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(children: [
                  for (var i = 0; i < acciones.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: acciones[i]),
                  ],
                ]),
              ),
            const CintaTricolor(),
          ]),
        ),
      );
}

// renglon con interruptor: sello de color, texto y switch, para listas de preferencias
class InterruptorTg extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;
  final bool valor;
  final ValueChanged<bool> onChanged;
  const InterruptorTg({
    super.key,
    required this.icono,
    required this.color,
    required this.texto,
    required this.valor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TarjetaTg(
        onTap: () => onChanged(!valor),
        acento: valor ? color : null,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        margen: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(children: [
          SelloTg(icono: icono, color: color, tam: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
          ),
          Switch(value: valor, onChanged: onChanged),
        ]),
      );
}

// ficha para elegir (categorias, etiquetas): amarilla cuando esta elegida
class FichaTg extends StatelessWidget {
  final String texto;
  final bool elegida;
  final ValueChanged<bool> onCambio;
  const FichaTg({super.key, required this.texto, required this.elegida, required this.onCambio});

  @override
  Widget build(BuildContext context) => Material(
        color: elegida ? Tg.amarillo : Tg.azulOscuro.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: elegida ? Tg.azulOscuro : Tg.azulClaro.withValues(alpha: 0.55), width: 1.5),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onTap: () => onCambio(!elegida),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (elegida) ...[
                const Icon(Icons.check_rounded, size: 17, color: Tg.azulOscuro),
                const SizedBox(width: 4),
              ],
              Text(texto,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: elegida ? Tg.azulOscuro : Colors.white)),
            ]),
          ),
        ),
      );
}
