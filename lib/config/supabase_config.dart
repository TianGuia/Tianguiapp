class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ijnvztoyhizdwtzagrvy.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_C4i-Lm08t35unAMETI36uw_0pH9hSc1',
  );
  static const bucketProductos = 'productos';
  static const bucketPerfiles = 'perfiles';
}