# Notas de implementación y pruebas manuales

La app activa está en la raíz del repositorio. La instalación y ejecución
se documentan en el [README](../README.md), los iconos en
[Iconos de la app](iconos.md) y el backend en
[Toldo](https://github.com/Tianguia/Toldo). Las antiguas copias de la app,
paquetes ZIP y scripts SQL se conservan únicamente en el historial de Git.

## Acceso anónimo y habilitación de vendedores

El backend debe permitir acceso anónimo y códigos OTP por correo. Consulta
Toldo para aplicar sus migraciones y configurar autenticación y permisos.

1. Entrar con nombre y condiciones: se crea una cuenta anónima de comprador.
2. Mi puesto > HABILITAR PERFIL > verificar correo: se conserva la misma cuenta
   y se habilita el perfil de vendedor.
3. En el backend, comprobar que el identificador no cambia y que la cuenta deja
   de ser anónima tras verificar el correo.
4. Comprobar que un comprador anónimo no puede crear un perfil de vendedor
   directamente sin verificar su cuenta.
5. Ya tengo cuenta con correo permite iniciar sesión por código en otro equipo.

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
1. Entrar como comprador anónimo o iniciar sesión por código de correo.
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
