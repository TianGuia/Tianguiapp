import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tianguia/services/auth_service.dart';

void main() {
  const userId = '10000000-0000-0000-0000-000000000001';
  late SupabaseClient client;
  late AuthService service;
  late List<http.Request> updates;
  late bool rejectUpdate;

  setUp(() async {
    updates = [];
    rejectUpdate = false;
    final transport = MockClient((request) async {
      if (request.url.path == '/auth/v1/token') {
        final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
        final claims = base64Url
            .encode(utf8.encode(jsonEncode({'sub': userId, 'exp': expiresAt})))
            .replaceAll('=', '');
        return http.Response(
          jsonEncode({
            'access_token': 'eyJhbGciOiJIUzI1NiJ9.$claims.signature',
            'refresh_token': 'synthetic-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': userId,
              'aud': 'authenticated',
              'email': 'usuario@example.test',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            },
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'PATCH' &&
          request.url.path == '/rest/v1/usuarios') {
        updates.add(request);
        final fields = jsonDecode(request.body) as Map<String, dynamic>;
        const editable = {'nombre_publico', 'telefono', 'foto_url'};
        if (rejectUpdate || fields.keys.any((key) => !editable.contains(key))) {
          return http.Response(
            jsonEncode({
              'code': '42501',
              'message': 'permission denied for table usuarios',
            }),
            403,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 204, request: request);
      }
      fail('Petición inesperada: ${request.method} ${request.url}');
    });
    client = SupabaseClient(
      'https://supabase.example.test',
      'synthetic-publishable-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    service = AuthService(client: client);
    await client.auth.signInWithPassword(
      email: 'usuario@example.test',
      password: 'synthetic-password',
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  test('actualiza el perfil propio sin enviar campos reservados', () async {
    await service.actualizarPerfil(
      nombre: 'Nuevo nombre',
      telefono: '5550000000',
      fotoUrl: 'https://example.test/foto.jpg',
    );

    expect(updates, hasLength(1));
    expect(updates.single.url.queryParameters['id'], 'eq.$userId');
    expect(jsonDecode(updates.single.body), {
      'nombre_publico': 'Nuevo nombre',
      'telefono': '5550000000',
      'foto_url': 'https://example.test/foto.jpg',
    });
  });

  test('cambiar el nombre no modifica teléfono ni fotografía', () async {
    await service.actualizarPerfil(nombre: 'Otro nombre');

    expect(jsonDecode(updates.single.body), {'nombre_publico': 'Otro nombre'});
  });

  test('propaga el rechazo del backend al editar el perfil', () async {
    rejectUpdate = true;

    await expectLater(
      service.actualizarPerfil(nombre: 'Otro nombre'),
      throwsA(isA<PostgrestException>()),
    );
  });
}
