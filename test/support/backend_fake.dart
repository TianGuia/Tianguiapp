import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const usuarioId = '10000000-0000-0000-0000-000000000001';
const vendedorId = '20000000-0000-0000-0000-000000000001';
const puestoId = '30000000-0000-0000-0000-000000000001';
const productoId = '40000000-0000-0000-0000-000000000001';
const fecha = '2026-01-01T12:00:00Z';

Map<String, dynamic> usuarioFila() => {
      'id': usuarioId,
      'nombre_publico': 'Persona',
      'estado_cuenta': 'activa',
      'creado_en': fecha,
      'correo': null,
      'telefono': null,
      'foto_url': null,
    };
Map<String, dynamic> vendedorFila() => {
      'id': vendedorId,
      'id_usuario': usuarioId,
      'estado': 'activo',
      'fecha_habilitacion': fecha,
      'descripcion': 'Catálogo',
      'usuarios': usuarioFila(),
    };
Map<String, dynamic> puestoFila() => {
      'id': puestoId,
      'id_vendedor': vendedorId,
      'id_tianguis': 'tianguis',
      'nombre': 'Puesto',
      'estado': 'cerrado',
      'activo': true,
    };
Map<String, dynamic> productoFila({String id = productoId}) => {
      'id': id,
      'id_vendedor': vendedorId,
      'id_puesto': puestoId,
      'nombre': 'Producto $id',
      'estado_articulo': 'nuevo',
      'precio_referencia': 100,
      'cantidad_disponible': 5,
      'disponible': true,
      'producto_imagenes': <dynamic>[],
    };
Map<String, dynamic> ofertaFila(
        {String id = 'oferta', String producto = productoId}) =>
    {
      'id': id,
      'id_producto': producto,
      'estado': 'activa',
      'titulo': 'Oferta',
      'fecha_inicio': fecha,
      'fecha_fin': '2099-01-01T12:00:00Z',
      'descuento': 20,
      'productos': {'nombre': 'Producto $producto', 'precio_referencia': 100},
    };
Map<String, dynamic> apartadoFila() => {
      'id': 'apartado',
      'id_producto': productoId,
      'id_comprador': usuarioId,
      'id_vendedor': vendedorId,
      'estado': 'pendiente',
      'cantidad': 1,
      'fecha_inicio': fecha,
      'fecha_expiracion': '2099-01-01T12:00:00Z',
      'comprador': {
        'usuarios': {'nombre_publico': 'Persona'}
      },
    };
Map<String, dynamic> conversacionFila(
        {DateTime? ultimo, String estado = 'activa'}) =>
    {
      'id': 'conversacion',
      'creada_en': fecha,
      'estado': estado,
      'ultimo_mensaje_en': ultimo?.toIso8601String(),
      'participantes': [
        for (final id in [usuarioId, 'segunda-persona', 'tercera-persona'])
          {'id_conversacion': 'conversacion', 'id_usuario': id},
      ],
    };

http.Response jsonResponse(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

/// Todo transporte inesperado falla; jamás consulta un proyecto real.
class BackendFake {
  late final SupabaseClient client;
  final List<http.Request> requests = [];
  final FutureOr<http.Response> Function(http.Request) handle;
  BackendFake(this.handle) {
    client = SupabaseClient('https://supabase.example.test', 'synthetic-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
      if (r.url.path == '/auth/v1/token' ||
          r.url.path == '/auth/v1/signup' ||
          r.url.path == '/auth/v1/verify') {
        final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        final claims = base64Url
            .encode(utf8.encode(jsonEncode({'sub': usuarioId, 'exp': exp})))
            .replaceAll('=', '');
        return jsonResponse({
          'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.signature',
          'refresh_token': 'synthetic-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': usuarioId,
            'aud': 'authenticated',
            'created_at': fecha,
            'app_metadata': {},
            'user_metadata': {}
          },
        });
      }
      requests.add(r);
      final response = await handle(r);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: r);
    }));
  }
  Future<void> login() async {
    await client.auth.signInWithPassword(
        email: 'persona@example.test', password: 'synthetic');
  }

  Future<void> dispose() => client.dispose();
}

Never unexpected(http.Request r) =>
    fail('Petición inesperada: ${r.method} ${r.url}');

/// Crear el isolate JSON fuera del reloj simulado de testWidgets permite
/// inicializarlo y cerrarlo sin dejar trabajo pendiente en FakeAsync.
Future<BackendFake> crearBackendWidget(
        FutureOr<http.Response> Function(http.Request) handle) async =>
    (await TestWidgetsFlutterBinding.instance
        .runAsync(() async => BackendFake(handle)))!;
