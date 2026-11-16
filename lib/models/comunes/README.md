# comunes/ · Lo que usan compradores y vendedores por igual

**Módulo del diagrama:** Funciones comunes y de confianza · **Requisitos:** RF-16, 35, 37, 44, 46

| Archivo | Para qué sirve |
|---|---|
| `conversacion.dart` | Un chat privado entre dos personas. |
| `mensaje.dart` | Cada mensaje dentro de un chat. |
| `participante.dart` | Dice quién está en cada chat (une Usuario con Conversación). |
| `reporte.dart` | Aviso de que algo rompe las reglas. Lo revisa el administrador. |
| `apelacion.dart` | Petición para que se revise de nuevo una decisión de moderación. |

**Flujo de confianza:** alguien envía un **Reporte** → el administrador decide →
si la persona afectada no está de acuerdo, presenta una **Apelación**.
