// Este archivo ya no contiene clases: solo las reúne en un mismo lugar.
//
// Antes, las 11 clases del diagrama vivían aquí, todas juntas. Ahora cada una
// tiene su propio archivo dentro de la carpeta de su módulo (inicio_sesion,
// comprador, vendedor, comunes). Se deja este archivo para que las pantallas
// que ya hacen `import '../models/entidades.dart'` sigan funcionando igual.
//
// Para ver una clase, busca su archivo en lib/models/<módulo>/.

export 'inicio_sesion/usuario.dart';
export 'comprador/comprador.dart';
export 'comprador/visita.dart';
export 'comprador/calificacion.dart';
export 'vendedor/vendedor.dart';
export 'vendedor/vendedor_tianguis.dart';
export 'comunes/conversacion.dart';
export 'comunes/mensaje.dart';
export 'comunes/participante.dart';
export 'comunes/reporte.dart';
export 'comunes/apelacion.dart';
