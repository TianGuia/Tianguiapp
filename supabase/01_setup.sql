-- =====================================================================
-- TianGuía · Seguridad y funciones sobre tu esquema existente
-- Ejecutar en Supabase > SQL Editor (una sola vez; es re-ejecutable).
-- Antes de nada, revisa los valores de tus ENUM (ver README, paso 3).
-- =====================================================================

-- ---------- Helpers ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from administradores where id_usuario = auth.uid());
$$;

create or replace function public.mi_vendedor_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from perfiles_vendedor where id_usuario = auth.uid();
$$;

-- ---------- Alta automática de usuarios (RF-01) ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into usuarios (id, nombre_publico, correo, telefono)
  values (
    new.id,
    left(coalesce(nullif(new.raw_user_meta_data->>'nombre',''),
                  nullif(split_part(coalesce(new.email,''),'@',1),''),
                  'Usuario'), 80),
    new.email,
    new.phone
  ) on conflict (id) do nothing;

  insert into preferencias_notificacion (id_usuario) values (new.id)
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Activar RLS en TODAS las tablas de public ----------
do $$ declare t text; begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- ---------- Vista pública de usuarios (sin correo ni teléfono) ----------
create or replace view public.usuarios_publicos as
  select id, nombre_publico, foto_url from public.usuarios where estado_cuenta::text = 'activa';
grant select on public.usuarios_publicos to authenticated;

-- ---------- POLÍTICAS ----------
-- Macro mental: "lectura pública" = anon + authenticated; escritura solo dueño/admin.

-- usuarios
drop policy if exists usr_sel on usuarios;
create policy usr_sel on usuarios for select to authenticated using (id = auth.uid() or is_admin());
drop policy if exists usr_upd on usuarios;
create policy usr_upd on usuarios for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- administradores: solo ellos se ven; altas se hacen desde el SQL Editor
drop policy if exists adm_sel on administradores;
create policy adm_sel on administradores for select to authenticated using (id_usuario = auth.uid());

-- catálogos de lectura pública, escritura admin
do $$ declare t text; begin
  foreach t in array array['categorias','etiquetas_valoracion','tianguis','tianguis_horarios','tianguis_zonas','versiones_documento'] loop
    execute format('drop policy if exists %I on public.%I', t||'_sel', t);
    execute format('create policy %I on public.%I for select to anon, authenticated using (true)', t||'_sel', t);
    execute format('drop policy if exists %I on public.%I', t||'_adm', t);
    execute format('create policy %I on public.%I for all to authenticated using (is_admin()) with check (is_admin())', t||'_adm', t);
  end loop;
end $$;

-- aceptaciones de términos
drop policy if exists acep_sel on aceptaciones_terminos;
create policy acep_sel on aceptaciones_terminos for select to authenticated using (id_usuario = auth.uid() or is_admin());

-- perfiles de vendedor (lectura para autenticados; alta vía RPC)
drop policy if exists pv_sel on perfiles_vendedor;
create policy pv_sel on perfiles_vendedor for select to authenticated using (true);
drop policy if exists pv_upd on perfiles_vendedor;
create policy pv_upd on perfiles_vendedor for update to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());

-- tablas del vendedor con columna id_vendedor
do $$ declare t text; begin
  foreach t in array array['vendedor_tianguis','vendedor_horarios','ausencias_programadas','puestos','ofertas','anuncios_espacio'] loop
    execute format('drop policy if exists %I on public.%I', t||'_sel', t);
    execute format('create policy %I on public.%I for select to authenticated using (true)', t||'_sel', t);
    execute format('drop policy if exists %I on public.%I', t||'_own', t);
    execute format($f$create policy %I on public.%I for all to authenticated
        using (id_vendedor = mi_vendedor_id()) with check (id_vendedor = mi_vendedor_id())$f$, t||'_own', t);
  end loop;
end $$;

-- puestos visibles también para anon (el comprador puede mirar antes de registrarse)
drop policy if exists puestos_anon on puestos;
create policy puestos_anon on puestos for select to anon using (activo);

-- productos: públicos si activos y no moderados; dueño ve/edita todo
drop policy if exists prod_sel on productos;
create policy prod_sel on productos for select to anon, authenticated
  using ((activo and not moderado) or id_vendedor = mi_vendedor_id() or is_admin());
drop policy if exists prod_own on productos;
create policy prod_own on productos for all to authenticated
  using (id_vendedor = mi_vendedor_id()) with check (id_vendedor = mi_vendedor_id());

