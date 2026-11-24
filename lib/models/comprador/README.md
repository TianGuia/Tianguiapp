# comprador/ · Quien busca en el tianguis

**Módulo del diagrama:** Comprador · **Requisitos:** RF-06, 07, 17, 41, 42

| Archivo | Para qué sirve |
|---|---|
| `comprador.dart` | El rol de comprador: buscar productos, filtrar y proponer un precio. |
| `visita.dart` | Confirma que el comprador **de verdad estuvo** en un puesto (con un código que le da el vendedor). |
| `calificacion.dart` | La opinión que deja después de una visita confirmada. |

**Cómo se conectan:** Comprador hace una Visita → la Visita confirmada le
permite dejar una Calificación. Sin visita no hay calificación; así se evitan
opiniones falsas.
