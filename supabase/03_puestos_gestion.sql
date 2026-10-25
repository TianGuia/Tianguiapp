-- =====================================================================
-- TianGuía · 03_puestos_gestion.sql  (se puede repetir)
-- Ejecutar DESPUÉS de 01_setup.sql y 02_seed.sql.
--
-- NO crea políticas ni funciones nuevas de permisos: 01_setup.sql ya deja que
-- el dueño edite/borre sus puestos, productos, imágenes y archivos de Storage
-- (tg_puestos_dueno, tg_productos_dueno, tg_pimagenes_dueno, tg_storage_*).
-- Aquí solo se agregan columnas, un trigger y se ajusta la vista del inicio.
-- =====================================================================

-- 1. Datos nuevos del puesto: descripción, foto y tipo de cierre ----------------
alter table public.puestos
  add column if not exists descripcion   text,
  add column if not exists foto_ruta     text,   -- ruta en Storage (bucket 'productos')
  add column if not exists cierre_tipo   text,   -- null = cierre normal del día
  add column if not exists reabre_en     date,   -- solo para 'temporal' (opcional)
  add column if not exists cierre_motivo text;

do $$ begin
  alter table public.puestos
    add constraint puestos_cierre_tipo_chk
    check (cierre_tipo is null or cierre_tipo in ('temporal', 'hasta_nuevo_aviso'));
exception when duplicate_object then null; end $$;

-- 2. Al abrir el puesto se limpia cualquier cierre temporal / indefinido --------
--    (así no hay que tocar tu función abrir_puesto)
create or replace function public.puestos_limpiar_cierre()
returns trigger language plpgsql as $$
begin
  if new.estado::text = 'abierto' then
    new.cierre_tipo   := null;
    new.reabre_en     := null;
    new.cierre_motivo := null;
  end if;
  return new;
end $$;

drop trigger if exists puestos_limpiar_cierre on public.puestos;
create trigger puestos_limpiar_cierre
  before insert or update on public.puestos
  for each row execute function public.puestos_limpiar_cierre();

-- 3. Vista del inicio: usa la descripción y la foto PROPIAS del puesto ----------
--    Mismas columnas, mismo orden y mismos tipos que en 01_setup.sql, solo cambian
--    dos expresiones (descripcion y ruta_imagen). Por eso no rompe puesto_destacado()
--    ni puestos_tendencia().
create or replace view public.v_puestos_resumen as
select
  p.id,
  p.nombre,
  p.id_tianguis,
  t.nombre as tianguis_nombre,
  (select min(h.dia_semana) from public.tianguis_horarios h
    where h.id_tianguis = p.id_tianguis) as dia_semana,
  cat.id as id_categoria,
  cat.nombre as categoria_nombre,
  coalesce(nullif(p.descripcion, ''), nullif(pv.descripcion, ''), pv.nombre_negocio) as descripcion,
  (select round(avg(k.puntuacion)::numeric, 1) from public.calificaciones k
    where k.id_puesto = p.id and not k.moderado) as promedio,
  (select count(*) from public.calificaciones k
    where k.id_puesto = p.id and not k.moderado) as calificaciones,
  (select count(*) from public.favoritos f where f.id_puesto = p.id) as guardados,
  (p.estado = 'abierto') as abierto,
  coalesce(
    p.foto_ruta,
    (select i.ruta_storage
       from public.productos pr
       join public.producto_imagenes i on i.id_producto = pr.id
      where pr.id_puesto = p.id and pr.activo and not pr.moderado
      order by i.orden, pr.creado_en
      limit 1)
  ) as ruta_imagen,
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
