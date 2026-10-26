import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/acceso_screen.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

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
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = Supabase.instance.client.auth.currentSession;
        if (sesion == null) return const _Entrada();
        // La llave por usuario reinicia las pestañas si cambia de usuario
        // (al verificar el correo el id NO cambia, así que no se reinicia).
        return HomeScreen(key: ValueKey(sesion.user.id));
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
