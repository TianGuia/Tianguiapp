import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
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

/// Muestra Bienvenida/Login o Home según haya sesión activa.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = Supabase.instance.client.auth.currentSession;
        return sesion == null ? const _Entrada() : const HomeScreen();
      },
    );
  }
}

/// Bienvenida ("COMENZAR") y, al tocar, el formulario de acceso.
class _Entrada extends StatefulWidget {
  const _Entrada();
  @override
  State<_Entrada> createState() => _EntradaState();
}

class _EntradaState extends State<_Entrada> {
  bool _login = false;

  @override
  Widget build(BuildContext context) {
    return _login
        ? LoginScreen(onVolver: () => setState(() => _login = false))
        : BienvenidaScreen(onComenzar: () => setState(() => _login = true));
  }
}
