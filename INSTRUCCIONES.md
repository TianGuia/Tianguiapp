# Acceso anónimo en TianGuía

## 1. Supabase (dashboard)
1. Authentication > Sign In / Providers > activa **Allow anonymous sign-ins**.
2. Authentication > Email Templates > **Change Email Address**: debe incluir `{{ .Token }}`
   (el código de 6 dígitos), igual que el template del login por código.
   Sin eso, al verificar el correo llega un enlace y no un código.
3. SQL Editor: ejecuta `supabase/05_anonimo.sql`.

## 2. App
Copia estos archivos sobre tu proyecto (respeta las rutas):
- lib/app.dart, lib/services/auth_service.dart
- lib/screens/: acceso_screen.dart (nuevo), verificar_contacto_screen.dart (nuevo),
  vendedor_tab.dart, perfil_tab.dart, home_screen.dart
- lib/widgets/cerrar_sesion.dart (nuevo)

`login_screen.dart` y `bienvenida_screen.dart` NO cambian.

## Flujo
Bienvenida (COMENZAR) -> nombre + condiciones -> Home (cuenta anónima).
Mi puesto -> HABILITAR PERFIL -> verifica correo (misma cuenta) -> perfil de vendedor.
"Ya tengo cuenta con correo" -> login por código (otro celular / reinstalación).

## Pruebas
1. Entrar con un nombre: en `auth.users` debe salir `is_anonymous = true`.
2. Habilitar vendedor: pide correo, luego el código; el `id` en `auth.users` NO cambia
   y `is_anonymous` pasa a false; `usuarios.correo` se llena.
3. Intentar insertar en `perfiles_vendedor` con un anónimo debe fallar (trigger).
