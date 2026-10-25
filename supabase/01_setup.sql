-- =====================================================================
-- TianGuía · 01_setup.sql
-- Ejecutar UNA vez en Supabase > SQL Editor (es repetible: usa "or replace",
-- "if not exists" y "drop ... if exists").
--
-- Los ENUM (estado_puesto, estado_cuenta, etc.) ya existen en tu base.
-- Este script asume estos valores (revísalos con la consulta del README):
--   estado_puesto   : 'abierto' | 'cerrado'
--   estado_vendedor : 'activo'
--   estado_oferta   : 'activa' | 'finalizada'
--   contexto        : 'producto'
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Utilidades de seguridad
-- ---------------------------------------------------------------------
create or replace function public.es_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.administradores where id_usuario = auth.uid());
$$;

-- ¿el perfil de vendedor p_id pertenece al usuario logueado?
create or replace function public.es_mi_vendedor(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles_vendedor where id = p_id and id_usuario = auth.uid());
$$;

-- ¿hay un bloqueo activo entre a y b (en cualquier sentido)?
create or replace function public.hay_bloqueo(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.bloqueos
    where activo and ((id_bloqueador = a and id_bloqueado = b) or (id_bloqueador = b and id_bloqueado = a))
  );
$$;

-- ¿el usuario logueado participa en la conversación?
create or replace function public.soy_de_conversacion(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversaciones
    where id = p_id and (id_iniciador = auth.uid() or id_receptor = auth.uid())
  );
$$;

-- ---------------------------------------------------------------------
-- 1. Alta de usuario (RF-01, RF-03): auth.users -> public.usuarios
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.usuarios (id, nombre_publico, correo)
  values (
    new.id,
    left(coalesce(nullif(trim(new.raw_user_meta_data->>'nombre_publico'), ''),
                  nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
                  'Usuario'), 80),
    new.email
  )
  on conflict (id) do nothing;

  insert into public.preferencias_notificacion (id_usuario)
  values (new.id)
  on conflict (id_usuario) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Un usuario NO puede cambiarse su propio estado_cuenta.
create or replace function public.proteger_estado_cuenta()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.estado_cuenta is distinct from old.estado_cuenta and not public.es_admin() then
    new.estado_cuenta := old.estado_cuenta;
  end if;
  return new;
end $$;

drop trigger if exists usuarios_proteger_estado on public.usuarios;
create trigger usuarios_proteger_estado
  before update on public.usuarios
  for each row execute function public.proteger_estado_cuenta();

-- ---------------------------------------------------------------------
-- 2. Términos y condiciones (RF-40, RF-53)
-- ---------------------------------------------------------------------
create or replace function public.terminos_pendientes()
returns setof public.versiones_documento
language sql stable security definer set search_path = public as $$
  select v.*
  from public.versiones_documento v
  where v.vigente
    and not exists (select 1 from public.aceptaciones_terminos a
                    where a.id_usuario = auth.uid() and a.id_version = v.id)
    and (v.requiere_reaceptacion
         or not exists (select 1 from public.aceptaciones_terminos a
                        join public.versiones_documento v2 on v2.id = a.id_version
                        where a.id_usuario = auth.uid() and v2.tipo = v.tipo));
$$;

