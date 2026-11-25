import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';
import '../services/chat_service.dart';
import '../services/inicio_service.dart';
import '../services/tutorial.dart';
import '../widgets/aviso_conexion.dart';
import '../widgets/cerrar_sesion.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';
import 'catalogo_tab.dart';
import 'chats_screen.dart';
import 'diagnostico_screen.dart';
import 'inicio_tab.dart';
import 'notificaciones_screen.dart';
import 'perfil_tab.dart';
import 'tutorial_screen.dart';
import 'puestos_tab.dart';
import 'vendedor_tab.dart';

class HomeScreen extends StatefulWidget {
  // vistaPrueba: el administrador la abre desde su panel y puede volver con un toque
  final bool vistaPrueba;
  const HomeScreen({super.key, this.vistaPrueba = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _llave = GlobalKey<ScaffoldState>();
  final _inicio = InicioService();
  int _i = 0;
  int _noLeidas = 0;
  int _mensajesSinLeer = 0;

  @override
  void initState() {
    super.initState();
    _contarNoLeidas();
    _tutorialPrimeraVez();
  }

  // la primera vez en este telefono se muestra el recorrido de como funciona la app
  Future<void> _tutorialPrimeraVez() async {
    if (!await Tutorial.debeMostrarse() || !mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen()));
  }

  Future<void> _contarNoLeidas() async {
    try {
      final n = await _inicio.noLeidas();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {/* la campana simplemente no muestra número */}
    try {
      final m = await ChatService().totalNoLeidos();
      if (mounted) setState(() => _mensajesSinLeer = m);
    } catch (_) {/* sin número en la insignia de mensajes */}
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    _contarNoLeidas();
  }

  void _abrirPuestos() => _ir(ScaffoldTg(
        appBar: AppBar(title: const Text('Puestos abiertos')),
        body: const PuestosTab(),
      ));

  void _abrirMapa() => _ir(ScaffoldTg(
        appBar: AppBar(title: const Text('Mapa de puestos')),
        body: const PuestosTab(iniciaEnMapa: true),
      ));

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      InicioTab(onVerPuestos: _abrirPuestos, onVerMapa: _abrirMapa),
      const CatalogoTab(),
      const VendedorTab(),
      const PerfilTab(),
    ];

    return Fondo(
      child: Scaffold(
        key: _llave,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          centerTitle: false,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 32),
            onPressed: () => _llave.currentState?.openDrawer(),
          ),
          title: Padding(
            padding: const EdgeInsets.only(left: 50),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/images/icono_app.png', height: 58, width: 58, fit: BoxFit.cover),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 28),
              tooltip: 'Mapa de puestos',
              onPressed: _abrirMapa,
            ),
            IconButton(
              icon: const Icon(Icons.search, size: 28),
              tooltip: 'Buscar',
              onPressed: () => setState(() => _i = 1),
            ),
            IconButton(
              tooltip: 'Notificaciones',
              icon: Badge(
                backgroundColor: Tg.rosa,
                label: Text('$_noLeidas'),
                isLabelVisible: _noLeidas > 0,
                child: const Icon(Icons.notifications_none, size: 28),
              ),
              onPressed: () => _ir(const NotificacionesScreen()),
            ),
            IconButton(
              icon: Badge(
                backgroundColor: Tg.rosa,
                label: Text('$_mensajesSinLeer'),
                isLabelVisible: _mensajesSinLeer > 0,
                child: const Icon(Icons.chat_bubble_outline, size: 26),
              ),
              tooltip: 'Mensajes',
              onPressed: () => _ir(const ChatsScreen()),
            ),
          ],
        ),
        drawer: _menu(),
        body: Column(children: [
          if (widget.vistaPrueba)
            Material(
              color: Tg.amarillo,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                child: const SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.arrow_back, size: 20, color: Tg.azulOscuro),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Modo prueba · Volver al panel de administración',
                            style: TextStyle(color: Tg.azulOscuro, fontWeight: FontWeight.w900)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          const AvisoConexion(),
          Expanded(child: IndexedStack(index: _i, children: tabs)),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) {
            if (v == 4) {
              _ir(const ChatsScreen()); // Mensajes abre su pantalla, no es una pestaña
            } else {
              setState(() => _i = v);
              _contarNoLeidas();
            }
          },
          destinations: [
            const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
            const NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
            const NavigationDestination(icon: Icon(Icons.store_mall_directory), label: 'Mi puesto'),
            const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
            NavigationDestination(
              icon: Badge(
                backgroundColor: Tg.rosa,
                label: Text('$_mensajesSinLeer'),
                isLabelVisible: _mensajesSinLeer > 0,
                child: const Icon(Icons.chat_bubble_outline),
              ),
              label: 'Mensajes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _menu() {
    Widget item(IconData icono, String texto, VoidCallback onTap,
        {bool activo = false, Color color = Tg.azulClaro}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: activo ? Tg.amarillo : Tg.azulOscuro.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: activo ? Tg.azulOscuro : Tg.azulClaro.withValues(alpha: 0.35), width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pop(context); // cierra el menú
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(children: [
                SelloTg(icono: icono, color: activo ? Tg.azulOscuro : color, tam: 38,
                    colorIcono: activo ? Tg.amarillo : Tg.azulOscuro),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texto,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: activo ? Tg.azulOscuro : Colors.white)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: Tg.azul,
      child: SafeArea(
        child: Column(children: [
          const Padding(padding: EdgeInsets.fromLTRB(0, 22, 0, 18), child: Wordmark(tam: 34)),
          Expanded(
            child: ListView(children: [
              item(Icons.home_rounded, 'Inicio', () => setState(() => _i = 0), activo: _i == 0, color: Tg.amarillo),
              item(Icons.search, 'Explorar productos', () => setState(() => _i = 1), activo: _i == 1, color: Tg.azulClaro),
              item(Icons.storefront, 'Puestos abiertos', _abrirPuestos, color: Tg.verde),
              item(Icons.map_outlined, 'Mapa de puestos', _abrirMapa, color: Tg.naranja),
              item(Icons.chat_bubble_rounded, 'Mis mensajes', () => _ir(const ChatsScreen()), color: Tg.amarillo),
              item(Icons.notifications_rounded, 'Notificaciones', () => _ir(const NotificacionesScreen()), color: Tg.naranja),
              item(Icons.store_mall_directory, 'Mi puesto', () => setState(() => _i = 2), activo: _i == 2, color: Tg.rosa),
              item(Icons.person, 'Mi perfil', () => setState(() => _i = 3), activo: _i == 3, color: Tg.azulClaro),
              item(Icons.bug_report_outlined, 'Diagnóstico de conexión',
                  () => _ir(const DiagnosticoScreen()), color: Tg.verde),
              if (widget.vistaPrueba)
                item(Icons.arrow_back, 'Volver al panel', () => Navigator.of(context).pop(), color: Tg.amarillo)
              else
                item(Icons.logout, 'Cerrar sesión', () => confirmarCerrarSesion(context), color: Tg.rojo),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 22),
            child: Transform.rotate(
              angle: -0.08,
              child: Text('¡GRACIAS\nPOR TU PREFERENCIA!',
                  textAlign: TextAlign.center, style: Tg.marcador(15)),
            ),
          ),
        ]),
      ),
    );
  }
}
