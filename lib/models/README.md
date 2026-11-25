# models/ · Las «cosas» de TianGuía

Cada archivo aquí es una **clase del diagrama de clases**. Una clase describe
una cosa del negocio: qué datos tiene (por ejemplo, un Puesto tiene nombre y
ubicación) y qué puede hacer.

Se ordenan en carpetas con los **mismos módulos del diagrama**:

| Carpeta | Módulo del diagrama | Clases |
|---|---|---|
| [`inicio_sesion/`](inicio_sesion/) | Inicio de sesión | **Usuario** |
| [`comprador/`](comprador/) | Comprador | Comprador, Visita, Calificacion |
| [`vendedor/`](vendedor/) | Vendedor | Vendedor, VendedorTianguis |
| [`comunes/`](comunes/) | Funciones comunes y de confianza | Conversacion, Mensaje, Participante, Reporte, Apelacion |

Todavía en archivos agrupados (pendientes de separar de la misma forma):

- `modelos.dart`: Tianguis, Puesto, Producto (y sus fotos/resúmenes).
- `tratos.dart`: Propuesta, Apartado, Oferta.

`entidades.dart` ya no tiene clases: solo apunta a las carpetas de arriba para
que el código viejo siga funcionando.

**NOTA** una clase no «piensa» ni se conecta sola a la base de datos.
Cuando necesita hacer algo (guardar, buscar), se lo pide a un archivo de
`services/`.
