import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/theme.dart';
import '../widgets/entradas.dart';
import '../widgets/mensaje.dart';
import '../widgets/pincel.dart';
import '../widgets/urbano.dart';

// la persona avisa que algo de la app no funciona o se ve mal
// se guarda en la tabla reportes_falla (ver docs/sql-valoraciones-y-fallas.sql)
class ReportarFallaScreen extends StatefulWidget {
  const ReportarFallaScreen({super.key});
  @override
  State<ReportarFallaScreen> createState() => _ReportarFallaScreenState();
}

class _ReportarFallaScreenState extends State<ReportarFallaScreen> {
  static const _tipos = <String, String>{
    'no_funciona': 'Algo no funciona',
    'se_traba': 'Se traba o se cierra',
    'se_ve_mal': 'Se ve mal',
    'sugerencia': 'Tengo una idea',
    'otra': 'Otra cosa',
  };

  final _db = Supabase.instance.client;
  final _texto = TextEditingController();
  String _tipo = 'no_funciona';
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.length < 10) {
      mostrarMensaje(context, 'Cuéntanos un poco más, mínimo 10 letras');
      return;
    }
    setState(() => _enviando = true);
    try {
      await _db.from('reportes_falla').insert({
        'id_usuario': _db.auth.currentUser!.id,
        'tipo': _tipo,
        'descripcion': t,
        'plataforma': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });
      if (!mounted) return;
      mostrarMensaje(context, '¡Gracias! Ya recibimos tu aviso');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        mostrarMensaje(context, 'No se pudo enviar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ScaffoldTg(
        appBar: AppBar(title: const Text('Reportar una falla')),
        body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          const CabeceraTg(
            titulo: '¿Algo falló?',
            subtitulo: 'Tu aviso nos ayuda a mejorar',
            icono: Icons.bug_report,
            color: Tg.rosa,
          ),
          const SeccionTg('¿Qué pasó?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _tipos.entries)
                FichaTg(texto: e.value, elegida: _tipo == e.key, onCambio: (_) => setState(() => _tipo = e.key)),
            ]),
          ),
          const SeccionTg('Cuéntanos'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _texto,
              maxLines: 6,
              minLines: 4,
              inputFormatters: Entradas.texto(500),
              style: const TextStyle(color: Colors.black, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Dónde estabas, qué tocaste y qué esperabas que pasara',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Text('No pongas contraseñas ni datos personales.',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: BotonPincel(
              texto: 'ENVIAR AVISO',
              icono: Icons.send_rounded,
              cargando: _enviando,
              onPressed: _enviar,
            ),
          ),
        ]),
      );
}
