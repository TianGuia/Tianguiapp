# screens/ · Lo que la persona ve

Cada archivo es una **pantalla** (o una pestaña). Las pantallas muestran
información y reaccionan a lo que la persona toca. Para el trabajo pesado,
llaman a `services/`.

## Inicio de sesión
`bienvenida_screen` · `acceso_screen` · `login_screen` · `verificar_contacto_screen` ·
`editar_perfil_screen` · `terminos_screen` · `documento_screen`

## Comprador
`home_screen` (contenedor con las pestañas) · `inicio_tab` · `catalogo_tab` ·
`puestos_tab` · `mapa_puestos_screen` · `puesto_screen` · `producto_detalle_screen` ·
`favoritos_screen` · `perfil_tab` · `preferencias_notificacion_screen` · `notificaciones_screen`

## Vendedor
`vendedor_tab` · `puesto_form_screen` · `mis_productos_screen` · `ofertas_screen` ·
`horarios_screen` · `tratos_screen` · `espacios_screen` · `valoraciones_screen`

## Comunes y de confianza
`chats_screen` · `chat_screen` · `medidas_screen`

## Administración
`admin_entrada_screen` · `admin_home_screen`

## Soporte
`diagnostico_screen`: revisa que la conexión con la base de datos funcione.

> `admin_home_screen.dart` es muy largo (más de 1,600 líneas). Una mejora
> futura sería partirlo en una pantalla por sección.
