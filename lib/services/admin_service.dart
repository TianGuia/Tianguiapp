import 'package:supabase_flutter/supabase_flutter.dart';

/// RF-47 a RF-54: operaciones del administrador. Los permisos los aplica la
/// base de datos (es_admin() en las políticas RLS), no la app.
class AdminService {
  final _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  static String _limpia(String t) => t.trim().replaceAll(RegExp(r'[,()%*]'), ' ');

  Future<Map<String, String>> _nombres(Iterable<dynamic> ids) async {
    final l = ids.whereType<String>().toSet().toList();
    if (l.isEmpty) return {};
    final r = await _db.from('usuarios').select('id, nombre_publico').inFilter('id', l);
    return {for (final u in r) u['id'] as String: (u['nombre_publico'] ?? '') as String};
  }

  // ---------------- RF-50: reportes ----------------

  Future<List<Map<String, dynamic>>> reportes({bool soloPendientes = true}) async {
    final base = _db.from('reportes').select();
    final r = await (soloPendientes ? base.neq('estado', 'resuelto') : base)
        .order('creado_en', ascending: false)
        .limit(100);
    final nombres = await _nombres(
        [for (final x in r) ...[x['id_reportante'], x['id_usuario_reportado']]]);
    final contenidos = await Future.wait([
      for (final x in r) _contenidoReportado('${x['tipo_objetivo']}', '${x['id_objetivo']}')
    ]);
    return [
      for (var i = 0; i < r.length; i++)
        {
          ...r[i],
          'reportante_nombre': nombres[r[i]['id_reportante']] ?? '—',
          'reportado_nombre': nombres[r[i]['id_usuario_reportado']] ?? '—',
          'contenido': contenidos[i],
        }
    ];
  }

  /// Texto de lo que se reportó, para que el administrador decida con contexto.
  Future<String> _contenidoReportado(String tipo, String id) async {
    String unir(List<Object?> partes) =>
        partes.where((p) => p != null && '$p'.trim().isNotEmpty).join(' · ');
    try {
      switch (tipo) {
        case 'producto':
          {
            final p = await _db
                .from('productos')
                .select('nombre, descripcion, precio_referencia')
                .eq('id', id)
                .maybeSingle();
            if (p == null) return 'El producto ya no existe';
            return unir([
              p['nombre'],
              p['precio_referencia'] == null ? null : '\$${p['precio_referencia']}',
              p['descripcion']
            ]);
          }
        case 'mensaje':
          {
            final m = await _db.from('mensajes').select('contenido').eq('id', id).maybeSingle();
            return m == null ? 'El mensaje ya no existe' : '"${m['contenido']}"';
          }
        case 'calificacion':
          {
            final c = await _db
                .from('calificaciones')
                .select('puntuacion, comentario')
                .eq('id', id)
                .maybeSingle();
            if (c == null) return 'La calificación ya no existe';
            return unir(['${c['puntuacion']} de 5', c['comentario']]);
          }
        case 'anuncio_espacio':
          {
            final a = await _db
                .from('anuncios_espacio')
                .select('titulo, descripcion')
                .eq('id', id)
                .maybeSingle();
            return a == null ? 'El anuncio ya no existe' : unir([a['titulo'], a['descripcion']]);
          }
        case 'perfil':
          {
            final u = await _db
                .from('usuarios')
                .select('nombre_publico, correo')
                .eq('id', id)
                .maybeSingle();
            return u == null ? 'El perfil ya no existe' : unir([u['nombre_publico'], u['correo']]);
          }
      }
    } catch (_) {
      return 'No se pudo cargar el contenido';
    }
    return '';
  }

