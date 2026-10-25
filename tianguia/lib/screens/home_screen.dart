import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/inicio_service.dart';
import '../widgets/fondo.dart';
import '../widgets/pincel.dart';
import 'catalogo_tab.dart';
import 'chats_screen.dart';
import 'diagnostico_screen.dart';
import 'inicio_tab.dart';
import 'notificaciones_screen.dart';
import 'perfil_tab.dart';
import 'puestos_tab.dart';
import 'vendedor_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _llave = GlobalKey<ScaffoldState>();
  final _inicio = InicioService();
  int _i = 0;
  int _noLeidas = 0;

  @override
  void initState() {
    super.initState();
    _contarNoLeidas();
  }

  Future<void> _contarNoLeidas() async {
    try {
      final n = await _inicio.noLeidas();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {/* la campana simplemente no muestra número */}
  }

  Future<void> _ir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    _contarNoLeidas();
  }

  void _abrirPuestos() => _ir(Scaffold(
        appBar: AppBar(title: const Text('Puestos abiertos')),
        body: const PuestosTab(),
      ));

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      InicioTab(onVerPuestos: _abrirPuestos),
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
          toolbarHeight: 66,
          leading: IconButton(
            icon: const Icon(Icons.menu, size: 32),
            onPressed: () => _llave.currentState?.openDrawer(),
          ),
          title: const Wordmark(tam: 26),
          actions: [
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
              icon: const Icon(Icons.chat_bubble_outline, size: 26),
              tooltip: 'Mensajes',
              onPressed: () => _ir(const ChatsScreen()),
            ),
          ],
        ),
        drawer: _menu(),
        body: IndexedStack(index: _i, children: tabs),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
            NavigationDestination(icon: Icon(Icons.store_mall_directory), label: 'Mi puesto'),
            NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _menu() {
    Widget item(IconData icono, String texto, VoidCallback onTap, {bool activo = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: activo ? Tg.amarillo : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.pop(context); // cierra el menú
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(icono, color: activo ? Tg.azulOscuro : Colors.white, size: 26),
                const SizedBox(width: 14),
                Text(texto,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: activo ? Tg.azulOscuro : Colors.white)),
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
              item(Icons.home_rounded, 'Inicio', () => setState(() => _i = 0), activo: _i == 0),
              item(Icons.search, 'Explorar productos', () => setState(() => _i = 1), activo: _i == 1),
              item(Icons.storefront, 'Puestos abiertos', _abrirPuestos),
              item(Icons.chat_bubble_outline, 'Mis mensajes', () => _ir(const ChatsScreen())),
              item(Icons.notifications_none, 'Notificaciones', () => _ir(const NotificacionesScreen())),
              item(Icons.store_mall_directory, 'Mi puesto', () => setState(() => _i = 2), activo: _i == 2),
              item(Icons.person_outline, 'Mi perfil', () => setState(() => _i = 3), activo: _i == 3),
              item(Icons.bug_report_outlined, 'Diagnóstico de conexión',
                  () => _ir(const DiagnosticoScreen())),
              item(Icons.logout, 'Cerrar sesión', () => AuthService().cerrarSesion()),
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
