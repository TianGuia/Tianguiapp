import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/theme.dart';
import 'screens/bienvenida_screen.dart';
import 'screens/home_screen.dart';

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

/// Sin sesión -> Bienvenida (el comprador elige un nombre; vendedor/admin hace login).
/// Con sesión (anónima o con correo) -> Home.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final sesion = Supabase.instance.client.auth.currentSession;
        if (sesion == null) return const BienvenidaScreen();
        // La llave por usuario reinicia las pestañas al cambiar de usuario.
        return HomeScreen(key: ValueKey(sesion.user.id));
      },
    );
  }
}
