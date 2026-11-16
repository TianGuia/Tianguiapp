# Guía del código · de los diagramas a los archivos

Para quien no sabe por dónde empezar. Cada clase del diagrama de clases tiene
su archivo. Si la maestra pide «muéstrame la clase X», aquí está dónde.

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

## «¿Dónde está la clase Usuario si cualquiera que entra es usuario?»

Respuesta corta para la presentación:

> *«La persona no es Usuario hasta que se registra. Usuario es la cuenta que el
> sistema crea al registrarse. Está en `models/inicio_sesion/usuario.dart`, con
> los mismos atributos y métodos del diagrama. De ahí salen Comprador y
> Vendedor, y una misma cuenta puede tener ambos roles (especialización
> solapada).»*

## Módulos = carpetas

En los diagramas, los **módulos** son los recuadros de colores. En el código son
las carpetas dentro de `lib/models/`. Los módulos **no son clases**: son
agrupaciones que contienen clases.

## Cómo escribir comentarios (sin sonar a robot ni a manual técnico)

1. **Explica el para qué, no el cómo.** El código ya dice cómo; el comentario
   dice por qué existe.
2. **Habla como le explicarías a un compañero.** Frases cortas, sin jerga.
3. **Si usas una palabra técnica, explícala una vez** («entidad asociativa: une
   dos cosas»).
4. **Pon el número de requisito (RF-xx)** para que se pueda rastrear al SRS.
5. **No comentes lo obvio.** `// suma 1` sobre `i++` sobra.
6. **Escríbelos con tus palabras.** Si suena a texto copiado, reescríbelo.

Ejemplo:

```dart
// ❌ Técnico:
/// Invoca el servicio de autenticación para persistir la sesión.

// ✅ Claro:
/// RF-03 · Volver a entrar con el código que llega al correo.
```

## Guion para videos cortos (2–3 min cada uno)

1. **El mapa general** (`lib/README.md`): restaurante, flujo
   pantalla → servicio → modelo.
2. **Del diagrama al código**: abrir el diagrama de clases y luego
   `models/`, mostrando que cada caja tiene su archivo.
3. **Un recorrido completo**: registro → habilitar vendedor → abrir puesto.
   Seguir el camino por `acceso_screen` → `auth_service` → `usuario.dart`.
4. **Cómo comentar y subir cambios**: esta guía + `git add / commit / push`.
