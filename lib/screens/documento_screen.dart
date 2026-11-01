import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/fondo.dart';

/// Muestra la versión vigente de las condiciones de uso o del aviso de
/// privacidad, para que la persona pueda leerlas antes de aceptarlas (RF-40).
/// [tipo] = 'terminos' | 'privacidad' (enum tipo_documento).
class DocumentoScreen extends StatefulWidget {
  final String tipo;
  final String titulo;
  const DocumentoScreen({super.key, required this.tipo, required this.titulo});

  @override
  State<DocumentoScreen> createState() => _DocumentoScreenState();
}

class _DocumentoScreenState extends State<DocumentoScreen> {
  late final Future<Map<String, dynamic>?> _futuro = _cargar();

  Future<Map<String, dynamic>?> _cargar() async {
    final db = Supabase.instance.client;
    // Sin sesión (pantalla de registro) la tabla no es legible: se usa la función
    // documento_vigente. Si aún no existe en la base, se intenta la consulta directa.
    try {
      final r = await db.rpc('documento_vigente', params: {'p_tipo': widget.tipo});
      final l = r is List ? r : (r == null ? const [] : [r]);
      if (l.isNotEmpty) return Map<String, dynamic>.from(l.first as Map);
    } catch (_) {}
    final r = await db
        .from('versiones_documento')
        .select('version, contenido, publicado_en')
        .eq('tipo', widget.tipo)
        .eq('vigente', true)
        .order('publicado_en', ascending: false)
        .limit(1);
    final l = r as List;
    return l.isEmpty ? null : Map<String, dynamic>.from(l.first as Map);
  }

  @override
  Widget build(BuildContext context) => Fondo(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(widget.titulo)),
          body: FutureBuilder<Map<String, dynamic>?>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: Tg.amarillo));
              }
              final d = s.data;
              if (s.hasError || d == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar el documento. Revisa tu conexión e inténtalo de nuevo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return SafeArea(
                child: ListView(padding: const EdgeInsets.all(18), children: [
                  Text('Versión ${d['version']}',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text('${d['contenido']}', style: const TextStyle(fontSize: 15, height: 1.4)),
                ]),
              );
            },
          ),
        ),
      );
}
