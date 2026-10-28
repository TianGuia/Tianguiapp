import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/enums.dart';
import '../services/chat_service.dart';

/// Valores de `reportes.tipo_objetivo` (ver lib/config/enums.dart).
class TipoReporte {
  static const perfil = Enums.repPerfil;
  static const producto = Enums.repProducto;
  static const anuncioEspacio = Enums.repAnuncioEspacio;
  static const mensaje = Enums.repMensaje;
  static const calificacion = Enums.repCalificacion;
}

/// RF-44: pide un motivo y registra el reporte.
Future<void> reportarContenido(
  BuildContext context, {
  required String tipoObjetivo,
  required String idObjetivo,
  String? idUsuarioReportado,
}) async {
  final motivo = TextEditingController();
  final enviar = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Reportar'),
      content: TextField(
        controller: motivo,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: '¿Qué pasó? (falso, abusivo, incorrecto…)',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
      ],
    ),
  );
  if (enviar != true || motivo.text.trim().isEmpty) return;
  try {
    await ChatService().reportar(
      tipoObjetivo: tipoObjetivo,
      idObjetivo: idObjetivo,
      idUsuarioReportado: idUsuarioReportado,
      motivo: motivo.text.trim(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias, revisaremos tu reporte')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo reportar: $e')));
    }
  }
}

/// RF-38: confirmación antes de bloquear.
Future<bool?> confirmarBloqueo(BuildContext context, String nombre) => showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Bloquear usuario?'),
        content: Text('Ya no podrán intercambiar mensajes con "$nombre" mientras el bloqueo siga activo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bloquear')),
        ],
      ),
    );

/// RF-46: solicitud de revisión de una medida, reporte o calificación.
/// Pasa exactamente uno de [idMedida], [idReporte] o [idCalificacion].
/// Devuelve true si la solicitud se registró.
Future<bool> solicitarRevision(
  BuildContext context, {
  String? idMedida,
  String? idReporte,
  String? idCalificacion,
}) async {
  final motivo = TextEditingController();
  final enviar = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Solicitar revisión'),
      content: TextField(
        controller: motivo,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(hintText: 'Cuéntanos por qué debería revisarse'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enviar')),
      ],
    ),
  );
  if (enviar != true || motivo.text.trim().isEmpty) return false;
  try {
    final db = Supabase.instance.client;
    await db.from('apelaciones').insert({
      'id_usuario': db.auth.currentUser!.id,
      'id_medida': idMedida,
      'id_reporte': idReporte,
      'id_calificacion': idCalificacion,
      'motivo': motivo.text.trim(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada. Un administrador la revisará')));
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
    }
    return false;
  }
}