  /// [medida]: advertencia | ocultar_contenido | retirar_contenido |
  /// suspender_cuenta, o null para mantener el contenido sin medida.
  Future<void> resolverReporte(Map<String, dynamic> reporte,
      {String? medida, required String decision}) async {
    if (medida != null) {
      final afectado = reporte['id_usuario_reportado'];
      if (afectado == null) {
        throw 'Este reporte no tiene un usuario asociado para aplicar una medida';
      }
      await _db.from('medidas_moderacion').insert({
        'id_reporte': reporte['id'],
        'id_usuario_afectado': afectado,
        'tipo_medida': medida,
        'tipo_objetivo': reporte['tipo_objetivo'],
        'id_objetivo': reporte['id_objetivo'],
        'motivo_general': decision,
        'id_admin': _uid,
      });
    }
    await _db.from('reportes').update({
      'estado': 'resuelto',
      'decision': decision,
      'id_admin': _uid,
      'resuelto_en': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reporte['id']);
  }

  // ---------------- RF-51: apelaciones ----------------

  Future<List<Map<String, dynamic>>> apelaciones({bool soloPendientes = true}) async {
    final base = _db.from('apelaciones').select();
    final r = await (soloPendientes ? base.eq('estado', 'pendiente') : base)
        .order('creada_en', ascending: false)
        .limit(100);
    final nombres = await _nombres([for (final x in r) x['id_usuario']]);
    return [for (final x in r) {...x, 'usuario_nombre': nombres[x['id_usuario']] ?? '—'}];
  }

  /// [resolucion]: mantenida | modificada | revertida. Si se revierte una
  /// medida, se desactiva (el trigger de la base restaura contenido/cuenta).
  Future<void> resolverApelacion(Map<String, dynamic> apelacion,
      {required String resolucion, required String comentario}) async {
    await _db.from('apelaciones').update({
      'estado': 'resuelta',
      'resolucion': resolucion,
      'comentario_resolucion': comentario,
      'id_admin': _uid,
      'resuelta_en': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', apelacion['id']);
    if (resolucion == 'revertida' && apelacion['id_medida'] != null) {
      await _db
          .from('medidas_moderacion')
          .update({'activa': false}).eq('id', apelacion['id_medida']);
    }
  }

  // ---------------- RF-47, RF-48, RF-49: tianguis ----------------

  Future<List<Map<String, dynamic>>> tianguis() async =>
      List<Map<String, dynamic>>.from(await _db.from('tianguis').select().order('nombre'));

  /// Crea (id == null) o modifica un tianguis. Devuelve su id.
  Future<String> guardarTianguis(String? id, Map<String, dynamic> datos) async {
    if (id == null) {
      final r = await _db.from('tianguis').insert(datos).select('id').single();
      return r['id'] as String;
    }
    await _db.from('tianguis').update(datos).eq('id', id);
    return id;
  }

  Future<List<Map<String, dynamic>>> horarios(String idTianguis) async =>
      List<Map<String, dynamic>>.from(await _db
          .from('tianguis_horarios')
          .select()
          .eq('id_tianguis', idTianguis)
          .order('dia_semana'));

  Future<void> agregarHorario(String idTianguis, int dia, String inicio, String fin) =>
      _db.from('tianguis_horarios').insert({
        'id_tianguis': idTianguis,
        'dia_semana': dia,
        'hora_inicio': inicio,
        'hora_fin': fin,
      });

  Future<void> eliminarHorario(String id) =>
      _db.from('tianguis_horarios').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> zonas(String idTianguis) async =>
      List<Map<String, dynamic>>.from(await _db
          .from('tianguis_zonas')
          .select()
          .eq('id_tianguis', idTianguis)
          .order('orden'));

  Future<void> agregarZona(String idTianguis, String nombre, String tipo,
          {Object? geometria, int orden = 0}) =>
      _db.from('tianguis_zonas').insert({
        'id_tianguis': idTianguis,
        'nombre': nombre,
        'tipo': tipo,
        'geometria': geometria,
        'orden': orden,
      });

  Future<void> eliminarZona(String id) => _db.from('tianguis_zonas').delete().eq('id', id);

  // ---------------- RF-52: términos y privacidad ----------------

  Future<List<Map<String, dynamic>>> versiones() async =>
      List<Map<String, dynamic>>.from(await _db
          .from('versiones_documento')
          .select('id, tipo, version, vigente, requiere_reaceptacion, publicado_en')
          .order('publicado_en', ascending: false));

  /// Publica una versión nueva y deja como no vigentes las anteriores del
  /// mismo tipo. Si falla la publicación, restaura las anteriores.
  Future<void> publicarVersion({
    required String tipo,
    required String version,
    required String contenido,
    required bool requiereReaceptacion,
  }) async {
    final previas = await _db
        .from('versiones_documento')
        .select('id')
        .eq('tipo', tipo)
        .eq('vigente', true);
    final ids = [for (final p in previas) p['id'] as String];
    if (ids.isNotEmpty) {
      await _db.from('versiones_documento').update({'vigente': false}).inFilter('id', ids);
    }
    try {
      await _db.from('versiones_documento').insert({
        'tipo': tipo,
        'version': version,
        'contenido': contenido,
        'requiere_reaceptacion': requiereReaceptacion,
        'vigente': true,
        'publicado_por': _uid,
      });
    } catch (_) {
      if (ids.isNotEmpty) {
        await _db.from('versiones_documento').update({'vigente': true}).inFilter('id', ids);
      }
      rethrow;
    }
  }

  // ---------------- RF-54: consulta ----------------

  /// [entidad]: usuarios | vendedores | productos | puestos.
  Future<List<Map<String, dynamic>>> consultar(String entidad, String texto) async {
    final t = _limpia(texto);
    const moderables = {
      'calificaciones': 'calificacion',
      'anuncios': 'anuncio_espacio',
      'ofertas': 'oferta',
    };
    if (moderables.containsKey(entidad)) {
      final m = await _db.rpc('admin_buscar_moderable',
          params: {'p_tipo': moderables[entidad], 'p_texto': t});
      return [for (final x in (m as List)) Map<String, dynamic>.from(x as Map)];
    }
    final List r;
    switch (entidad) {
      case 'usuarios':
      {
        var q = _db.from('usuarios').select('id, nombre_publico, correo, estado_cuenta, creado_en');
        if (t.isNotEmpty) q = q.or('nombre_publico.ilike.%$t%,correo.ilike.%$t%');
        r = await q.order('creado_en', ascending: false).limit(60);
      }
      case 'vendedores':
      {
        var q = _db
            .from('perfiles_vendedor')
            .select('id, nombre_negocio, id_usuario, estado, usuarios(nombre_publico, correo, estado_cuenta)');
        if (t.isNotEmpty) q = q.ilike('nombre_negocio', '%$t%');
        r = await q.limit(60);
      }
      case 'productos':
      {
        var q = _db
            .from('productos')
            .select('id, nombre, precio_referencia, activo, moderado, puestos!productos_id_puesto_fkey(nombre)');
        if (t.isNotEmpty) q = q.ilike('nombre', '%$t%');
        r = await q.order('creado_en', ascending: false).limit(60);
      }
      case 'puestos':
      {
        // puestos no tiene llave foránea directa a tianguis (apunta a
        // vendedor_tianguis), así que no se puede incrustar tianguis(...).
        // Se piden los nombres aparte y se pegan a cada fila.
        var q = _db.from('puestos').select('id, nombre, estado, activo, id_tianguis');
        if (t.isNotEmpty) q = q.ilike('nombre', '%$t%');
        final ps = await q.limit(60);
        final ids = {for (final p in ps) p['id_tianguis']}.whereType<String>().toList();
        final nombres = <String, String>{};
        if (ids.isNotEmpty) {
          final ts = await _db.from('tianguis').select('id, nombre').inFilter('id', ids);
          for (final x in ts) {
            nombres[x['id'] as String] = (x['nombre'] ?? '') as String;
          }
        }
        r = [
          for (final p in ps) {...p, 'tianguis': {'nombre': nombres[p['id_tianguis']] ?? ''}}
        ];
      }
      default:
        r = const [];
    }
    final lista = List<Map<String, dynamic>>.from(r);
    const tipos = {'vendedores': 'vendedor', 'productos': 'producto', 'puestos': 'puesto'};
    final tipo = tipos[entidad];
    return tipo == null ? lista : _conMedidas(tipo, lista);
  }

  /// Agrega 'medida_id' a las filas que tienen una medida de ocultar/retirar
  /// activa (de un reporte o directa), para poder levantarla desde la lista.
  Future<List<Map<String, dynamic>>> _conMedidas(
      String tipoObjetivo, List<Map<String, dynamic>> filas) async {
    final ms = await medidasActivas();
    final porObjetivo = {
      for (final m in ms)
        if (m['tipo_objetivo'] == tipoObjetivo &&
            (m['tipo_medida'] == 'ocultar_contenido' || m['tipo_medida'] == 'retirar_contenido'))
          '${m['id_objetivo']}': m['id'] as String
    };
    return [for (final f in filas) {...f, 'medida_id': porObjetivo['${f['id']}']}];
  }

  /// Categorías ('categorias') o etiquetas de valoración ('etiquetas').
  Future<List<Map<String, dynamic>>> catalogo(String tabla) async {
    final r = await _db.rpc('admin_catalogo_listar', params: {'p_tabla': tabla});
    return [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];
  }

  /// Crea ([id] nulo) o edita una categoría/etiqueta; [activa] false la desactiva.
  Future<void> guardarCatalogo(String tabla,
          {String? id, required String nombre, bool activa = true}) =>
      _db.rpc('admin_catalogo_guardar',
          params: {'p_tabla': tabla, 'p_id': id, 'p_nombre': nombre, 'p_activa': activa});

  // ---------------- administradores por clave ----------------

  Future<List<Map<String, dynamic>>> administradores() async {
    final r = await _db.rpc('admin_lista_admins');
    return [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];
  }

  Future<List<Map<String, dynamic>>> bitacoraAdmins() async {
    final r = await _db.rpc('admin_bitacora_listar');
    return [for (final x in (r as List)) Map<String, dynamic>.from(x as Map)];
  }

  /// Alta o cambio de clave. [miClave]/[miRespuesta] son las de quien lo hace.
  Future<void> guardarAdministrador(
          {required String nombre,
          required String clave,
          required String respuesta,
          required String miClave,
          required String miRespuesta}) =>
      _db.rpc('admin_guardar_admin', params: {
        'p_nombre': nombre,
        'p_clave': clave,
        'p_respuesta': respuesta,
        'p_mi_clave': miClave,
        'p_mi_respuesta': miRespuesta,
      });

  Future<void> quitarAdministrador(String nombre,
          {required String miClave, required String miRespuesta}) =>
      _db.rpc('admin_quitar_admin',
          params: {'p_nombre': nombre, 'p_mi_clave': miClave, 'p_mi_respuesta': miRespuesta});

  /// Números para el resumen del panel (función admin_resumen).
  Future<Map<String, int>> resumen() async {
    final r = await _db.rpc('admin_resumen');
    return {for (final e in (r as Map).entries) '${e.key}': (e.value as num).toInt()};
  }

  /// Medidas de moderación vigentes, más recientes primero.
  Future<List<Map<String, dynamic>>> medidasActivas() async {
    final r = await _db.rpc('admin_medidas_activas');
    return [for (final m in (r as List)) Map<String, dynamic>.from(m as Map)];
  }

  /// Moderación directa, sin reporte. [tipoObjetivo]: puesto | producto |
  /// vendedor | anuncio_espacio | calificacion | mensaje. La función de la base
  /// calcula a quién afecta, aplica el efecto y le avisa al usuario (RF-45).
  Future<void> aplicarMedida(
          {required String tipoObjetivo,
          required String id,
          required String motivo,
          String tipoMedida = 'ocultar_contenido'}) =>
      _db.rpc('admin_aplicar_medida', params: {
        'p_tipo_objetivo': tipoObjetivo,
        'p_id': id,
        'p_tipo_medida': tipoMedida,
        'p_motivo': motivo,
      });

  /// Levanta una medida activa, revierte su efecto y avisa al usuario.
  Future<void> levantarMedida(String idMedida, String motivo) =>
      _db.rpc('admin_levantar_medida', params: {'p_id': idMedida, 'p_motivo': motivo});

  /// activa | suspendida
  Future<void> cambiarEstadoCuenta(String idUsuario, String estado) =>
      _db.rpc('admin_cambiar_estado_cuenta', params: {'p_id': idUsuario, 'p_estado': estado});
}
