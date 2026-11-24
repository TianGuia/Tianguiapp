# inicio_sesion/ · Cuentas y acceso

**Módulo del diagrama:** Inicio de sesión · **Requisitos:** RF-01 a RF-05

## Usuario (`usuario.dart`)

`Usuario` es la **cuenta** de una persona. Es importante distinguir dos cosas:

- La **persona** es quien abre la app.
- El **Usuario** es el registro que se crea cuando esa persona se registra.

Hasta que alguien se registra, no existe como Usuario. Después de registrarse,
su cuenta tiene nombre, correo, teléfono, foto y estado.

De `Usuario` salen los dos roles:

```
Usuario ──► Comprador   (busca y compra)
        └─► Vendedor    (opera un puesto)
```

Una misma cuenta puede tener los dos roles. Por eso, en el diagrama, la
especialización se llama **solapada**.

**Quién hace el trabajo real:** `services/auth_service.dart`. La clase Usuario
solo lo llama.
