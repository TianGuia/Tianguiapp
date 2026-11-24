# Guía del código · de los diagramas a los archivos

Cada clase del diagrama de clases tiene su archivo. Esta tabla dice cuál es.

## Dónde está cada clase del diagrama

| Módulo | Clase | Archivo |
|---|---|---|
| Inicio de sesión | **Usuario** | `lib/models/inicio_sesion/usuario.dart` |
| Comprador | Comprador | `lib/models/comprador/comprador.dart` |
| Comprador | Visita | `lib/models/comprador/visita.dart` |
| Comprador | Calificacion | `lib/models/comprador/calificacion.dart` |
| Comprador | Apartado | `lib/models/tratos.dart` |
| Vendedor | Vendedor | `lib/models/vendedor/vendedor.dart` |
| Vendedor | Vendedor_Tianguis | `lib/models/vendedor/vendedor_tianguis.dart` |
| Vendedor | Puesto, Producto | `lib/models/modelos.dart` |
| Vendedor | Oferta | `lib/models/tratos.dart` |
| Funciones comunes | Conversacion | `lib/models/comunes/conversacion.dart` |
| Funciones comunes | Mensaje | `lib/models/comunes/mensaje.dart` |
| Funciones comunes | Participante | `lib/models/comunes/participante.dart` |
| Funciones comunes | Reporte | `lib/models/comunes/reporte.dart` |
| Funciones comunes | Apelacion | `lib/models/comunes/apelacion.dart` |
| Administración | Tianguis | `lib/models/modelos.dart` |

## ¿Dónde está la clase Usuario?

La persona no es Usuario hasta que se registra. Usuario es la cuenta que se crea
al registrarse, y está en `lib/models/inicio_sesion/usuario.dart`. De ahí salen
Comprador y Vendedor, y una misma cuenta puede ser las dos cosas.

## Módulos y carpetas

Los módulos de los diagramas son carpetas dentro de `lib/models/`. No son
clases, solo agrupan las clases que van juntas.

## Carpetas de `lib/`

- `screens/`: lo que se ve y se toca. Hay pantallas de inicio de sesión, de comprador, de vendedor,
  de chat y moderación, y las del administrador.
- `widgets/`: piezas que se repiten en varias pantallas, como el corazón de favoritos o el fondo.
- `services/`: hablan con Supabase, iniciar sesión, mandar mensajes, buscar productos.
- `models/`: las clases del diagrama, una carpeta por módulo.
- `config/`: colores, tipografía y datos de conexión.

`app.dart` decide a qué pantalla va la persona y `main.dart` arranca la app.

## Dónde se cumple cada requisito

En el código, cada lugar que cumple un requisito tiene un comentario que empieza con `rf-` y el número.
Para ver todos: `grep -rn "rf-" lib`.
