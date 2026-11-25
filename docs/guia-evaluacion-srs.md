# Guía de evaluación del SRS

Sigue el orden del SRS actualizado. En cada fila, abre el código Flutter y muestra la llamada a Supabase. Cuando la lógica se ejecuta en el servidor, sigue el enlace a la migración de Toldo. La guía señala evidencia de implementación y pendientes de prueba en dispositivo.

Las referencias de Flutter siguen la numeración vigente. En las migraciones ya aplicadas de Toldo, los comentarios conservan los números del SRS original. Para estas referencias usa la equivalencia anterior → vigente. RF-02 → RF-07, RF-03 → RF-08, RF-13 → RF-18, RF-21 → RF-26, RF-25 → RF-30, RF-27 → RF-32 y RF-31 → RF-36.

## Cuenta y sesión

| RF | Función | Código Flutter | Consulta o lógica en Supabase |
| --- | --- | --- | --- |
| RF-01 | Registro | [auth_service:96](../lib/services/auth_service.dart#L96) | Auth crea la cuenta; [`handle_new_user`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L486) |
| RF-02 | Verificar contacto | [auth_service:115](../lib/services/auth_service.dart#L115) | Auth updateUser y verifyOTP |
| RF-03 | Iniciar sesión por código | [auth_service:127](../lib/services/auth_service.dart#L127) | Auth signInWithOtp y verifyOTP; admite alta |
| RF-04 | Cerrar sesión | [auth_service:231](../lib/services/auth_service.dart#L231) | Revoca en Auth; [quitar_token_push](../lib/services/push_service.dart#L103) |
| RF-05 | Perfil | [auth_service:242](../lib/services/auth_service.dart#L242), [auth_service:160](../lib/services/auth_service.dart#L160) | SELECT y UPDATE usuarios; carga en Storage |

## Comprador

| RF | Función | Código Flutter | Consulta o lógica en Supabase |
| --- | --- | --- | --- |
| RF-06 | Buscar productos | [catalogo_service:44](../lib/services/catalogo_service.dart#L44) | Búsqueda de texto sobre busqueda y filtro de categoría |
| RF-07 | Filtrar resultados | [catalogo_service:38](../lib/services/catalogo_service.dart#L38) | RPC por tianguis y día; precio y categoría en Flutter; [`productos_catalogo`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000500_catalogo_y_apartados.sql#L2) |
| RF-08 | Ficha de producto | [producto_detalle_screen:36](../lib/screens/producto_detalle_screen.dart#L36) | SELECT productos, imágenes y puesto; [`nombre_vendedor_producto`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000500_catalogo_y_apartados.sql#L31) |
| RF-09 | Mapa de puestos abiertos | [puestos_service:10](../lib/services/puestos_service.dart#L10), [mapa_puestos_screen:95](../lib/screens/mapa_puestos_screen.dart#L95) | SELECT puestos activos y abiertos; marcadores con coordenadas |
| RF-10 | Estado y ubicación de la jornada | [ubicacion_producto:68](../lib/widgets/ubicacion_producto.dart#L68), [inicio_service:97](../lib/services/inicio_service.dart#L97) | SELECT puestos por ID; aviso cuando faltan coordenadas |
| RF-11 | Favoritos | [favoritos_screen:36](../lib/screens/favoritos_screen.dart#L36), [catalogo_service:65](../lib/services/catalogo_service.dart#L65), [inicio_service:79](../lib/services/inicio_service.dart#L79), [inicio_service:49](../lib/services/inicio_service.dart#L49) | SELECT, INSERT y DELETE favoritos |
| RF-12 | Avisos de ofertas | [notificaciones_screen:16](../lib/screens/notificaciones_screen.dart#L16) | [`trg_notificar_oferta`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000200_align_domain_contract.sql#L332); considera favoritos e intereses |
| RF-13 | Avisos de ausencia | [vendedor_service:55](../lib/services/vendedor_service.dart#L55) | INSERT ausencias_programadas; [`notificar_ausencia`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261127000100_ausencias_respetan_silencios.sql#L5) |
| RF-14 | Recordatorios de tianguis | [preferencias_notificacion_screen:24](../lib/screens/preferencias_notificacion_screen.dart#L24) | [`generar_recordatorios_tianguis`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261127000000_recordatorios_tianguis.sql#L13); cron y deduplicación; entrega física pendiente |
| RF-15 | Preferencias y silencios | [preferencias_notificacion_screen:82](../lib/screens/preferencias_notificacion_screen.dart#L82), [preferencias_notificacion_screen:130](../lib/screens/preferencias_notificacion_screen.dart#L130) | preferencias_notificacion, intereses_categoria, silencios_notificacion |
| RF-16 | Chat desde producto | [producto_detalle_screen:106](../lib/screens/producto_detalle_screen.dart#L106), [chat_service:14](../lib/services/chat_service.dart#L14) | Conversaciones y alta de participantes; [`conversaciones_participantes`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000200_align_domain_contract.sql#L129) |
| RF-17 | Proponer precio | [chat_service:222](../lib/services/chat_service.dart#L222) | INSERT propuestas_precio |
| RF-18 | Solicitar apartado | [chat_service:232](../lib/services/chat_service.dart#L232) | INSERT apartados; [`validar_solicitud_apartado`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L119) |

## Vendedor

| RF | Función | Código Flutter | Consulta o lógica en Supabase |
| --- | --- | --- | --- |
| RF-19 | Activar perfil de vendedor | [vendedor_tab:69](../lib/screens/vendedor_tab.dart#L69), [vendedor_service:33](../lib/services/vendedor_service.dart#L33) | INSERT perfiles_vendedor; [`perfiles_vendedor_verificado`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L2110) |
| RF-20 | Tianguis habituales | [vendedor_service:43](../lib/services/vendedor_service.dart#L43), [horarios_screen:57](../lib/screens/horarios_screen.dart#L57) | INSERT vendedor_tianguis |
| RF-21 | Horario habitual | [vendedor_service:47](../lib/services/vendedor_service.dart#L47) | INSERT vendedor_horarios |
| RF-22 | Ausencias programadas | [horarios_screen:113](../lib/screens/horarios_screen.dart#L113), [vendedor_service:55](../lib/services/vendedor_service.dart#L55) | INSERT ausencias_programadas |
| RF-23 | Registrar productos | [vendedor_service:195](../lib/services/vendedor_service.dart#L195), [vendedor_service:227](../lib/services/vendedor_service.dart#L227) | INSERT productos y producto_imagenes; carga en Storage |
| RF-24 | Editar productos | [mis_productos_screen:287](../lib/screens/mis_productos_screen.dart#L287), [vendedor_service:220](../lib/services/vendedor_service.dart#L220) | UPDATE productos y gestión de imágenes |
| RF-25 | Retirar productos | [vendedor_service:225](../lib/services/vendedor_service.dart#L225) | UPDATE activo en productos |
| RF-26 | Disponibilidad e inventario | [vendedor_service:217](../lib/services/vendedor_service.dart#L217), [mis_productos_screen:319](../lib/screens/mis_productos_screen.dart#L319) | [`sincronizar_disponibilidad_producto`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L48) |
| RF-27 | Abrir y cerrar puesto | [vendedor_tab:96](../lib/screens/vendedor_tab.dart#L96), [vendedor_service:171](../lib/services/vendedor_service.dart#L171) | [`abrir_puesto`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L132); [`cerrar_puesto`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L304) |
| RF-28 | Registrar ubicación | [vendedor_service:145](../lib/services/vendedor_service.dart#L145), [vendedor_tab:113](../lib/screens/vendedor_tab.dart#L113) | [`insert into jornadas_puesto`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L146); admite apertura sin coordenadas |
| RF-29 | Publicar ofertas | [vendedor_service:249](../lib/services/vendedor_service.dart#L249) | INSERT ofertas; id_oferta_origen agrupa productos |
| RF-30 | Finalizar ofertas | [vendedor_service:281](../lib/services/vendedor_service.dart#L281), [catalogo_service:106](../lib/services/catalogo_service.dart#L106) | UPDATE ofertas y filtro temporal; [`vencer_pendientes`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L217) |
| RF-31 | Responder propuestas | [tratos_service:50](../lib/services/tratos_service.dart#L50) | [`responder_propuesta`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L971); aceptar, rechazar o contraofertar |
| RF-32 | Gestionar apartados | [tratos_service:59](../lib/services/tratos_service.dart#L59) | [`responder_apartado`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L158); [`vencer_pendientes`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L217) |
| RF-33 | Publicar espacios | [espacios_screen:88](../lib/screens/espacios_screen.dart#L88) | INSERT anuncios_espacio |
| RF-34 | Consultar espacios | [espacios_screen:240](../lib/screens/espacios_screen.dart#L240), [espacios_screen:42](../lib/screens/espacios_screen.dart#L42) | SELECT anuncios abiertos; filtros locales; [`alter policy anuncios_select`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000800_reportes_y_tianguis_activos.sql#L97) |
| RF-35 | Chat desde anuncio | [espacios_screen:60](../lib/screens/espacios_screen.dart#L60), [chat_service:14](../lib/services/chat_service.dart#L14) | Conversaciones asociadas a id_anuncio_espacio |
| RF-36 | Editar o cerrar anuncios | [espacios_screen:88](../lib/screens/espacios_screen.dart#L88), [espacios_screen:181](../lib/screens/espacios_screen.dart#L181) | UPDATE anuncios_espacio; [`verificar_tianguis_anuncio`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000800_reportes_y_tianguis_activos.sql#L103) |

## Funciones comunes y de confianza

| RF | Función | Código Flutter | Consulta o lógica en Supabase |
| --- | --- | --- | --- |
| RF-37 | Mensajes | [chat_service:175](../lib/services/chat_service.dart#L175), [chat_service:160](../lib/services/chat_service.dart#L160) | INSERT y Realtime mensajes; [`mis_conversaciones`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000200_privacidad_chat.sql#L3) |
| RF-38 | Bloquear usuarios | [chat_service:207](../lib/services/chat_service.dart#L207), [chat_service:200](../lib/services/chat_service.dart#L200) | bloqueos; [`public.hay_bloqueo`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000200_align_domain_contract.sql#L167) |
| RF-39 | Modalidad de venta | [producto_detalle_screen:257](../lib/screens/producto_detalle_screen.dart#L257) | Aviso en interfaz |
| RF-40 | Aceptar condiciones | [auth_service:144](../lib/services/auth_service.dart#L144), [terminos_screen:37](../lib/screens/terminos_screen.dart#L37) | [`aceptar_terminos_vigentes`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000400_aceptacion_documentos.sql#L34) |
| RF-41 | Verificar visita | [vendedor_service:175](../lib/services/vendedor_service.dart#L175), [puestos_service:26](../lib/services/puestos_service.dart#L26) | [`generar_codigo_visita`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L461); [`confirmar_visita`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L323) |
| RF-42 | Valorar visita | [visita_flow:53](../lib/widgets/visita_flow.dart#L53), [puestos_service:46](../lib/services/puestos_service.dart#L46) | INSERT calificaciones y calificacion_etiquetas |
| RF-43 | Consultar valoraciones | [valoraciones_screen:22](../lib/screens/valoraciones_screen.dart#L22) | SELECT calificaciones y etiquetas del vendedor |
| RF-44 | Reportar contenido | [chat_service:244](../lib/services/chat_service.dart#L244), [moderacion:15](../lib/widgets/moderacion.dart#L15) | INSERT reportes; [`verificar_objetivo_reporte`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000800_reportes_y_tianguis_activos.sql#L22) |
| RF-45 | Avisar medidas | [medidas_screen:37](../lib/screens/medidas_screen.dart#L37) | [`notificar_medida`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000000_baseline_supabase.sql#L598); notificaciones |
| RF-46 | Solicitar revisión | [medidas_screen:134](../lib/screens/medidas_screen.dart#L134), [apelacion:26](../lib/models/comunes/apelacion.dart#L26) | INSERT apelaciones con id_medida. La revisión directa de reportes del caso de uso carece de entrada equivalente. |

## Administración

| RF | Función | Código Flutter | Consulta o lógica en Supabase |
| --- | --- | --- | --- |
| RF-47 | Gestionar tianguis | [admin_service:138](../lib/services/admin_service.dart#L138) | INSERT y UPDATE tianguis, incluido activo |
| RF-48 | Gestionar horarios generales | [admin_service:154](../lib/services/admin_service.dart#L154) | INSERT y UPDATE tianguis_horarios |
| RF-49 | Gestionar zonas y pasillos | [admin_service:176](../lib/services/admin_service.dart#L176), [zonas_mapa:53](../lib/widgets/zonas_mapa.dart#L53) | INSERT y UPDATE tianguis_zonas; capas GeoJSON |
| RF-50 | Revisar reportes | [admin_service:100](../lib/services/admin_service.dart#L100), [admin_service:20](../lib/services/admin_service.dart#L20) | [`admin_resolver_reporte`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000800_reportes_y_tianguis_activos.sql#L44) |
| RF-51 | Resolver revisión | [admin_service:121](../lib/services/admin_service.dart#L121) | [`admin_resolver_apelacion`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000300_moderacion_y_apelaciones.sql#L42) |
| RF-52 | Publicar documentos | [admin_service:199](../lib/services/admin_service.dart#L199) | [`admin_publicar_documento`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000400_aceptacion_documentos.sql#L66) |
| RF-53 | Exigir reaceptación | [app:109](../lib/app.dart#L109), [auth_service:167](../lib/services/auth_service.dart#L167) | [`terminos_pendientes`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000400_aceptacion_documentos.sql#L3) |
| RF-54 | Consultar datos administrativos | [admin_service:216](../lib/services/admin_service.dart#L216) | SELECT por entidad y RPC de búsqueda de contenido moderable |

## Requisitos no funcionales

| RNF | Evidencia para mostrar |
| --- | --- |
| RNF-1 | Tutorial y controles de apertura. Revisar legibilidad con texto ampliado en móvil. [vendedor_tab:113](../lib/screens/vendedor_tab.dart#L113) |
| RNF-2 | Geolocalización puntual al abrir y opción de abrir sin compartirla. [vendedor_service:145](../lib/services/vendedor_service.dart#L145) |
| RNF-3 | RLS, membresía de chat y permisos de vendedor. [`CREATE POLICY msg_select`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261027000200_align_domain_contract.sql#L148); [`puede_operar_vendedor`](https://github.com/TianGuia/Toldo/blob/98be02567a8f17349f543c8ff0c7549c5ec7a63d/supabase/migrations/20261128000700_permisos_y_disponibilidad.sql#L2) |
| RNF-4 | Cambios por Realtime y consulta de respaldo. [datos_en_vivo:16](../lib/services/datos_en_vivo.dart#L16) |
| RNF-5 | Se conserva la última respuesta válida y se avisa cuando falla la sincronización. [datos_en_vivo:69](../lib/services/datos_en_vivo.dart#L69), [aviso_sincronizacion:3](../lib/widgets/aviso_sincronizacion.dart#L3) |

## Para cerrar la exposición

Muestra el SELECT con filtros de día y tianguis en RF-07, el INSERT a apartados en RF-18, la actualización de inventario dentro de responder_apartado en RF-32 y el trigger de notificaciones en RF-12. Usa cuentas de prueba y evita mostrar correos, códigos de acceso o credenciales. La entrega push, los ajustes nativos y la recepción del OTP siguen pendientes de comprobación en móvil.
