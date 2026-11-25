import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/acceso_screen.dart';
import 'screens/admin_home_screen.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/terminos_screen.dart';
import 'services/auth_service.dart';
import 'widgets/cerrar_sesion.dart';

class TianGuiaApp extends StatelessWidget {
  const TianGuiaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TianGuía',
        debugShowCheckedModeBanner: false,
        theme: Tg.tema,
        home: const AuthGate(),
      );
}

// sin sesion va a bienvenida o acceso, con sesion va al home
// si ya habia sesion y hay terminos nuevos primero se piden aceptar
// RF-53 se cumple aqui: si hay condiciones nuevas se pide aceptarlas antes de seguir
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String?>(
        valueListenable: AuthService.sesionOculta,
        builder: (context, oculta, _) => ValueListenableBuilder<bool>(
          valueListenable: AuthService.entrandoAdmin,
          builder: (context, entrandoAdmin, _) =>
              _contenido(entrandoAdmin, oculta != null),
        ),
      );

  Widget _contenido(bool entrandoAdmin, bool sesionOculta) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = Supabase.instance.client.auth.currentSession;
        // sin sesion, o con la sesion anonima "cerrada" en este telefono.
        if (sesion == null || sesionOculta) {
          return const _Entrada();
        }
        // validando el acceso de administrador: no mostrar la app de comprador.
        if (entrandoAdmin) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // la llave por usuario reinicia las pestañas si cambia el usuario
        // al verificar el correo el id no cambia, asi que no se reinicia
        final home = HomeScreen(key: ValueKey(sesion.user.id));
        final destino = _PuertaTerminos(
            key: ValueKey('terminos-${sesion.user.id}'), child: home);
        return _PuertaRol(
            key: ValueKey('rol-${sesion.user.id}'), usuario: destino);
      },
    );
  }
}

class _PuertaRol extends StatefulWidget {
  final Widget usuario;
  const _PuertaRol({super.key, required this.usuario});
  @override
  State<_PuertaRol> createState() => _PuertaRolState();
}

class _PuertaRolState extends State<_PuertaRol> {
  int _version = -1;
  Future<bool>? _futuro;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AuthService.cambioRol,
      builder: (_, v, __) {
        if (v != _version || _futuro == null) {
          _version = v;
          _futuro = AuthService().esAdmin();
        }
        return FutureBuilder<bool>(
          future: _futuro,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            return s.data == true ? const AdminHomeScreen() : widget.usuario;
          },
        );
      },
    );
  }
}

class _PuertaTerminos extends StatefulWidget {
  final Widget child;
  const _PuertaTerminos({super.key, required this.child});

  @override
  State<_PuertaTerminos> createState() => _PuertaTerminosState();
}

class _PuertaTerminosState extends State<_PuertaTerminos>
    with WidgetsBindingObserver {
  final _db = Supabase.instance.client;
  late final RealtimeChannel _documentos;
  List<Map<String, dynamic>>? _pendientes;
  bool _error = false;
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _documentos = _db.channel('documentos-vigentes')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'versiones_documento',
        callback: (_) => _consultar(),
      )
      ..subscribe((estado, _) {
        if (estado == RealtimeSubscribeStatus.subscribed) _consultar();
      });
    _consultar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_db.removeChannel(_documentos));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _consultar();
  }

  Future<void> _consultar() async {
    if (!mounted) return;
    final consulta = ++_consulta;
    List<Map<String, dynamic>>? pendientes;
    try {
      pendientes = await AuthService().terminosPendientes();
    } catch (_) {
      // Una consulta fallida no autoriza la entrada.
    }
    if (!mounted || consulta != _consulta) return;
    final estabaEnLaApp = _pendientes?.isEmpty ?? false;
    setState(() {
      _pendientes = pendientes;
      _error = pendientes == null;
    });
    if (estabaEnLaApp && (pendientes == null || pendientes.isNotEmpty)) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        appBar: AppBar(title: const Text('Condiciones de uso y privacidad')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No pudimos verificar los documentos vigentes.',
                    textAlign: TextAlign.center),
                FilledButton(
                    onPressed: _consultar, child: const Text('Reintentar')),
                TextButton(
                  onPressed: () => confirmarCerrarSesion(context),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final pendientes = _pendientes;
    if (pendientes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (pendientes.isEmpty) return widget.child;
    return TerminosScreen(
      pendientes: pendientes,
      onAceptado: _consultar,
      onRecargar: _consultar,
    );
  }
}

enum _Paso { bienvenida, acceso, login }

class _Entrada extends StatefulWidget {
  const _Entrada();
  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> {
  _Paso _paso = _Paso.bienvenida;

  @override
  Widget build(BuildContext context) {
    switch (_paso) {
      case _Paso.bienvenida:
        return BienvenidaScreen(
            onComenzar: () => setState(() => _paso = _Paso.acceso));
      case _Paso.acceso:
        return AccesoScreen(
          onVolver: () => setState(() => _paso = _Paso.bienvenida),
          onTengoCuenta: () => setState(() => _paso = _Paso.login),
        );
      case _Paso.login:
        return LoginScreen(
            onVolver: () => setState(() => _paso = _Paso.acceso));
    }
  }
}
