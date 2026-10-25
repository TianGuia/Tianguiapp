import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'catalogo_tab.dart';
import 'puestos_tab.dart';
import 'vendedor_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _i = 0;
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    // Un comprador sin cuenta no ve el panel "Mi puesto".
    final anonimo = _auth.esAnonimo;
    final tabs = <Widget>[
      const PuestosTab(),
      const CatalogoTab(),
      if (!anonimo) const VendedorTab(),
      const _PerfilTab(),
    ];
    final destinos = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.storefront), label: 'Puestos'),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Catálogo'),
      if (!anonimo)
        const NavigationDestination(icon: Icon(Icons.store_mall_directory), label: 'Mi puesto'),
      const NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
    ];
    final i = _i < tabs.length ? _i : 0;

    return Scaffold(
      body: SafeArea(child: tabs[i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: destinos,
      ),
    );
  }
}

class _PerfilTab extends StatefulWidget {
  const _PerfilTab();
  @override
  State<_PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<_PerfilTab> {
  final _auth = AuthService();
  late Future<Map<String, dynamic>?> _futuro = _auth.miPerfil();

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  /// RF-05: cambiar el nombre público.
  Future<void> _editarNombre(String actual) async {
    final c = TextEditingController(text: actual);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar nombre'),
        content: TextField(
          controller: c,
          maxLength: 30,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(hintText: 'Nombre de usuario'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final n = c.text.trim();
    if (ok != true || n.isEmpty) return;
    try {
      await _auth.actualizarPerfil(nombre: n);
      setState(() => _futuro = _auth.miPerfil());
    } catch (e) {
      _msg('No se pudo guardar: $e');
    }
  }

  /// El comprador sin cuenta sale de su usuario para entrar como vendedor/admin.
  Future<void> _irAAccesoVendedor() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de este usuario?'),
        content: const Text(
            'Para entrar como vendedor o administrador saldrás de este usuario. '
            'Tus favoritos y conversaciones de este usuario no se podrán recuperar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (ok == true) await _auth.cerrarSesion(); // AuthGate muestra la Bienvenida
  }

  @override
  Widget build(BuildContext context) {
    final anonimo = _auth.esAnonimo;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _futuro,
      builder: (_, s) {
        final p = s.data;
        final nombre = (p?['nombre_publico'] as String?) ?? '…';
        return ListView(padding: const EdgeInsets.all(20), children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 12),
          Text(nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(anonimo ? 'Comprador' : (p?['correo'] ?? ''), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: p == null ? null : () => _editarNombre(nombre),
            icon: const Icon(Icons.edit),
            label: const Text('CAMBIAR NOMBRE'),
          ),
          const SizedBox(height: 12),
          if (anonimo)
            FilledButton(
              onPressed: _irAAccesoVendedor,
              child: const Text('SOY VENDEDOR O ADMINISTRADOR'),
            )
          else
            FilledButton(onPressed: _auth.cerrarSesion, child: const Text('CERRAR SESIÓN')),
        ]);
      },
    );
  }
}
