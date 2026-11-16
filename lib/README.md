# lib/ · El código de la app

Aquí vive todo lo que hace funcionar TianGuía. Está dividido en carpetas, cada
una con un trabajo distinto. Una forma fácil de entenderlo es pensar en un
restaurante:

| Carpeta | En el restaurante | Qué hace en TianGuía |
|---|---|---|
| `screens/` | El comedor | Lo que la persona **ve y toca**: pantallas y pestañas. |
| `widgets/` | La vajilla | Piezas visuales que se **reutilizan** en varias pantallas (botones, fondo, corazón de favoritos). |
| `services/` | La cocina | Lo que **hace el trabajo**: hablar con la base de datos, iniciar sesión, mandar mensajes. |
| `models/` | El menú | Las **cosas del negocio** (Usuario, Puesto, Producto…) tal como las muestra el diagrama de clases. |
| `config/` | El reglamento | Colores, tipografía y datos de conexión. |

Flujo típico: la persona toca algo en una **pantalla** → la pantalla le pide el
trabajo a un **servicio** → el servicio habla con la base de datos y regresa
**modelos** (Producto, Puesto…) → la pantalla los muestra.

Archivos sueltos:

- `main.dart`: el botón de encendido. Arranca la app.
- `app.dart`: decide a qué pantalla mandar a la persona (bienvenida, inicio,
  panel de administrador o aceptar términos nuevos).

Para ubicar una clase del diagrama en el código, mira
[`docs/guia-del-codigo.md`](../docs/guia-del-codigo.md).