-- ---------------------------------------------------------------------
-- 3. Puestos abiertos / cerrados y código de visita (RF-27, RF-28, RF-41)
-- ---------------------------------------------------------------------
create or replace function public.abrir_puesto(
  p_id_puesto uuid,
  p_latitud double precision,
  p_longitud double precision,
  p_precision double precision default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_jornada uuid;
begin
  if not exists (
    select 1 from public.puestos p
    join public.perfiles_vendedor v on v.id = p.id_vendedor
    where p.id = p_id_puesto and v.id_usuario = auth.uid() and p.activo
  ) then
    raise exception 'Este puesto no es tuyo o está inactivo';
  end if;

  -- cierra jornadas que hubieran quedado abiertas
  update public.jornadas_puesto set fecha_cierre = now()
   where id_puesto = p_id_puesto and fecha_cierre is null;

  insert into public.jornadas_puesto (id_puesto, latitud, longitud, precision_m)
  values (p_id_puesto, p_latitud, p_longitud, p_precision)
  returning id into v_jornada;

  update public.puestos
     set estado = 'abierto', latitud = p_latitud, longitud = p_longitud,
         fecha_apertura = now(), fecha_cierre = null
   where id = p_id_puesto;

  return v_jornada;
end $$;

create or replace function public.cerrar_puesto(p_id_puesto uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.puestos p
    join public.perfiles_vendedor v on v.id = p.id_vendedor
    where p.id = p_id_puesto and v.id_usuario = auth.uid()
  ) then
    raise exception 'Este puesto no es tuyo';
  end if;

  update public.jornadas_puesto set fecha_cierre = now()
   where id_puesto = p_id_puesto and fecha_cierre is null;
  update public.puestos set estado = 'cerrado', fecha_cierre = now()
   where id = p_id_puesto;
end $$;

-- Código de 6 dígitos que el vendedor muestra para que el comprador confirme su visita.
create or replace function public.generar_codigo_visita(p_id_puesto uuid, p_minutos int default 10)
returns text
language plpgsql security definer set search_path = public as $$
declare v_jornada uuid; v_codigo text; v_intentos int := 0;
begin
  if not exists (
    select 1 from public.puestos p
    join public.perfiles_vendedor v on v.id = p.id_vendedor
    where p.id = p_id_puesto and v.id_usuario = auth.uid()
  ) then
    raise exception 'Este puesto no es tuyo';
  end if;

  select id into v_jornada from public.jornadas_puesto
   where id_puesto = p_id_puesto and fecha_cierre is null
   order by fecha_apertura desc limit 1;
  if v_jornada is null then
    raise exception 'Abre tu puesto antes de generar un código';
  end if;

  loop
    v_codigo := (100000 + floor(random() * 900000))::int::text;
    exit when not exists (select 1 from public.codigos_visita
                          where codigo = v_codigo and expira_en > now());
    v_intentos := v_intentos + 1;
    if v_intentos > 20 then raise exception 'No se pudo generar un código, intenta de nuevo'; end if;
  end loop;

  insert into public.codigos_visita (id_jornada, codigo, expira_en)
  values (v_jornada, v_codigo, now() + make_interval(mins => greatest(p_minutos, 1)));
  return v_codigo;
end $$;

-- El comprador captura el código -> se crea la visita verificada. Devuelve visitas.id
create or replace function public.confirmar_visita(p_codigo text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_jornada uuid; v_puesto uuid; v_visita uuid;
begin
  select c.id_jornada, j.id_puesto into v_jornada, v_puesto
    from public.codigos_visita c
    join public.jornadas_puesto j on j.id = c.id_jornada
   where c.codigo = trim(p_codigo) and c.expira_en > now()
   order by c.creado_en desc limit 1;

  if v_jornada is null then
    raise exception 'Código incorrecto o vencido';
  end if;

  if exists (select 1 from public.puestos p
             join public.perfiles_vendedor v on v.id = p.id_vendedor
             where p.id = v_puesto and v.id_usuario = auth.uid()) then
    raise exception 'No puedes confirmar la visita a tu propio puesto';
  end if;

  select id into v_visita from public.visitas
   where id_usuario = auth.uid() and id_jornada = v_jornada;
  if v_visita is not null then return v_visita; end if;

  insert into public.visitas (id_usuario, id_puesto, id_jornada, metodo_verificacion)
  values (auth.uid(), v_puesto, v_jornada, 'codigo')
  returning id into v_visita;
  return v_visita;
end $$;

-- ---------------------------------------------------------------------
-- 4. Calificaciones (RF-42): completa puesto/vendedor desde la visita
-- ---------------------------------------------------------------------
create or replace function public.calificacion_desde_visita()
returns trigger language plpgsql security definer set search_path = public as $$
declare v record;
begin
  select vi.id_usuario, vi.id_puesto, p.id_vendedor
    into v
    from public.visitas vi join public.puestos p on p.id = vi.id_puesto
   where vi.id = new.id_visita;
  if not found then raise exception 'Visita no encontrada'; end if;
  if v.id_usuario <> auth.uid() then
    raise exception 'Solo puedes calificar tus propias visitas';
  end if;
  new.id_usuario  := v.id_usuario;
  new.id_puesto   := v.id_puesto;
  new.id_vendedor := v.id_vendedor;
  return new;
end $$;

drop trigger if exists calificaciones_desde_visita on public.calificaciones;
create trigger calificaciones_desde_visita
  before insert on public.calificaciones
  for each row execute function public.calificacion_desde_visita();

-- ---------------------------------------------------------------------
-- 5. Chat: actualiza ultimo_mensaje_en y habilita Realtime (RF-16, RF-37)
-- ---------------------------------------------------------------------
create or replace function public.mensaje_nuevo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.conversaciones set ultimo_mensaje_en = new.enviado_en
   where id = new.id_conversacion;
  return new;
end $$;

drop trigger if exists mensajes_ultimo on public.mensajes;
create trigger mensajes_ultimo
  after insert on public.mensajes
  for each row execute function public.mensaje_nuevo();

do $$ begin
  alter publication supabase_realtime add table public.mensajes;
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 6. Inicio de la app: resumen, destacado de la semana y tendencias
-- ---------------------------------------------------------------------
-- Datos públicos de cada puesto activo (la vista corre con permisos del dueño,
-- por eso NO se da acceso directo: solo se consulta mediante las funciones de abajo).
create or replace view public.v_puestos_resumen as
select
  p.id,
  p.nombre,
  p.id_tianguis,
  t.nombre as tianguis_nombre,
  (select min(h.dia_semana) from public.tianguis_horarios h
    where h.id_tianguis = p.id_tianguis) as dia_semana,   -- 0 = domingo ... 6 = sábado
  cat.id as id_categoria,
  cat.nombre as categoria_nombre,
  coalesce(nullif(pv.descripcion, ''), pv.nombre_negocio) as descripcion,
  (select round(avg(k.puntuacion)::numeric, 1) from public.calificaciones k
    where k.id_puesto = p.id and not k.moderado) as promedio,
  (select count(*) from public.calificaciones k
    where k.id_puesto = p.id and not k.moderado) as calificaciones,
  (select count(*) from public.favoritos f where f.id_puesto = p.id) as guardados,
  (p.estado = 'abierto') as abierto,
  (select i.ruta_storage
     from public.productos pr
     join public.producto_imagenes i on i.id_producto = pr.id
    where pr.id_puesto = p.id and pr.activo and not pr.moderado
    order by i.orden, pr.creado_en
    limit 1) as ruta_imagen,
  p.fecha_apertura,
  p.creado_en
from public.puestos p
join public.tianguis t on t.id = p.id_tianguis
join public.perfiles_vendedor pv on pv.id = p.id_vendedor
left join lateral (
  select c.id, c.nombre
    from public.productos pr
    join public.categorias c on c.id = pr.id_categoria
   where pr.id_puesto = p.id and pr.activo
   group by c.id, c.nombre
   order by count(*) desc
   limit 1
) cat on true
where p.activo and pv.estado = 'activo' and t.activo;

revoke all on public.v_puestos_resumen from anon, authenticated;

create or replace function public.resumen_inicio()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'abiertos',  (select count(*) from public.puestos where activo and estado = 'abierto'),
    'en_espera', (select count(*) from public.puestos where activo and estado <> 'abierto')
  );
$$;

create or replace function public.puesto_destacado(p_categoria uuid default null)
returns setof public.v_puestos_resumen
language sql stable security definer set search_path = public as $$
  select * from public.v_puestos_resumen
   where p_categoria is null or id_categoria = p_categoria
   order by coalesce(promedio, 0) desc, calificaciones desc, guardados desc, creado_en desc
   limit 1;
$$;

create or replace function public.puestos_tendencia(p_categoria uuid default null, p_limite int default 12)
returns setof public.v_puestos_resumen
language sql stable security definer set search_path = public as $$
  select * from public.v_puestos_resumen
   where p_categoria is null or id_categoria = p_categoria
   order by guardados desc, calificaciones desc, fecha_apertura desc nulls last, creado_en desc
   limit greatest(p_limite, 1);
$$;

-- ---------------------------------------------------------------------
-- 7. RLS: activar en todas las tablas
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  for t in select tablename from pg_tables
           where schemaname = 'public' and tableowner = current_user loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Limpia políticas anteriores de ESTE script (permite repetirlo)
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies
           where schemaname = 'public' and policyname like 'tg\_%' loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ---- Catálogos de lectura pública (escribe solo el administrador) ----
create policy tg_categorias_leer    on public.categorias           for select to authenticated using (true);
create policy tg_categorias_admin   on public.categorias           for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_etiquetas_leer     on public.etiquetas_valoracion for select to authenticated using (true);
create policy tg_etiquetas_admin    on public.etiquetas_valoracion for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_tianguis_leer      on public.tianguis             for select to authenticated using (true);
create policy tg_tianguis_admin     on public.tianguis             for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_tghorarios_leer    on public.tianguis_horarios    for select to authenticated using (true);
create policy tg_tghorarios_admin   on public.tianguis_horarios    for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_zonas_leer         on public.tianguis_zonas       for select to authenticated using (true);
create policy tg_zonas_admin        on public.tianguis_zonas       for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_versiones_leer     on public.versiones_documento  for select to authenticated using (vigente or public.es_admin());
create policy tg_versiones_admin    on public.versiones_documento  for all    to authenticated using (public.es_admin()) with check (public.es_admin());

-- ---- Usuarios y cuenta ----
-- Ven tu fila: tú, el admin, quien tenga una conversación contigo y los vendedores (perfil público).
create policy tg_usuarios_leer on public.usuarios for select to authenticated using (
  id = auth.uid() or public.es_admin()
  or exists (select 1 from public.perfiles_vendedor pv where pv.id_usuario = usuarios.id)
  or exists (select 1 from public.conversaciones c
             where (c.id_iniciador = auth.uid() and c.id_receptor = usuarios.id)
                or (c.id_receptor  = auth.uid() and c.id_iniciador = usuarios.id))
);
create policy tg_usuarios_editar on public.usuarios for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy tg_admins_leer on public.administradores for select to authenticated
  using (id_usuario = auth.uid() or public.es_admin());

create policy tg_aceptaciones_leer   on public.aceptaciones_terminos for select to authenticated using (id_usuario = auth.uid());
create policy tg_aceptaciones_crear  on public.aceptaciones_terminos for insert to authenticated with check (id_usuario = auth.uid());

create policy tg_prefnotif_propias   on public.preferencias_notificacion for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy tg_silencios_propios   on public.silencios_notificacion    for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy tg_push_propios        on public.dispositivos_push         for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy tg_intereses_propios   on public.intereses_categoria       for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy tg_favoritos_propios   on public.favoritos                 for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
create policy tg_notif_leer          on public.notificaciones            for select to authenticated using (id_usuario = auth.uid());
create policy tg_notif_marcar        on public.notificaciones            for update to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

-- ---- Vendedores, puestos y productos (lectura pública, escribe el dueño) ----
create policy tg_vendedor_leer    on public.perfiles_vendedor for select to authenticated using (true);
create policy tg_vendedor_crear   on public.perfiles_vendedor for insert to authenticated with check (id_usuario = auth.uid());
create policy tg_vendedor_editar  on public.perfiles_vendedor for update to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

create policy tg_vtianguis_leer   on public.vendedor_tianguis for select to authenticated using (true);
create policy tg_vtianguis_dueno  on public.vendedor_tianguis for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

create policy tg_vhorarios_leer   on public.vendedor_horarios for select to authenticated using (true);
create policy tg_vhorarios_dueno  on public.vendedor_horarios for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

create policy tg_ausencias_leer   on public.ausencias_programadas for select to authenticated using (true);
create policy tg_ausencias_dueno  on public.ausencias_programadas for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

create policy tg_puestos_leer     on public.puestos for select to authenticated using (activo or public.es_mi_vendedor(id_vendedor) or public.es_admin());
create policy tg_puestos_dueno    on public.puestos for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

-- jornadas y códigos: SOLO el dueño (los crean las funciones abrir_puesto / generar_codigo_visita)
create policy tg_jornadas_dueno   on public.jornadas_puesto for select to authenticated using (
  exists (select 1 from public.puestos p where p.id = id_puesto and public.es_mi_vendedor(p.id_vendedor)));
create policy tg_codigos_dueno    on public.codigos_visita for select to authenticated using (
  exists (select 1 from public.jornadas_puesto j join public.puestos p on p.id = j.id_puesto
          where j.id = id_jornada and public.es_mi_vendedor(p.id_vendedor)));

create policy tg_productos_leer   on public.productos for select to authenticated using (
  (activo and not moderado) or public.es_mi_vendedor(id_vendedor) or public.es_admin());
create policy tg_productos_dueno  on public.productos for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

create policy tg_pimagenes_leer   on public.producto_imagenes for select to authenticated using (true);
create policy tg_pimagenes_dueno  on public.producto_imagenes for all    to authenticated
  using (exists (select 1 from public.productos p where p.id = id_producto and public.es_mi_vendedor(p.id_vendedor)))
  with check (exists (select 1 from public.productos p where p.id = id_producto and public.es_mi_vendedor(p.id_vendedor)));

create policy tg_ofertas_leer     on public.ofertas for select to authenticated using (true);
create policy tg_ofertas_dueno    on public.ofertas for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));
create policy tg_ofprod_leer      on public.oferta_productos for select to authenticated using (true);
create policy tg_ofprod_dueno     on public.oferta_productos for all    to authenticated
  using (exists (select 1 from public.ofertas o where o.id = id_oferta and public.es_mi_vendedor(o.id_vendedor)))
  with check (exists (select 1 from public.ofertas o where o.id = id_oferta and public.es_mi_vendedor(o.id_vendedor)));

