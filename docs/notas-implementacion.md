# Notas y pruebas manuales

Aquí van decisiones que tomamos y pasos para probar la app a mano. Cómo instalarla
está en el [README](../README.md), los iconos en [iconos](iconos.md) y el backend
en [Toldo](https://github.com/Tianguia/Toldo).

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

## Decisiones que conviene revisar
- **Inicio**: muestra *Abiertos ahora* (puestos con estado `abierto`) y *En espera* (puestos activos
  cerrados). No hay un dato de "verificados" en la base.
- **Día del tianguis** (`LUNES`, `VIERNES`): `dia_semana` se interpreta como 0 = domingo … 6 = sábado.
- **Destacado de la semana**: el puesto con mejor promedio de calificaciones (desempata por
  calificaciones y guardados). La categoría del puesto sale de la que más usan sus productos.
- **Privacidad**: la política de `usuarios` deja que un usuario vea la fila de los vendedores y de
  quien chatea con él, y esa fila incluye `correo`. Si no quieres exponerlo, crea una vista pública
  (`id, nombre_publico, foto_url`) y que la app lea de ahí.
- **No hay carrito, pedidos ni pagos**: TianGuía no vende dentro de la app, se usan chat, propuesta de
  precio y apartado.

## Pendiente
- Avisos (RF-07, RF-08, RF-09): existen la pantalla de notificaciones y las preferencias, pero la app
  no crea los avisos ni manda notificaciones push. Falta revisar si Toldo los genera con triggers.
- Pruebas automáticas: solo hay de autenticación y de entradas. Faltan chat, apartados, propuestas,
  moderación y administración.

## Guion de prueba
1. Entrar como comprador anónimo o iniciar sesión por código de correo.
2. Perfil > **Diagnóstico de conexión**: todo en verde.
3. Mi puesto > habilitar vendedor > crear puesto > "YA LLEGUÉ · ABRIR" (da permiso de ubicación).
4. Mi puesto > MIS PRODUCTOS > agregar con foto y stock.
5. Con otra cuenta: Inicio (debe salir el puesto), Explorar (buscar), detalle: chat, propuesta, apartado, favorito.
6. Vendedor: "Generar código de visita". Comprador: "Ya visité este puesto" > código > calificar.

## Prueba de puestos y productos
1. Mi puesto > **+ Puesto**: nombre, descripción, foto > crear. Menú ⋮ del puesto > **Editar**.
2. ⋮ > **Cerrar temporalmente** (motivo y fecha de regreso) o **Cerrar hasta nuevo aviso**.
   Con otra cuenta, abre el puesto desde Inicio: debe verse el estado, el motivo y la fecha.
3. "YA LLEGUÉ · ABRIR" quita el cierre especial (lo limpia el trigger).
4. ⋮ > **Eliminar puesto**: desaparece; sus productos siguen en MIS PRODUCTOS sin puesto.
5. MIS PRODUCTOS > toca un producto: edita datos, agrega hasta 6 fotos, quita fotos, cambia stock.

## Prueba de propuestas, apartados y ofertas (necesitas dos cuentas: vendedor y comprador)
1. Comprador: detalle de un producto > **PROPONER PRECIO** y **SOLICITAR APARTADO**.
2. Vendedor: Mi puesto > **PROPUESTAS Y APARTADOS** (el número rosa son pendientes).
   Propuesta: Aceptar / Contraofertar / Rechazar. Apartado: Aceptar (descuenta piezas) / Rechazar.
3. Comprador: Perfil > **Mis propuestas y apartados**. Si el vendedor contraofertó, el comprador
   puede aceptar, rechazar o contraofertar de vuelta. Un apartado aceptado se puede cancelar (libera piezas).
4. Vendedor: **OFERTAS RELÁMPAGO** > Oferta: título, hora de fin, productos y % o precio fijo.
   El comprador ve el precio tachado y el de oferta en el detalle del producto.
5. Vencimiento: pon una oferta que termine en 2 minutos; la app la marca como terminada al abrir
   la lista (y pg_cron lo hace cada 10 min si está disponible).
