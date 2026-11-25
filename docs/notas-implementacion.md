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

## Valoraciones, etiquetas y fallas (necesita Toldo `20261128000000`)
- **Etiquetas**: las que el comprador elige al calificar las ve cualquier usuario en el puesto, solo como
  conteo ("Amable ×5"), mediante la función `etiquetas_puesto`. Si la migración no está aplicada, no salen.
- **Comentarios**: son privados. Solo los leen quien calificó, el vendedor calificado y el administrador.
  La app lo avisa en la ventana de calificar; la regla real está en la política `calif_select` de Toldo.
  Antes de esa migración cualquier usuario con sesión podía leer la tabla completa.
- **Reportar una falla**: Perfil > Ajustes y avisos. Se guarda en `reportes_falla` y el administrador la
  lee en el panel (icono del bicho). No está ligada a un requisito funcional.
- **Tutorial**: recorrido de 4 tarjetas (encontrar puestos, platicar con el vendedor, visitar y calificar, vender).
  Sale solo la primera vez que se abre el inicio en cada teléfono (`shared_preferences`, llave `tutorial_visto`)
  y se repite desde Perfil > Cómo funciona. No viene en los requisitos del PDF; entra por RNF-1 (usabilidad).
  No usa la base de datos.
- **Estilo**: las ventanas emergentes salen con el estilo de la app desde `theme.dart`, sin tocar cada una.

## Pendiente
- Avisos (RF-12 a RF-14): Toldo genera los avisos y llama a la función de entrega push. Queda por confirmar la entrega en móvil.
- Pruebas automáticas: solo hay de autenticación y de entradas. Faltan chat, apartados, propuestas,
  moderación y administración.

## Guion de prueba
1. Entrar como comprador anónimo o iniciar sesión por código de correo.
2. Perfil > **Diagnóstico de conexión**: todo en verde.
3. Mi puesto > habilitar vendedor > crear puesto > "YA LLEGUÉ · ABRIR" (da permiso de ubicación).
4. Mi puesto > MIS PRODUCTOS > agregar con foto y stock.
5. Con otra cuenta: Inicio (debe salir el puesto), Explorar (buscar), detalle: chat, propuesta, apartado, favorito.
6. Vendedor: "Generar código de visita". Comprador: "Ya visité este puesto" > código > calificar.
   Con una tercera cuenta (sin visita), comprobar que en el puesto se ven las etiquetas pero no el comentario.
7. Teléfono nuevo o datos de la app borrados: al entrar debe salir el tutorial; al terminar o saltar no vuelve a salir solo.
8. Perfil > Reportar una falla: enviar uno y verlo como administrador en el icono del bicho.

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