create policy tg_anuncios_leer    on public.anuncios_espacio for select to authenticated using (not moderado or public.es_mi_vendedor(id_vendedor) or public.es_admin());
create policy tg_anuncios_dueno   on public.anuncios_espacio for all    to authenticated using (public.es_mi_vendedor(id_vendedor)) with check (public.es_mi_vendedor(id_vendedor));

-- ---- Visitas y calificaciones ----
create policy tg_visitas_leer on public.visitas for select to authenticated using (
  id_usuario = auth.uid()
  or exists (select 1 from public.puestos p where p.id = id_puesto and public.es_mi_vendedor(p.id_vendedor)));

create policy tg_calif_leer   on public.calificaciones for select to authenticated using (not moderado or id_usuario = auth.uid() or public.es_admin());
create policy tg_calif_crear  on public.calificaciones for insert to authenticated with check (true); -- el trigger valida y fija id_usuario
create policy tg_calif_borrar on public.calificaciones for delete to authenticated using (id_usuario = auth.uid());
create policy tg_calif_et_leer  on public.calificacion_etiquetas for select to authenticated using (true);
create policy tg_calif_et_crear on public.calificacion_etiquetas for insert to authenticated
  with check (exists (select 1 from public.calificaciones k where k.id = id_calificacion and k.id_usuario = auth.uid()));