drop policy if exists pimg_sel on producto_imagenes;
create policy pimg_sel on producto_imagenes for select to anon, authenticated using (true);
drop policy if exists pimg_own on producto_imagenes;
create policy pimg_own on producto_imagenes for all to authenticated
  using (exists (select 1 from productos p where p.id = id_producto and p.id_vendedor = mi_vendedor_id()))
  with check (exists (select 1 from productos p where p.id = id_producto and p.id_vendedor = mi_vendedor_id()));

-- oferta_productos
drop policy if exists ofp_sel on oferta_productos;
create policy ofp_sel on oferta_productos for select to authenticated using (true);
drop policy if exists ofp_own on oferta_productos;
create policy ofp_own on oferta_productos for all to authenticated
  using (exists (select 1 from ofertas o where o.id = id_oferta and o.id_vendedor = mi_vendedor_id()))
  with check (exists (select 1 from ofertas o where o.id = id_oferta and o.id_vendedor = mi_vendedor_id()));

-- conversaciones y mensajes (solo participantes)
drop policy if exists conv_sel on conversaciones;
create policy conv_sel on conversaciones for select to authenticated
  using (auth.uid() in (id_iniciador, id_receptor));
drop policy if exists conv_ins on conversaciones;
create policy conv_ins on conversaciones for insert to authenticated
  with check (id_iniciador = auth.uid() and id_receptor <> auth.uid());

drop policy if exists msg_sel on mensajes;
create policy msg_sel on mensajes for select to authenticated
  using (exists (select 1 from conversaciones c where c.id = id_conversacion and auth.uid() in (c.id_iniciador, c.id_receptor)));
drop policy if exists msg_ins on mensajes;
create policy msg_ins on mensajes for insert to authenticated
  with check (
    id_remitente = auth.uid()
    and exists (select 1 from conversaciones c where c.id = id_conversacion and auth.uid() in (c.id_iniciador, c.id_receptor))
    -- RF-38: sin bloqueos activos entre los participantes
    and not exists (
      select 1 from bloqueos b join conversaciones c on c.id = id_conversacion
      where b.activo and (
        (b.id_bloqueador = c.id_iniciador and b.id_bloqueado = c.id_receptor) or
        (b.id_bloqueador = c.id_receptor  and b.id_bloqueado = c.id_iniciador))
    )
  );
drop policy if exists msg_upd on mensajes;  -- marcar como leído (solo el que NO envió)
create policy msg_upd on mensajes for update to authenticated
  using (id_remitente <> auth.uid() and exists (select 1 from conversaciones c where c.id = id_conversacion and auth.uid() in (c.id_iniciador, c.id_receptor)));

drop policy if exists blq_all on bloqueos;
create policy blq_all on bloqueos for all to authenticated
  using (id_bloqueador = auth.uid()) with check (id_bloqueador = auth.uid());

-- propuestas de precio y apartados
drop policy if exists prop_sel on propuestas_precio;
create policy prop_sel on propuestas_precio for select to authenticated
  using (id_comprador = auth.uid() or id_vendedor = mi_vendedor_id());
drop policy if exists prop_ins on propuestas_precio;
create policy prop_ins on propuestas_precio for insert to authenticated
  with check (id_emisor = auth.uid() and (id_comprador = auth.uid() or id_vendedor = mi_vendedor_id()));
drop policy if exists prop_upd on propuestas_precio;
create policy prop_upd on propuestas_precio for update to authenticated
  using (id_vendedor = mi_vendedor_id() or id_comprador = auth.uid());

drop policy if exists apt_sel on apartados;
create policy apt_sel on apartados for select to authenticated
  using (id_comprador = auth.uid() or id_vendedor = mi_vendedor_id());
drop policy if exists apt_ins on apartados;
create policy apt_ins on apartados for insert to authenticated with check (id_comprador = auth.uid());
drop policy if exists apt_upd on apartados;
create policy apt_upd on apartados for update to authenticated
  using (id_vendedor = mi_vendedor_id() or id_comprador = auth.uid());

-- datos propios del usuario
do $$ declare t text; begin
  foreach t in array array['favoritos','intereses_categoria','silencios_notificacion','dispositivos_push'] loop
    execute format('drop policy if exists %I on public.%I', t||'_own', t);
    execute format('create policy %I on public.%I for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid())', t||'_own', t);
  end loop;
end $$;
drop policy if exists pn_own on preferencias_notificacion;
create policy pn_own on preferencias_notificacion for all to authenticated using (id_usuario = auth.uid()) with check (id_usuario = auth.uid());
drop policy if exists not_sel on notificaciones;
create policy not_sel on notificaciones for select to authenticated using (id_usuario = auth.uid());
drop policy if exists not_upd on notificaciones;
create policy not_upd on notificaciones for update to authenticated using (id_usuario = auth.uid());

