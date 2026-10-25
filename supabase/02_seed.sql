-- Datos de prueba (opcionales)
insert into categorias (nombre) values ('Chacharas'),('Comida'),('Frutas'),('Ropa'),('Servicios')
on conflict (nombre) do nothing;

insert into etiquetas_valoracion (nombre) values ('Buen trato'),('Precio justo'),('Producto como se describe'),('Puntual')
on conflict (nombre) do nothing;

insert into tianguis (nombre, direccion, latitud, longitud) values
 ('El Niño 1', 'Zapopan, Jalisco', 20.7200, -103.3900),
 ('Jalua', 'Zapopan, Jalisco', 20.6900, -103.4000);

-- Texto de términos (ajusta 'tipo' a un valor real de tu enum tipo_documento)
-- insert into versiones_documento (tipo, version, contenido) values ('terminos','1.0','Condiciones de uso…');