-- ---- Chat, propuestas y apartados ----
create policy tg_conv_leer   on public.conversaciones for select to authenticated using (id_iniciador = auth.uid() or id_receptor = auth.uid());
create policy tg_conv_crear  on public.conversaciones for insert to authenticated
  with check (id_iniciador = auth.uid() and not public.hay_bloqueo(id_iniciador, id_receptor));

create policy tg_msj_leer    on public.mensajes for select to authenticated using (public.soy_de_conversacion(id_conversacion));
create policy tg_msj_crear   on public.mensajes for insert to authenticated with check (
  id_remitente = auth.uid() and public.soy_de_conversacion(id_conversacion)
  and not exists (select 1 from public.conversaciones c
                  where c.id = id_conversacion
                    and public.hay_bloqueo(c.id_iniciador, c.id_receptor)));
create policy tg_msj_leido   on public.mensajes for update to authenticated
  using (public.soy_de_conversacion(id_conversacion) and id_remitente <> auth.uid())
  with check (public.soy_de_conversacion(id_conversacion));

create policy tg_bloqueos_propios on public.bloqueos for all to authenticated
  using (id_bloqueador = auth.uid()) with check (id_bloqueador = auth.uid());

create policy tg_prop_leer   on public.propuestas_precio for select to authenticated
  using (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor));
