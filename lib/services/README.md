# services/ · Los que hacen el trabajo

Un servicio es un archivo que **hace cosas de verdad**: guardar un dato, buscar
productos, mandar un mensaje. Las pantallas no hablan directamente con la base
de datos; le piden el trabajo a un servicio.

La base de datos y el inicio de sesión los da **Supabase**.

| Archivo | Se encarga de | Requisitos |
|---|---|---|
| `auth_service.dart` | Registro, código por correo, entrar, cerrar sesión, términos | RF-01 a 05, 40 |
| `catalogo_service.dart` | Buscar y filtrar productos | RF-06 a 08 |
| `puestos_service.dart` | Puestos abiertos, mapa, visitas, calificaciones y las etiquetas públicas de un puesto (`etiquetas_puesto`) | RF-09, 10, 41, 42 |
| `chat_service.dart` | Conversaciones, mensajes, reportes y bloqueos | RF-16, 37, 38, 44 |
| `tratos_service.dart` | Propuestas de precio y apartados | RF-17, 18, 31, 32 |
| `vendedor_service.dart` | Perfil, horarios, productos, ofertas y espacios del vendedor | RF-19 a 36 |
| `admin_service.dart` | Panel del administrador: tianguis, reportes, apelaciones | RF-47 a 54 |
| `inicio_service.dart` | Datos de la pantalla de inicio | — |
| `comprador_id.dart` | Averigua cuál es el comprador de la sesión actual | — |
| `favoritos_cambios.dart` | Avisa a los corazones abiertos cuando cambia un favorito | RF-11 |
| `tutorial.dart` | Recuerda en el teléfono si ya se mostró el recorrido de bienvenida | — |
| `ocultos.dart` | Recuerda lo que la persona quitó de su lista en ese teléfono | — |
