# Colaborar en TianGuía

Gracias por querer ayudar. Se vale aportar código, diseño, documentación,
pruebas o ideas. Si conoces los tianguis, tu opinión vale tanto como un commit.

## Antes de empezar

- Lee el [README](README.md) para saber cómo correr la app.
- Revisa las [incidencias](https://github.com/Tianguia/Tianguiapp/issues) y los
  pull requests abiertos, a ver si alguien ya está en lo mismo.
- Para corregir una errata o hacer una mejora chica no hace falta abrir una
  incidencia. Si es una función nueva o un cambio que toca varios módulos,
  cuéntanos primero en una incidencia qué quieres resolver y cómo lo harías.

## Cómo trabajamos

Nos ponemos de acuerdo en qué se va a hacer, no en cada línea. Si dos personas
van a tocar las mismas pantallas o servicios, avísense antes para no repetir
trabajo. Tener asignado un módulo no lo hace tuyo: otra persona puede ayudarte o
revisarlo.

Lo chico y local se puede hacer sin preguntar. Lo que cambia requisitos, flujos
de usuario, permisos, dependencias importantes o la estructura compartida
conviene platicarlo antes, aunque ya lo tengas hecho. Lo que se decida lo
dejamos escrito en una incidencia o en el PR, para no depender de que alguien se
acuerde de una plática.

## El código

La app está en `lib/`:

- `screens/`: pantallas y navegación
- `widgets/`: piezas visuales que se repiten
- `models/`: las clases de los datos
- `services/`: lógica y conexión con Supabase
- `config/`: tema y configuración

Las pruebas están en `test/`, fuera de `lib/`.

El backend, con las migraciones y los permisos de la base, vive en
[Toldo](https://github.com/Tianguia/Toldo). Si tu cambio afecta a los dos
repositorios, explica en el PR qué depende de qué.

Lo que pedimos:

- nombres claros y funciones que hagan una sola cosa
- la lógica de datos fuera de los widgets cuando se pueda
- nada de código repetido ni de abstracciones que nadie pidió
- comentarios solo cuando expliquen algo que no se ve a simple vista, no para
  repetir lo que hace la línea
- no esconder errores con `catch` vacíos si de verdad importan
- si el cambio se ve en la pantalla, que sea accesible y se parezca al resto
- pensar en el celular real: consultas, red, batería y ubicación

Puedes usar herramientas de IA, pero tú respondes por lo que mandas. Entiéndelo,
pruébalo y quita lo que sobre.

Si agregas un requisito nuevo, deja un comentario `rf-NN` en el lugar donde se
cumple, como los que ya hay.

## Privacidad y seguridad

La app maneja cuentas, ubicaciones y chats, así que ten cuidado:

- no subas contraseñas, tokens, claves privadas, claves de firma ni la
  `service_role` de Supabase
- la clave pública (`publishable` o `anon`) puede ir en la app, pero eso no
  reemplaza los permisos del backend. Esconder algo en la app no lo protege
- usa datos inventados en pruebas y capturas. Nada de correos, teléfonos,
  mensajes ni ubicaciones de personas reales
- si tocas autenticación, políticas RLS, Storage o funciones SQL, revísalo con
  más cuidado y da solo el acceso necesario
- no pongas datos sensibles en los logs ni en los mensajes de error

Si encuentras una vulnerabilidad, avísanos en privado, no la publiques en una
incidencia. Y si se filtra una clave hay que cambiarla: borrar el archivo en el
siguiente commit no la borra del historial.

## Pull requests

Trabaja en una rama aparte. Un PR chico y enfocado se revisa mejor que uno que
mezcla funciones, rediseños y reorganizaciones. En la descripción cuenta:

- qué problema resuelve y por qué
- qué cambió, sobre todo si se nota en la app o afecta otros módulos
- cómo lo probaste y qué no pudiste probar
- capturas, si tocaste la interfaz
- la incidencia o el requisito relacionado, si hay

Si el trabajo es grande, abre el PR como borrador para enseñar avances. Los
cambios importantes los revisa otra persona antes de entrar. Al revisar, explica
el porqué de cada comentario y aclara qué es un error y qué es solo una
preferencia.

Antes de dar el PR por listo, corre lo mismo que corre CI:

```powershell
./scripts/verify.ps1
```

En Linux o macOS: `bash scripts/check.sh`. Solo necesita Docker con Compose v2
(en Windows también sirve Docker dentro de WSL). Más información en la
[guía de Docker](docs/desarrollo-docker.md#verificar-un-cambio).

Si ya tienes Flutter instalado, mientras desarrollas puedes correr:

```sh
dart format lib test
flutter analyze
flutter test
```

Que pase CI no reemplaza probar a mano lo que cambiaste. Si algo no lo pudiste
correr, dilo en el PR. Si cambias algo que se puede probar automáticamente,
agrega o actualiza la prueba.

## Documentación y trato

Si tu cambio deja desactualizada alguna documentación, arréglala sin duplicar lo
que ya está en el README. Respeta las licencias y da crédito por imágenes o
código de otras personas.

Se vale criticar una decisión técnica con argumentos, y no hace falta estar de
acuerdo en todo. Tratemos a todos con respeto y asumamos buena intención. Lo
importante es que la app sirva y se pueda mantener.
