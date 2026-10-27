# Correspondencia del contrato con Tianguía y Toldo

Fuentes: `Diagrama_Clases_TianGuia.pdf` y `Diagrama_ER_TianGuia.pdf`, proporcionados
en la raíz. El esquema objetivo es la secuencia de migraciones de Toldo hasta
`20261027000300_client_operations.sql`; `schema-reference.sql` documenta una exportación
de la baseline y no sustituye esa secuencia. Las cuatro migraciones quedaron
registradas en el Supabase compartido; falta validar los recorridos completos
con la aplicación.

## Clases, identidad y operaciones

Las entidades están en `lib/models/`. `Comprador` y `Vendedor` heredan de
`Usuario`: pueden representar simultáneamente la misma cuenta. `idComprador`
coincide con `idUsuario`, pero `idVendedor` identifica el perfil vendedor y no
debe usarse como identificador de Auth. `AuthService.miComprador()` y los métodos
`miPerfil()` devuelven entidades tipadas.

Los identificadores del PDF se expresan en camelCase (`id_usuario` →
`idUsuario`). Los modelos anteriores conservan `id` y exponen además
`idProducto`, `idPuesto`, `idApartado`, `idOferta` e `idTianguis`. Los atributos
heredados del usuario proceden de la relación `usuarios` del subtipo.

Los métodos que crean entidades son fábricas estáticas: no requieren un objeto
con identificador ficticio antes del INSERT. Los métodos de modificación devuelven
el estado recuperado de la base. Todos reciben un puerto de `operaciones.dart`;
los servicios implementan esos puertos y admiten un `SupabaseClient` inyectado.
No hay operaciones de persistencia en memoria ni clientes globales en las
entidades. El resolvedor de URLs de imágenes es puro y no requiere sesión.

| Clase del PDF | Atributos y relaciones físicos | Métodos y adaptador | Pruebas |
| --- | --- | --- | --- |
| Usuario | `usuarios`: `id` → idUsuario, `nombre_publico` → nombre, correo, teléfono, `foto_url` → fotoPerfil, `creado_en` → fechaRegistro, estadoCuenta | registrar, iniciarSesion, actualizarPerfil → AuthService; entrada anónima y confirmación OTP | `contrato_test`: especialización; `contrato_service_test`: registro/acceso/actualización; `auth_service_test`: campos editables y rechazo |
| Comprador | `compradores.id_comprador`, usuario heredado por `id_usuario` | buscarProductos, filtrarProductos → CatalogoService; proponerPrecio → ChatService | especialización; búsqueda y filtros; propuestas y apartados |
| Vendedor | `perfiles_vendedor`: idVendedor, descripción, fechaHabilitacion, estado; usuario heredado | habilitarPerfil, registrarHorario, registrarAusencia → VendedorService | especialización; habilitación/horarios/ausencias |
| Visita | `visitas`: idVisita, `id_usuario` → idComprador, idPuesto, fechaHora, metodoVerificacion, estado | verificarVisita → PuestosService → confirmar_visita y lectura de la visita | visitas/calificaciones; Toldo `04_er.sql` |
| Calificacion | `calificaciones`: idCalificacion, idComprador desde id_usuario, idVendedor, idPuesto, puntuación, comentario, fechaCreacion; etiquetas normalizadas; idVisita adicional | registrarCalificacion → PuestosService; el trigger valida y deriva puesto/vendedor desde visita | visitas/calificaciones y etiquetas; Toldo `04_er.sql`: visita verificada y unicidad |
| Apartado | `apartados`: idApartado, idProducto, idComprador, idVendedor, fechaInicio, fechaExpiracion, estado; cantidad adicional | solicitarApartado → ChatService; aceptarApartado/rechazarApartado → TratosService → responder_apartado | fechas y nombre anidado; respuestas por RPC; Toldo `03_remote_sync.sql` |
| Puesto | `puestos`: idPuesto, idTianguis, idVendedor, código, ubicación desde coordenadas, estado, fechaApertura, fechaCierre | marcarAbierto/marcarCerrado → VendedorService → abrir_puesto/cerrar_puesto | ubicación/cierre; delegación de apertura/cierre; retiro SQL |
| Producto | `productos`: idProducto, idVendedor, idPuesto obligatorio, nombre, descripción, categoría por relación, estadoArticulo, precioReferencia, disponibilidad entera desde cantidad_disponible; imágenes normalizadas | crearProducto, actualizarStock → VendedorService | imágenes sin sesión; puesto obligatorio/inactivo, stock, filtros; widgets de producto; SQL ER y retiro |
| Oferta | `ofertas`: idOferta, idProducto, precioPromocional, descuento, fechaInicio, fechaFin, estado | publicarOferta/finalizarOferta → VendedorService | vigencia, inserción múltiple atómica, finalización; listado de tarjetas; SQL ER |
| Conversacion | `conversaciones`: idConversacion, fechaCreacion, estado; miembros en participantes | iniciarConversacion → ChatService → iniciar_conversacion y lectura por membresía | contexto opcional, membresía, ocultación; widget de chats; Toldo `04_er.sql` y `06_client_contract.sql` |
| Mensaje | `mensajes`: idMensaje, idConversacion, idRemitente, contenido, fechaEnvio, estado generado | enviarMensaje → ChatService | lectura de estado, envío tipado y rechazo de vacío; SQL participación/bloqueos |
| Reporte | `reportes`: idReporte, `id_reportante` → idUsuario, `tipo_objetivo` → tipo, `id_objetivo` → idReferencia, motivo, fechaCreacion, estado | crearReporte → ConfianzaService | mapeo y envío sin campos administrativos |
| Apelacion | `apelaciones`: idApelacion, idReporte opcional, idUsuario, motivo, fechaCreacion, estado, resolución | solicitarRevision → ConfianzaService | reporte nulo, resolución nula y envío sin campos administrativos; SQL ER |
| Tianguis | `tianguis`: idTianguis, nombre, ubicación desde dirección/coordenadas, descripción, estado desde activo; diasOperacion/horarioGeneral derivados de tianguis_horarios | consultarMapa → CatalogoService; devuelve MapaTianguis con ubicación y zonas geométricas | horarios y zonas; búsqueda por tianguis |

