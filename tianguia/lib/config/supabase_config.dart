/// Datos públicos de tu proyecto (Dashboard > Project Settings > API).
/// Se pasan al compilar para no dejarlos en el repositorio:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=tu_publishable_key
/// NUNCA pongas aquí la clave service_role / secret.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_KEY');
  static const bucketProductos = 'productos';
  static const bucketPerfiles = 'perfiles';
}
