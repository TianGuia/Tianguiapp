import '../config/supabase_config.dart';

/// Resolver puro: no inicializa ni consulta Supabase al leer un modelo.
String urlImagenProducto(String ruta) =>
    '${SupabaseConfig.url.replaceFirst(RegExp(r'/+$'), '')}/storage/v1/object/public/'
    '${SupabaseConfig.bucketProductos}/${ruta.split('/').map(Uri.encodeComponent).join('/')}';
