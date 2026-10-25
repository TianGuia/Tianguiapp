# TianGuía · Flutter + Supabase

App Android (Flutter/Dart) con Supabase como backend. Diseño tomado de tus pantallas:
fondo azul con pinceladas, letra tipo marcador, chips amarillos, tarjeta "Destacado de la semana".

## 1. Crear el proyecto y copiar esta base
```bash
flutter create --org mx.udg --platforms=android tianguia
# copia encima de la carpeta creada: lib/, assets/, supabase/, pubspec.yaml
rm test/widget_test.dart          # el de ejemplo ya no aplica
flutter pub get
dart run flutter_launcher_icons   # ícono de la app (el de tu diseño)
dart run flutter_native_splash:create   # pantalla de arranque azul con el logo
```
Nombre que ve el usuario bajo el ícono: en `android/app/src/main/AndroidManifest.xml`
cambia `android:label="tianguia"` por `android:label="TianGuía"`.

## 2. Permisos de Android
En `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
En `android/app/build.gradle(.kts)` verifica `minSdk = 21` o mayor.
Las fuentes (`google_fonts`) se descargan la primera vez con internet.

## 3. Supabase
1. **Revisa tus ENUM** (en el esquema salen como USER-DEFINED). En el SQL Editor:
   ```sql
   select t.typname, string_agg(e.enumlabel, ', ' order by e.enumsortorder)
   from pg_type t join pg_enum e on e.enumtypid = t.oid group by t.typname;
   ```
   El código asume: `estado_puesto` = abierto/cerrado, `estado_vendedor` = activo,
   `estado_oferta` = activa/finalizada, `contexto` de conversaciones = producto,
   `estado_articulo` = nuevo. Si tus valores son distintos, cámbialos en
   `supabase/01_setup.sql` y en los servicios Dart.
2. Ejecuta `supabase/01_setup.sql`, después `supabase/02_seed.sql` y por último
   `supabase/03_puestos_gestion.sql` (columnas de descripción/foto/cierre del puesto y trigger) y
   `supabase/04_tratos_ofertas.sql` (responder propuestas/apartados, vencimientos, cron).
   Si el 04 se detiene diciendo que faltan valores en un ENUM, ejecuta las líneas `alter type` que te muestra
   (una por una) y vuelve a correrlo.
3. Authentication > Providers > Email: activa **Email OTP**. En Email Templates (Magic Link)
   usa `{{ .Token }}` para que el correo traiga el código de 6 dígitos.
4. Hazte admin (después de registrarte): `insert into administradores (id_usuario)
   select id from usuarios where correo = 'tu_correo';`

## 4. Correr
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_KEY=TU_PUBLISHABLE_KEY
```
Nunca pongas la clave `service_role` en la app.

## Estructura
- `lib/config/` → tema (colores y fuentes) y datos de Supabase.
- `lib/widgets/` → fondo con pinceladas, botón/etiquetas/chips estilo pincel, corazón, flujo de visita.
- `lib/services/` → un servicio por módulo (auth, catálogo, inicio, puestos, vendedor, chat).
- `lib/screens/` → bienvenida, login con código, home (menú lateral + 4 pestañas:
  Inicio, Explorar, Mi puesto, Perfil), detalle de puesto, notificaciones, chat, diagnóstico.
- `supabase/01_setup.sql` → trigger de alta, RLS de las 38 tablas, funciones (abrir/cerrar puesto,
  código de visita, confirmar visita, resumen/destacado/tendencias del inicio), Realtime y Storage.
- `assets/` → logo y archivos del ícono generados desde tu imagen.

## Cosas que decidí y conviene revisar
- **"15 verificados / 76 en espera"** del diseño no tiene equivalente en la base; el inicio muestra
  *Abiertos ahora* (puestos con estado `abierto`) y *En espera* (puestos activos cerrados).
- **Día del tianguis** (`LUNES`, `VIERNES`): `dia_semana` se interpreta como 0 = domingo … 6 = sábado.
- **Destacado de la semana**: el puesto con mejor promedio de calificaciones (desempata por
  calificaciones y guardados). La categoría del puesto sale de la que más usan sus productos.
- **Privacidad**: la política de `usuarios` deja que un usuario vea la fila de los vendedores y de
  quien chatea con él, y esa fila incluye `correo`. Si no quieres exponerlo, crea una vista pública
  (`id, nombre_publico, foto_url`) y que la app lea de ahí.
- Carrito, pedidos y métodos de pago del diseño de ejemplo (tacos) **no están**: TianGuía no vende
  dentro de la app; se usan chat, propuesta de precio y apartado.

## Pendiente
(Hecho en el paso 2: bandeja de propuestas/contraofertas y apartados, ofertas relámpago, vencimiento automático.)
(Hecho en el paso 1: editar/eliminar puesto, cierre temporal o hasta nuevo aviso, descripción y foto del puesto, editar producto, varias fotos.)

Mapa visual (flutter_map u OSM), pantallas de propuestas/apartados (el servicio ya existe), pantalla de
favoritos, ofertas y anuncios de espacios, notificaciones push (FCM + Edge Function), panel de administración.

## Guion de prueba (con el Diagnóstico)
1. Entrar (código por correo, o "modo desarrollo" con contraseña; desactiva "Confirm email" en Supabase).
2. Perfil > **Diagnóstico de conexión**: todo en verde.
3. Mi puesto > habilitar vendedor > crear puesto > "YA LLEGUÉ · ABRIR" (da permiso de ubicación).
4. Mi puesto > MIS PRODUCTOS > agregar con foto y stock.
5. Con OTRA cuenta: Inicio (debe salir el puesto), Explorar (buscar), detalle: chat, propuesta, apartado, favorito.
6. Vendedor: "Generar código de visita". Comprador: "Ya visité este puesto" > código > calificar.

## Prueba del paso 1
1. Mi puesto > **+ Puesto**: nombre, descripción, foto > crear. Menú ⋮ del puesto > **Editar**.
2. ⋮ > **Cerrar temporalmente** (motivo y fecha de regreso) o **Cerrar hasta nuevo aviso**.
   Con otra cuenta, abre el puesto desde Inicio: debe verse el estado, el motivo y la fecha.
3. "YA LLEGUÉ · ABRIR" quita el cierre especial (lo limpia el trigger).
4. ⋮ > **Eliminar puesto**: desaparece; sus productos siguen en MIS PRODUCTOS sin puesto.
5. MIS PRODUCTOS > toca un producto: edita datos, agrega hasta 6 fotos, quita fotos, cambia stock.

## Prueba del paso 2 (necesitas DOS cuentas: vendedor y comprador)
1. Comprador: detalle de un producto > **PROPONER PRECIO** y **SOLICITAR APARTADO**.
2. Vendedor: Mi puesto > **PROPUESTAS Y APARTADOS** (el número rosa son pendientes).
   Propuesta: Aceptar / Contraofertar / Rechazar. Apartado: Aceptar (descuenta piezas) / Rechazar.
3. Comprador: Perfil > **Mis propuestas y apartados**. Si el vendedor contraofertó, el comprador
   puede aceptar, rechazar o contraofertar de vuelta. Un apartado aceptado se puede cancelar (libera piezas).
4. Vendedor: **OFERTAS RELÁMPAGO** > Oferta: título, hora de fin, productos y % o precio fijo.
   El comprador ve el precio tachado y el de oferta en el detalle del producto.
5. Vencimiento: pon una oferta que termine en 2 minutos; la app la marca como terminada al abrir
   la lista (y pg_cron lo hace cada 10 min si está disponible).
