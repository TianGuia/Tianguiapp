# Colaborar en TianGuía

¡Gracias por tu interés en TianGuía! Este proyecto está abierto a aportaciones de código, diseño, documentación, pruebas, accesibilidad e ideas de personas que conocen los tianguis de primera mano.

Esta guía busca facilitar el trabajo entre quienes desarrollamos la aplicación habitualmente y quienes contribuyen de manera ocasional. No pretende imponer una forma única de programar: preferimos acuerdos sencillos, cambios comprensibles y comunicación oportuna.

## Antes de empezar

- Consulta el [README](README.md) para conocer la aplicación, su configuración y las tecnologías que utilizamos.
- Revisa las [incidencias](https://github.com/Tianguia/Tianguiapp/issues) y los pull requests existentes para descubrir trabajos relacionados. No hace falta abrir una incidencia para corregir una errata o realizar una mejora pequeña y evidente.
- Si planeas una función nueva, un cambio que afecte a varios módulos o una decisión técnica importante, comenta primero tu propuesta en una incidencia o discusión. Basta con explicar qué quieres resolver y cómo piensas abordarlo.
- Quienes trabajamos en el equipo también podemos organizarnos en nuestro tablero interno. Las personas externas no necesitan acceso a él para colaborar.

Las propuestas son bienvenidas incluso si todavía no hay una solución definida. Preguntar o cuestionar una decisión técnica es parte normal del desarrollo.

## Trabajar en conjunto

**Coordinamos el alcance, no cada línea de código.** Cada contribuyente tiene libertad para resolver una tarea dentro de los acuerdos del proyecto. Cuando dos trabajos puedan afectar las mismas pantallas, servicios, modelos o recursos, procuramos avisarlo y repartir el alcance antes de que se duplique el esfuerzo.

La responsabilidad sobre un módulo o tarea puede asignarse temporalmente, pero no implica propiedad exclusiva del código. Se puede pedir ayuda, intercambiar tareas o revisar el trabajo de otra persona. Lo importante es que las responsabilidades y el estado de cada actividad sean visibles para quienes colaboran.

Los cambios locales y pequeños pueden avanzar sin una consulta previa. En cambio, conviene discutir antes las modificaciones que alteren requisitos, flujos de usuario, dependencias relevantes, contratos de datos, permisos, plataformas compatibles o la arquitectura compartida. El hecho de que una solución ya esté implementada no sustituye esa conversación.

Tratamos de registrar las decisiones que afecten al equipo en una incidencia, un pull request o la documentación pertinente, con una explicación breve de sus motivos. Así no dependemos de recordar conversaciones privadas para entender el proyecto.

## Estructura y responsabilidades del código

La aplicación activa se desarrolla principalmente en `lib/`:

- `screens/`: pantallas, navegación y presentación de la interfaz.
- `widgets/`: componentes visuales reutilizables.
- `models/`: representación de los datos del dominio.
- `services/`: operaciones del dominio y comunicación con Supabase.
- `config/`: configuración y tema visual.
- `test/`: pruebas automatizadas.

La aplicación activa está en la raíz del repositorio. La antigua copia `tianguia/` se retiró; evita volver a incorporar copias completas de la aplicación o paquetes ZIP de entrega.

El backend, incluidas las migraciones y políticas de la base de datos, se mantiene en [Toldo](https://github.com/Tianguia/Toldo). Los cambios que afecten conjuntamente a la app y al backend deben describir las dependencias entre ambos repositorios.

Esta organización es una referencia, no una invitación a crear capas, clases o archivos sin necesidad. Si una responsabilidad deja de estar clara, podemos ajustar la estructura de común acuerdo.

## Código que podamos mantener

Buscamos **código legible, directo y eficiente**, sin complejidad innecesaria.

- Prefiere nombres descriptivos, funciones con una responsabilidad clara y convenciones habituales de Dart y Flutter.
- Mantén la lógica de acceso a datos y las operaciones del dominio fuera de los widgets cuando corresponda. Reutiliza componentes cuando haya un beneficio real, sin abstraer por adelantado cada detalle.
- Evita el código repetido, las dependencias prescindibles, el *boilerplate* sin propósito y los comentarios que solo repiten lo evidente. Documenta, en cambio, las decisiones y restricciones que no sean obvias.
- Considera el rendimiento en dispositivos reales: consultas a la base de datos, reconstrucciones de interfaz, consumo de red, memoria, ubicación y batería. Optimiza problemas concretos sin sacrificar claridad por mejoras hipotéticas.
- Maneja los errores de forma explícita cuando importen. No ocultes fallos ni descartes excepciones indiscriminadamente para aparentar que una función siempre tiene éxito.
- Respeta el diseño existente y procura que las interfaces sean utilizables, accesibles y coherentes. Los cambios visuales relevantes deben poder revisarse con capturas o una descripción del comportamiento.

Se permite usar herramientas de generación de código e inteligencia artificial. Quien presenta una contribución sigue siendo responsable de comprenderla, comprobarla, revisar sus dependencias y retirar el contenido generado que no aporte valor. El código sugerido por una herramienta se evalúa con los mismos criterios que cualquier otro.

## Privacidad y seguridad

TianGuía trabaja con cuentas, ubicaciones, información de vendedores y conversaciones. Tratamos esos datos con cuidado desde el desarrollo:

- No incluyas contraseñas, tokens de sesión, claves privadas, credenciales de firma, claves de servicio privilegiadas ni archivos de configuración personal en commits o pull requests.
- Las claves públicas de cliente de Supabase (`publishable` o `anon`) no son equivalentes a una clave `service_role`, pero tampoco sustituyen permisos correctos en el backend. Nunca confíes en que ocultar algo en la aplicación protege ese dato.
- Utiliza datos ficticios para pruebas, capturas y ejemplos. No publiques correos, teléfonos, mensajes, coordenadas precisas u otros datos personales de usuarios reales sin una razón y autorización adecuadas.
- Revisa los cambios de autenticación, permisos, políticas RLS, acceso a Storage y funciones SQL con especial atención. El acceso debe ser el mínimo necesario para cada operación.
- No registres en logs información sensible ni expongas detalles internos innecesarios en mensajes de error.

Si descubres una vulnerabilidad que pueda afectar a usuarios o credenciales, comunícala de forma privada a los responsables del proyecto en lugar de publicar instrucciones de explotación o datos sensibles en una incidencia pública. Si un secreto se filtra, debe revocarse o rotarse: borrar el archivo del último commit no basta.

## Proponer e integrar cambios

Trabaja preferentemente en una rama dedicada y abre un **pull request** para integrar tu aportación. Un PR pequeño y enfocado suele revisarse mejor que uno que mezcla cambios funcionales, rediseños y reorganizaciones sin relación.

En la descripción del PR, procura indicar:

- **Qué** problema resuelve y **por qué** es necesario.
- **Qué** cambió, especialmente si modifica el comportamiento visible o afecta otros módulos.
- **Cómo** lo verificaste, incluyendo limitaciones conocidas. Adjunta capturas si modificaste la interfaz.
- La incidencia o el requisito relacionado, cuando exista.

Si el trabajo es amplio o puede entrar en conflicto con cambios simultáneos, un PR en borrador sirve para compartir avances y recibir comentarios sin presentar la solución como terminada. No es necesario publicar cada pequeño cambio: lo importante es que el trabajo compartido pueda coordinarse e integrarse sin sorpresas.

Procuramos que los cambios significativos reciban la revisión de otra persona antes de integrarse. Las correcciones triviales pueden llevar un proceso más ligero. Una revisión busca detectar problemas y aprender en conjunto, no imponer preferencias personales: explica el motivo de cada observación y distingue los errores reales de las sugerencias de estilo.

Antes de dar un PR por listo, aplica el formato y ejecuta, cuando corresponda:

```sh
dart format lib test
flutter analyze
flutter test
```

Las verificaciones automatizadas de GitHub Actions ayudan a detectar problemas, pero no sustituyen las pruebas manuales de los flujos modificados. Si alguna comprobación no puede ejecutarse en tu entorno, indícalo en el PR. Incluye o actualiza pruebas cuando cambies un comportamiento que se pueda verificar automáticamente.

## Documentación, atribución y convivencia

Mantén actualizada la documentación que resulte afectada por tu cambio, sin duplicar instrucciones que ya existen en el README u otros documentos. Conserva los avisos de licencia y atribuye adecuadamente el trabajo de terceros, incluidos recursos gráficos y fragmentos de código que puedan tener condiciones de uso.

Agradecemos la crítica técnica fundamentada y la diversidad de experiencia. Nos dirigimos a las personas con respeto, suponemos buena intención y resolvemos los desacuerdos sobre hechos, requisitos y alternativas técnicas. No hace falta estar de acuerdo en todo para colaborar bien.

**La prioridad es construir una aplicación útil y mantenible entre todos.** Estas convenciones pueden evolucionar mediante propuestas y revisiones del propio equipo y de la comunidad.
