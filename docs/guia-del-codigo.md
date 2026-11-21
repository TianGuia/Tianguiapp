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