-- jornadas / códigos / visitas / calificaciones
drop policy if exists jor_sel on jornadas_puesto;
create policy jor_sel on jornadas_puesto for select to authenticated using (true);
drop policy if exists cod_sel on codigos_visita;   -- solo el dueño del puesto ve el código
create policy cod_sel on codigos_visita for select to authenticated using (
  exists (select 1 from jornadas_puesto j join puestos p on p.id = j.id_puesto
          where j.id = id_jornada and p.id_vendedor = mi_vendedor_id()));
drop policy if exists vis_sel on visitas;
create policy vis_sel on visitas for select to authenticated using (id_usuario = auth.uid());
drop policy if exists cal_sel on calificaciones;
create policy cal_sel on calificaciones for select to authenticated using (not moderado or id_usuario = auth.uid() or is_admin());
drop policy if exists cale_sel on calificacion_etiquetas;
create policy cale_sel on calificacion_etiquetas for select to authenticated using (true);

-- reportes, medidas y apelaciones
drop policy if exists rep_ins on reportes;
create policy rep_ins on reportes for insert to authenticated with check (id_reportante = auth.uid());
drop policy if exists rep_sel on reportes;
create policy rep_sel on reportes for select to authenticated using (id_reportante = auth.uid() or is_admin());
drop policy if exists rep_adm on reportes;
create policy rep_adm on reportes for update to authenticated using (is_admin()) with check (is_admin());

drop policy if exists med_sel on medidas_moderacion;
create policy med_sel on medidas_moderacion for select to authenticated using (id_usuario_afectado = auth.uid() or is_admin());
drop policy if exists med_adm on medidas_moderacion;
create policy med_adm on medidas_moderacion for all to authenticated using (is_admin()) with check (is_admin());

drop policy if exists ape_ins on apelaciones;
create policy ape_ins on apelaciones for insert to authenticated with check (id_usuario = auth.uid());
drop policy if exists ape_sel on apelaciones;
create policy ape_sel on apelaciones for select to authenticated using (id_usuario = auth.uid() or is_admin());
drop policy if exists ape_adm on apelaciones;
create policy ape_adm on apelaciones for update to authenticated using (is_admin()) with check (is_admin());

-- ---------- Triggers ----------
create or replace function public.tg_ultimo_mensaje() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update conversaciones set ultimo_mensaje_en = new.enviado_en where id = new.id_conversacion;
  return new;
end $$;
drop trigger if exists mensajes_ultimo on mensajes;
create trigger mensajes_ultimo after insert on mensajes for each row execute function tg_ultimo_mensaje();

-- ---------- RPC: términos (RF-40, RF-53) ----------
create or replace function public.aceptar_terminos_vigentes() returns void
language sql security definer set search_path = public as $$
  insert into aceptaciones_terminos (id_usuario, id_version)
  select auth.uid(), v.id from versiones_documento v
  where v.vigente and not exists (
    select 1 from aceptaciones_terminos a where a.id_usuario = auth.uid() and a.id_version = v.id);
$$;

create or replace function public.terminos_pendientes() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from versiones_documento v
    where v.vigente and v.requiere_reaceptacion and not exists (
      select 1 from aceptaciones_terminos a where a.id_usuario = auth.uid() and a.id_version = v.id));
$$;

