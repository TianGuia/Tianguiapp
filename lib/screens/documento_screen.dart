import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/urbano.dart';

// muestra las condiciones de uso o el aviso de privacidad vigentes
// tipo puede ser terminos o privacidad
// RF-40 se cumple aqui: la persona puede leer las condiciones antes de aceptarlas
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
    // sin sesion la tabla no se puede leer, se usa documento_vigente
    // y si no existe en la base se intenta la consulta directa
    try {
      final r = await db.rpc('documento_vigente', params: {'p_tipo': widget.tipo});
      final l = r is List ? r : (r == null ? const [] : [r]);
      if (l.isNotEmpty) return Map<String, dynamic>.from(l.first as Map);
    } catch (_) {} // si falla se intenta la otra consulta
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
  Widget build(BuildContext context) => ScaffoldTg(
          appBar: AppBar(title: Text(widget.titulo)),
          body: FutureBuilder<Map<String, dynamic>?>(
            future: _futuro,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) return const CargandoTg();
              final d = s.data;
              if (s.hasError || d == null) {
                return const EstadoVacio(
                  icono: Icons.cloud_off,
                  color: Tg.rosa,
                  titulo: 'No se pudo cargar',
                  mensaje: 'No se pudo cargar el documento. Revisa tu conexión e inténtalo de nuevo.',
                );
              }
              return SafeArea(
                child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  CabeceraTg(
                    titulo: widget.titulo,
                    subtitulo: 'Versión ${d['version']}',
                    icono: widget.tipo == 'privacidad' ? Icons.privacy_tip : Icons.description,
                  ),
                  TarjetaTg(
                    padding: const EdgeInsets.all(18),
                    child: Text('${d['contenido']}', style: const TextStyle(fontSize: 15, height: 1.4)),
                  ),
                ]),
              );
            },
          ),
      );
}