`contrato_test` está en `test/models/`, `contrato_service_test` en `test/services/`
y las pruebas de interfaz en `test/screens/contrato_screen_test.dart`.
`Propuesta`, `Participante`, horarios, imágenes, zonas y resúmenes son extensiones
operativas; no sustituyen las clases del contrato.

## Equivalencias y excepciones acordadas

- Se conservan las relaciones de Toldo y del ER: varios participantes por
  conversación y varios tianguis por vendedor. Difieren de las cardinalidades
  dibujadas en el diagrama de clases. Las membresías, no iniciador/receptor,
  determinan acceso, listado y operaciones de chat.
- UUID implementa los identificadores String. `num` conserva precios SQL numeric
  sin limitar el dominio a los valores JSON que llegan como double. El stock es
  un entero nullable para registros sin control de cantidad; no se interpreta como
  el booleano adicional `disponible` ni se convierte silenciosamente en cero.
- Contacto, descripción, imágenes, fechas de apertura/cierre y otros atributos
  opcionales conservan la nulabilidad de Toldo. Las cuentas anónimas no reciben
  un correo ficticio. La apelación permite reporte y resolución nulos.
- Las fechas se envían en UTC. Los métodos existentes de presentación convierten
  a hora local; el modelo conserva el instante recibido.
- Las operaciones que requieren identidad actúan con la sesión autenticada del
  adaptador. La base conserva la autoridad sobre propiedad, membresía, roles,
  stock, verificación de visitas y transiciones de estado.
- Se implementan las operaciones del contrato y se adaptan las pantallas
  existentes. No se agregan pantallas de apelaciones, gestión de participantes,
  mapa o administración.

## Integración y despliegue coordinado

Las ofertas se insertan en un solo lote sobre `ofertas`: una fila por producto.
La interfaz permite seleccionar varios productos, pero lista y finaliza cada
oferta individualmente. La lectura vigente exige estado activo, inicio alcanzado
y fin futuro, ordenando por fin ascendente. La app no depende de la vista de
compatibilidad `oferta_productos`.

Los productos requieren un puesto activo del mismo vendedor. El formulario
bloquea el guardado sin selección y explica qué hacer si no hay puestos.
Las consultas que admiten varias FK especifican `productos_id_puesto_fkey` y
`ofertas_id_producto_fkey`. Los tratos cargan el nombre mediante
`compradores → usuarios`.

`retirar_puesto` comprueba propiedad, bloquea el puesto y realiza una transacción:
cierra la jornada, retira productos, finaliza ofertas y da de baja el puesto.
No elimina filas ni altera cantidades o estados de tratos históricos. Repetir
la operación no vuelve a cerrar la jornada. Los triggers impiden publicaciones,
reasignaciones y reactivaciones incompatibles con un puesto retirado.

Antes de distribuir esta app debe aplicarse coordinadamente el ER y la migración
de retiro, siguiendo `Toldo/docs/despliegue-supabase.md`. La app anterior y la nueva
no son intercambiables durante esa transición. Diagnóstico comprueba compradores,
participantes y columnas de ofertas; no demuestra por sí solo que Auth, Storage
y Realtime estén configurados correctamente.

## Verificación reproducible

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
cd Toldo
bash scripts/test-db.sh
```

Flutter utiliza transporte HTTP simulado, sin contactar el proyecto compartido.
Las pruebas de widgets ejercitan las pantallas con esos mismos adaptadores.
Toldo aplica las migraciones en un PostgreSQL temporal de Docker, prueba la
transformación histórica y revierte los fixtures. `05_retire_stall.sql` cubre
propiedad, permisos, retiro, repetición, historial, prohibiciones de reactivación
y rollback ante un fallo deliberado al finalizar ofertas.

`06_client_contract.sql` verifica la creación por `iniciar_conversacion`, la
disponibilidad de participantes al recuperar el chat y la pérdida de acceso al
salir. La RPC evita el conflicto de `INSERT … RETURNING` con la política de
lectura, que se evalúa antes del trigger AFTER INSERT de participantes. No se
amplía el acceso por el mero hecho de ser iniciador.

La revisión manual pendiente en un entorno con Auth/Storage/Realtime debe cubrir:
entrada anónima y OTP conservando identidad, imágenes, apertura con GPS, chat en
tiempo real de tres participantes, propuesta/apartado entre dos cuentas,
visita/calificación y retiro visible desde la cuenta compradora. Las pruebas
simuladas y SQL no equivalen a haber completado ese recorrido en un dispositivo.