-- ---------- RPC: vendedor (RF-19) ----------
create or replace function public.habilitar_vendedor(p_nombre_negocio text default null, p_descripcion text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  insert into perfiles_vendedor (id_usuario, nombre_negocio, descripcion)
  values (auth.uid(), p_nombre_negocio, p_descripcion)
  on conflict (id_usuario) do update set nombre_negocio = coalesce(excluded.nombre_negocio, perfiles_vendedor.nombre_negocio)
  returning id into v_id;
  return v_id;
end $$;

-- ---------- RPC: puesto abierto/cerrado + ubicación (RF-27, RF-28) ----------
create or replace function public.abrir_puesto(p_puesto uuid, p_lat double precision, p_lng double precision, p_precision real default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_jornada uuid;
begin
  if not exists (select 1 from puestos where id = p_puesto and id_vendedor = mi_vendedor_id()) then
    raise exception 'El puesto no te pertenece';
  end if;
  update jornadas_puesto set fecha_cierre = now() where id_puesto = p_puesto and fecha_cierre is null;
  insert into jornadas_puesto (id_puesto, latitud, longitud, precision_m)
  values (p_puesto, p_lat, p_lng, p_precision) returning id into v_jornada;
  update puestos set estado = 'abierto', latitud = p_lat, longitud = p_lng,
         fecha_apertura = now(), fecha_cierre = null where id = p_puesto;
  return v_jornada;
end $$;

create or replace function public.cerrar_puesto(p_puesto uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from puestos where id = p_puesto and id_vendedor = mi_vendedor_id()) then
    raise exception 'El puesto no te pertenece';
  end if;
  update jornadas_puesto set fecha_cierre = now() where id_puesto = p_puesto and fecha_cierre is null;
  update puestos set estado = 'cerrado', fecha_cierre = now() where id = p_puesto;
end $$;

-- ---------- RPC: código de visita (RF-41) ----------
create or replace function public.generar_codigo_visita(p_puesto uuid)
returns table (codigo text, expira_en timestamptz)
language plpgsql security definer set search_path = public as $$
declare v_jornada uuid; v_codigo text; v_exp timestamptz := now() + interval '15 minutes';
begin
  if not exists (select 1 from puestos where id = p_puesto and id_vendedor = mi_vendedor_id()) then
    raise exception 'El puesto no te pertenece';
  end if;
  select id into v_jornada from jornadas_puesto where id_puesto = p_puesto and fecha_cierre is null
    order by fecha_apertura desc limit 1;
  if v_jornada is null then raise exception 'El puesto está cerrado'; end if;
  v_codigo := lpad(floor(random() * 1000000)::int::text, 6, '0');
  insert into codigos_visita (id_jornada, codigo, expira_en) values (v_jornada, v_codigo, v_exp);
  return query select v_codigo, v_exp;
end $$;

create or replace function public.verificar_visita(p_puesto uuid, p_codigo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_jornada uuid; v_visita uuid;
begin
  select j.id into v_jornada
  from jornadas_puesto j join codigos_visita c on c.id_jornada = j.id
  where j.id_puesto = p_puesto and j.fecha_cierre is null
    and c.codigo = p_codigo and c.expira_en > now()
  limit 1;
  if v_jornada is null then raise exception 'Código inválido o vencido'; end if;

  select id into v_visita from visitas where id_usuario = auth.uid() and id_jornada = v_jornada;
  if v_visita is null then
    insert into visitas (id_usuario, id_puesto, id_jornada) values (auth.uid(), p_puesto, v_jornada)
    returning id into v_visita;
  end if;
  return v_visita;
end $$;

-- ---------- RPC: calificar (RF-42) ----------
create or replace function public.registrar_calificacion(p_visita uuid, p_puntuacion smallint, p_comentario text, p_etiquetas uuid[] default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_pu uuid; v_ven uuid; v_cal uuid; e uuid;
begin
  select v.id_puesto, p.id_vendedor into v_pu, v_ven
  from visitas v join puestos p on p.id = v.id_puesto
  where v.id = p_visita and v.id_usuario = auth.uid();
  if v_pu is null then raise exception 'Visita no verificada'; end if;

  insert into calificaciones (id_visita, id_usuario, id_puesto, id_vendedor, puntuacion, comentario)
  values (p_visita, auth.uid(), v_pu, v_ven, p_puntuacion, p_comentario) returning id into v_cal;
  foreach e in array coalesce(p_etiquetas, '{}') loop
    insert into calificacion_etiquetas values (v_cal, e) on conflict do nothing;
  end loop;
  return v_cal;
end $$;

-- ---------- Storage (RF-23, RF-05) ----------
insert into storage.buckets (id, name, public) values ('productos','productos',true), ('perfiles','perfiles',true)
on conflict (id) do nothing;

drop policy if exists st_pub_read on storage.objects;
create policy st_pub_read on storage.objects for select to public using (bucket_id in ('productos','perfiles'));
drop policy if exists st_own_write on storage.objects;
create policy st_own_write on storage.objects for insert to authenticated
  with check (bucket_id in ('productos','perfiles') and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists st_own_del on storage.objects;
create policy st_own_del on storage.objects for delete to authenticated
  using (bucket_id in ('productos','perfiles') and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- Realtime ----------
do $$ begin
  begin alter publication supabase_realtime add table public.mensajes; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.puestos;  exception when duplicate_object then null; end;
end $$;

-- ---------- Permisos de ejecución de RPC ----------
revoke all on function habilitar_vendedor, abrir_puesto, cerrar_puesto, generar_codigo_visita,
  verificar_visita, registrar_calificacion, aceptar_terminos_vigentes, terminos_pendientes from public, anon;
grant execute on function habilitar_vendedor, abrir_puesto, cerrar_puesto, generar_codigo_visita,
  verificar_visita, registrar_calificacion, aceptar_terminos_vigentes, terminos_pendientes to authenticated;
