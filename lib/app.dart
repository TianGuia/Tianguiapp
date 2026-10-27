import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/acceso_screen.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/terminos_screen.dart';
import 'services/auth_service.dart';

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

/// Sin sesión -> Bienvenida / Acceso. Con sesión (anónima o con correo) -> Home.
/// Si la sesión ya existía al abrir la app y hay una versión nueva de los
/// términos, se pide aceptarla antes de entrar (RF-53). Las sesiones iniciadas
/// en esta ejecución ya aceptaron los términos vigentes al entrar.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _revisarTerminos = Supabase.instance.client.auth.currentSession != null;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = Supabase.instance.client.auth.currentSession;
        if (sesion == null) {
          _revisarTerminos = false;
          return const _Entrada();
        }
        // La llave por usuario reinicia las pestañas si cambia de usuario
        // (al verificar el correo el id NO cambia, así que no se reinicia).
        final home = HomeScreen(key: ValueKey(sesion.user.id));
        if (!_revisarTerminos) return home;
        return _PuertaTerminos(
          key: ValueKey('terminos-${sesion.user.id}'),
          child: home,
        );
      },
    );
  }
}

/// RF-53: muestra los términos pendientes y deja pasar al aceptarlos.
/// Si no se pueden consultar (sin red, función ausente), no bloquea la app.
class _PuertaTerminos extends StatefulWidget {
  final Widget child;
  const _PuertaTerminos({super.key, required this.child});
  @override
  State<_PuertaTerminos> createState() => _PuertaTerminosState();
}

class _PuertaTerminosState extends State<_PuertaTerminos> {
  late Future<List<Map<String, dynamic>>> _futuro = _consultar();

  Future<List<Map<String, dynamic>>> _consultar() async {
    try {
      return await AuthService().terminosPendientes();
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futuro,
      builder: (_, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final pendientes = s.data ?? const [];
        if (pendientes.isEmpty) return widget.child;
        return TerminosScreen(
          pendientes: pendientes,
          onAceptado: () => setState(() => _futuro = _consultar()),
        );
      },
    );
  }
}

enum _Paso { bienvenida, acceso, login }

/// Bienvenida ("COMENZAR") -> elegir nombre (acceso anónimo).
/// Desde ahí, "Ya tengo cuenta" lleva al login con correo.
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
        return BienvenidaScreen(onComenzar: () => setState(() => _paso = _Paso.acceso));
      case _Paso.acceso:
        return AccesoScreen(
          onVolver: () => setState(() => _paso = _Paso.bienvenida),
          onTengoCuenta: () => setState(() => _paso = _Paso.login),
        );
      case _Paso.login:
        return LoginScreen(onVolver: () => setState(() => _paso = _Paso.acceso));
    }
  }
}
