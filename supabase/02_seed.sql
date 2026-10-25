-- =====================================================================
-- TianGuía · 02_seed.sql  (datos de arranque; se puede repetir)
-- =====================================================================

-- Categorías (las del diseño)
insert into public.categorias (nombre) values
  ('Chacharas'), ('Comida'), ('Frutas'), ('Ropa'), ('Servicios')
on conflict (nombre) do nothing;

-- Etiquetas para calificar
insert into public.etiquetas_valoracion (nombre) values
  ('Amable'), ('Buen precio'), ('Productos de calidad'), ('Puesto limpio'), ('Puntual')
on conflict (nombre) do nothing;

-- Tianguis de ejemplo (cámbialos por los reales). dia_semana: 0 = domingo ... 6 = sábado
insert into public.tianguis (nombre, descripcion, direccion)
select v.nombre, v.descripcion, v.direccion
from (values
  ('El Niño 1',     'Tianguis de los lunes',   'Por definir'),
  ('Jalua',         'Tianguis de los viernes', 'Por definir'),
  ('Mercado Local', 'Todos los días',          'Por definir')
) as v(nombre, descripcion, direccion)
where not exists (select 1 from public.tianguis t where t.nombre = v.nombre);

insert into public.tianguis_horarios (id_tianguis, dia_semana, hora_inicio, hora_fin)
select t.id, h.dia, h.ini::time, h.fin::time
from (values
  ('El Niño 1', 1, '08:00', '16:00'),
  ('Jalua',     5, '08:00', '16:00')
) as h(nombre, dia, ini, fin)
join public.tianguis t on t.nombre = h.nombre
where not exists (select 1 from public.tianguis_horarios x
                  where x.id_tianguis = t.id and x.dia_semana = h.dia);

insert into public.tianguis_horarios (id_tianguis, dia_semana, hora_inicio, hora_fin)
select t.id, d, '08:00'::time, '18:00'::time
from public.tianguis t, generate_series(0, 6) as d
where t.nombre = 'Mercado Local'
  and not exists (select 1 from public.tianguis_horarios x where x.id_tianguis = t.id and x.dia_semana = d);

-- Términos y aviso de privacidad (RF-40): una versión 1.0 por cada valor del enum "tipo".
-- Reemplaza el texto por el documento legal real antes de publicar la app.
do $$
declare t regtype; l text;
begin
  select atttypid::regtype into t from pg_attribute
   where attrelid = 'public.versiones_documento'::regclass and attname = 'tipo';
  for l in execute format('select unnest(enum_range(null::%s))::text', t) loop
    if not exists (select 1 from public.versiones_documento where tipo::text = l) then
      execute format(
        'insert into public.versiones_documento (tipo, version, contenido) values (%L::%s, %L, %L)',
        l, t, '1.0', 'Texto provisional de "' || l || '". Sustitúyelo por el documento oficial.');
    end if;
  end loop;
end $$;

-- Para ser administrador (cambia el correo por el tuyo, después de registrarte en la app):
-- insert into public.administradores (id_usuario)
-- select id from public.usuarios where correo = 'tu_correo@ejemplo.com';