create policy tg_prop_crear  on public.propuestas_precio for insert to authenticated
  with check (id_emisor = auth.uid() and (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor)));
create policy tg_prop_resp   on public.propuestas_precio for update to authenticated
  using (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor))
  with check (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor));

create policy tg_apart_leer  on public.apartados for select to authenticated
  using (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor));
create policy tg_apart_crear on public.apartados for insert to authenticated with check (id_comprador = auth.uid());
create policy tg_apart_edit  on public.apartados for update to authenticated
  using (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor))
  with check (id_comprador = auth.uid() or public.es_mi_vendedor(id_vendedor));

-- ---- Moderación ----
create policy tg_rep_crear   on public.reportes for insert to authenticated with check (id_reportante = auth.uid());
create policy tg_rep_leer    on public.reportes for select to authenticated using (id_reportante = auth.uid() or public.es_admin());
create policy tg_rep_admin   on public.reportes for update to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_medidas_leer  on public.medidas_moderacion for select to authenticated using (id_usuario_afectado = auth.uid() or public.es_admin());
create policy tg_medidas_admin on public.medidas_moderacion for all    to authenticated using (public.es_admin()) with check (public.es_admin());
create policy tg_apel_crear  on public.apelaciones for insert to authenticated with check (id_usuario = auth.uid());
create policy tg_apel_leer   on public.apelaciones for select to authenticated using (id_usuario = auth.uid() or public.es_admin());
create policy tg_apel_admin  on public.apelaciones for update to authenticated using (public.es_admin()) with check (public.es_admin());

