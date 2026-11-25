import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tianguia/services/vendedor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plataformas = [
    MethodChannel('flutter.baseflow.com/geolocator'),
    MethodChannel('flutter.baseflow.com/geolocator_android'),
  ];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late SupabaseClient client;
  late VendedorService service;
  late List<http.Request> solicitudes;
  late List<String> llamadasUbicacion;
  late bool ubicacionActiva;

  setUp(() {
    solicitudes = [];
    llamadasUbicacion = [];
    ubicacionActiva = false;
    for (final canal in plataformas) {
      messenger.setMockMethodCallHandler(canal, (call) async {
        llamadasUbicacion.add(call.method);
        return switch (call.method) {
          'isLocationServiceEnabled' => ubicacionActiva,
          'checkPermission' || 'requestPermission' => 0,
          'openLocationSettings' || 'openAppSettings' => true,
          _ => throw MissingPluginException(call.method),
        };
      });
    }
    client = SupabaseClient(
      'https://vendedor.example.test',
      'synthetic-publishable-key',
      httpClient: MockClient((request) async {
        solicitudes.add(request);
        return http.Response('"jornada"', 200,
            headers: {'content-type': 'application/json'}, request: request);
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    service = VendedorService(client: client);
  });

  tearDown(() async {
    for (final canal in plataformas) {
      messenger.setMockMethodCallHandler(canal, null);
    }
    await client.dispose();
  });

  test('abrir sin ubicación omite geolocalización y envía coordenadas nulas', () async {
    expect(await service.marcarAbierto('puesto', conUbicacion: false), 'jornada');
    expect(llamadasUbicacion, isEmpty);
    final solicitud = solicitudes.single;
    expect(solicitud.url.path, '/rest/v1/rpc/abrir_puesto');
    expect(jsonDecode(solicitud.body), {
      'p_id_puesto': 'puesto',
      'p_latitud': null,
      'p_longitud': null,
      'p_precision': null,
    });
  });

  test('si el servicio está apagado, se puede informar antes de abrir', () async {
    await expectLater(
        service.marcarAbierto('puesto'), throwsA(FalloUbicacionPuesto.servicioDesactivado));
    expect(solicitudes, isEmpty);
    expect(llamadasUbicacion, ['isLocationServiceEnabled']);
  });

  test('si se deniega el permiso, el puesto sigue cerrado hasta decidir', () async {
    ubicacionActiva = true;
    await expectLater(
        service.marcarAbierto('puesto'), throwsA(FalloUbicacionPuesto.permisoDenegado));
    expect(solicitudes, isEmpty);
    expect(llamadasUbicacion, ['isLocationServiceEnabled', 'checkPermission', 'requestPermission']);
  });

  test('los accesos nativos distinguen ubicación y permisos de la app', () async {
    expect(await FalloUbicacionPuesto.servicioDesactivado.abrirAjustes(), isTrue);
    expect(await FalloUbicacionPuesto.permisoDenegado.abrirAjustes(), isTrue);
    expect(llamadasUbicacion, ['openLocationSettings', 'openAppSettings']);
  });
}
