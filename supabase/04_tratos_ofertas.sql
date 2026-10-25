-- =====================================================================
-- TianGuía · 04_tratos_ofertas.sql  (se puede repetir)
-- Ejecutar DESPUÉS de 01, 02 y 03.
-- Cubre: RF-17/31 (propuestas y contraofertas), RF-18/32 (apartados),
--        RF-29/30 (ofertas que vencen solas).
-- =====================================================================

-- 0. Verifica que tus ENUM tengan los valores que usa este script ----------------
--    Si falta alguno, el script se detiene y te dice qué agregar.
do $$
declare faltan text;
begin
  select string_agg(format('alter type public.%s add value %L;', v.t, v.l), E'\n') into faltan
    from (values
      ('estado_propuesta', 'pendiente'), ('estado_propuesta', 'aceptada'),
      ('estado_propuesta', 'rechazada'), ('estado_propuesta', 'contraofertada'),
      ('estado_apartado',  'pendiente'), ('estado_apartado',  'aceptado'),
      ('estado_apartado',  'rechazado'), ('estado_apartado',  'cancelado'),
      ('estado_apartado',  'expirado'),
      ('estado_oferta',    'activa'),    ('estado_oferta',    'finalizada')
    ) as v(t, l)
   where not exists (
     select 1 from pg_enum e join pg_type ty on ty.oid = e.enumtypid
      where ty.typname = v.t and e.enumlabel = v.l);

  if faltan is not null then
    raise exception E'A tus ENUM les faltan valores. Ejecuta esto (cada línea sola, una por una) y vuelve a correr este script:\n%', faltan;
  end if;
end $$;

-- 1. Candado: el estado de propuestas y apartados SOLO cambia con las funciones de abajo
create or replace function public.tratos_guard()
returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('tianguia.rpc', true), '') = '1' or public.es_admin() then
    return new;
  end if;
  if new.estado is distinct from old.estado then
    raise exception 'Usa las opciones de la app para responder (el estado no se cambia directo)';
  end if;
  if tg_table_name = 'apartados' and (new.cantidad is distinct from old.cantidad
                                      or new.id_producto is distinct from old.id_producto) then
    raise exception 'No se puede modificar un apartado ya creado';
  end if;
  if tg_table_name = 'propuestas_precio' and (new.monto is distinct from old.monto
                                              or new.id_producto is distinct from old.id_producto) then
    raise exception 'No se puede modificar una propuesta ya enviada';
  end if;
  return new;
end $$;

drop trigger if exists propuestas_guard on public.propuestas_precio;
create trigger propuestas_guard before update on public.propuestas_precio
  for each row execute function public.tratos_guard();

drop trigger if exists apartados_guard on public.apartados;
create trigger apartados_guard before update on public.apartados
  for each row execute function public.tratos_guard();