-- ---------------------------------------------------------------------
-- 8. Storage: buckets públicos de lectura; cada quien sube en su carpeta <uid>/...
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('productos', 'productos', true), ('perfiles', 'perfiles', true)
on conflict (id) do update set public = true;

drop policy if exists tg_storage_leer   on storage.objects;
drop policy if exists tg_storage_subir  on storage.objects;
drop policy if exists tg_storage_editar on storage.objects;
drop policy if exists tg_storage_borrar on storage.objects;

create policy tg_storage_leer on storage.objects for select to authenticated
  using (bucket_id in ('productos', 'perfiles'));
create policy tg_storage_subir on storage.objects for insert to authenticated
  with check (bucket_id in ('productos', 'perfiles') and (storage.foldername(name))[1] = auth.uid()::text);
create policy tg_storage_editar on storage.objects for update to authenticated
  using (bucket_id in ('productos', 'perfiles') and (storage.foldername(name))[1] = auth.uid()::text);
create policy tg_storage_borrar on storage.objects for delete to authenticated
  using (bucket_id in ('productos', 'perfiles') and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------
-- 9. Índice que exigen las llaves compuestas del esquema
-- ---------------------------------------------------------------------
create unique index if not exists vendedor_tianguis_vendedor_tianguis_uk
  on public.vendedor_tianguis (id_vendedor, id_tianguis);