-- 2. Responder una propuesta: aceptar | rechazar | contraofertar (RF-31) -------------
--    Responde la persona que NO la envió (el vendedor responde al comprador y
--    el comprador puede responder a una contraoferta del vendedor).
create or replace function public.responder_propuesta(
  p_id uuid, p_accion text, p_monto numeric default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare r record; v_user_vendedor uuid; v_nuevo uuid;
begin
  select * into r from public.propuestas_precio where id = p_id for update;
  if not found then raise exception 'Propuesta no encontrada'; end if;

  select id_usuario into v_user_vendedor from public.perfiles_vendedor where id = r.id_vendedor;
  if auth.uid() is null or auth.uid() not in (r.id_comprador, v_user_vendedor) then
    raise exception 'No participas en esta propuesta';
  end if;
  if r.id_emisor = auth.uid() then
    raise exception 'Esta propuesta la envió otra persona: ella debe responderla';
  end if;
  if r.estado::text <> 'pendiente' then
    raise exception 'Esta propuesta ya fue respondida';
  end if;

  perform set_config('tianguia.rpc', '1', true);

  if p_accion = 'aceptar' then
    update public.propuestas_precio set estado = 'aceptada', respondida_en = now() where id = p_id;
    return p_id;
  elsif p_accion = 'rechazar' then
    update public.propuestas_precio set estado = 'rechazada', respondida_en = now() where id = p_id;
    return p_id;
  elsif p_accion = 'contraofertar' then
    if p_monto is null or p_monto < 0 then raise exception 'Escribe un monto válido'; end if;
    update public.propuestas_precio set estado = 'contraofertada', respondida_en = now() where id = p_id;
    insert into public.propuestas_precio
      (id_producto, id_comprador, id_vendedor, id_emisor, id_propuesta_anterior, monto)
    values (r.id_producto, r.id_comprador, r.id_vendedor, auth.uid(), p_id, p_monto)
    returning id into v_nuevo;
    return v_nuevo;
  end if;
  raise exception 'Acción no válida: %', p_accion;
end $$;

-- 3. Responder un apartado: aceptar | rechazar | cancelar (RF-32) ----------------------
--    Al ACEPTAR se descuentan las piezas; al cancelar/expirar un apartado aceptado se liberan.
create or replace function public.responder_apartado(p_id uuid, p_accion text)
returns void
language plpgsql security definer set search_path = public as $$
declare r record; v_user_vendedor uuid; es_v boolean; es_c boolean; e text; v_cant integer;
begin
  select * into r from public.apartados where id = p_id for update;
  if not found then raise exception 'Apartado no encontrado'; end if;

  select id_usuario into v_user_vendedor from public.perfiles_vendedor where id = r.id_vendedor;
  es_v := (auth.uid() = v_user_vendedor);
  es_c := (auth.uid() = r.id_comprador);
  if not (es_v or es_c) then raise exception 'No participas en este apartado'; end if;
  e := r.estado::text;

  perform set_config('tianguia.rpc', '1', true);

  if p_accion = 'aceptar' then
    if not es_v then raise exception 'Solo el vendedor puede aceptar'; end if;
    if e <> 'pendiente' then raise exception 'Este apartado ya fue respondido'; end if;
    if r.fecha_expiracion is not null and r.fecha_expiracion < now() then
      raise exception 'La solicitud ya venció';
    end if;
    select cantidad_disponible into v_cant from public.productos where id = r.id_producto for update;
    if v_cant is not null then
      if v_cant < r.cantidad then raise exception 'No hay suficientes piezas disponibles'; end if;
      update public.productos
         set cantidad_disponible = v_cant - r.cantidad,
             disponible = (v_cant - r.cantidad) > 0,
             actualizado_en = now()
       where id = r.id_producto;
    end if;
    -- el apartado aceptado dura 24 h a partir de que el vendedor acepta
    update public.apartados set estado = 'aceptado', fecha_expiracion = now() + interval '24 hours'
     where id = p_id;

  elsif p_accion = 'rechazar' then
    if not es_v then raise exception 'Solo el vendedor puede rechazar'; end if;
    if e <> 'pendiente' then raise exception 'Este apartado ya fue respondido'; end if;
    update public.apartados set estado = 'rechazado' where id = p_id;

  elsif p_accion = 'cancelar' then
    if not ((es_c and e in ('pendiente', 'aceptado')) or (es_v and e = 'aceptado')) then
      raise exception 'No se puede cancelar en este estado';
    end if;
    if e = 'aceptado' then
      update public.productos
         set cantidad_disponible = cantidad_disponible + r.cantidad, disponible = true,
             actualizado_en = now()
       where id = r.id_producto and cantidad_disponible is not null;
    end if;
    update public.apartados set estado = 'cancelado' where id = p_id;

  else
    raise exception 'Acción no válida: %', p_accion;
  end if;
end $$;

-- 4. Vencimientos automáticos (RF-30, RF-32) -------------------------------------------
create or replace function public.vencer_pendientes()
returns void
language plpgsql security definer set search_path = public as $$
declare a record;
begin
  perform set_config('tianguia.rpc', '1', true);

  for a in
    select id, id_producto, cantidad, estado::text as e from public.apartados
     where estado::text in ('pendiente', 'aceptado')
       and fecha_expiracion is not null and fecha_expiracion < now()
     for update
  loop
    if a.e = 'aceptado' then
      update public.productos
         set cantidad_disponible = cantidad_disponible + a.cantidad, disponible = true,
             actualizado_en = now()
       where id = a.id_producto and cantidad_disponible is not null;
    end if;
    update public.apartados set estado = 'expirado' where id = a.id;
  end loop;

  update public.ofertas set estado = 'finalizada'
   where estado::text = 'activa' and fecha_fin < now();
end $$;

revoke all on function public.vencer_pendientes() from public, anon;
grant execute on function public.vencer_pendientes() to authenticated;
grant execute on function public.responder_propuesta(uuid, text, numeric) to authenticated;
grant execute on function public.responder_apartado(uuid, text) to authenticated;

-- Cron cada 10 min (necesita la extensión pg_cron). Si no está disponible no pasa
-- nada: la app llama a vencer_pendientes() cada vez que abre las bandejas.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule(jobid) from cron.job where jobname = 'tianguia_vencer';
  perform cron.schedule('tianguia_vencer', '*/10 * * * *', 'select public.vencer_pendientes()');
exception when others then
  raise notice 'pg_cron no disponible (%). Actívalo en Database > Extensions si quieres vencimiento automático.', sqlerrm;
end $$;

-- 5. El vendedor debe poder ver el NOMBRE de quien le propone o aparta -------------------
--    (tg_usuarios_leer solo deja ver a quien ya chateó con él). Esta política se SUMA
--    a las de 01 y no se borra si repites 01 porque no empieza con "tg_".
drop policy if exists trato_usuarios_leer on public.usuarios;
create policy trato_usuarios_leer on public.usuarios for select to authenticated using (
  exists (select 1 from public.propuestas_precio pp
           where pp.id_comprador = usuarios.id and public.es_mi_vendedor(pp.id_vendedor))
  or exists (select 1 from public.apartados ap
              where ap.id_comprador = usuarios.id and public.es_mi_vendedor(ap.id_vendedor))
);
