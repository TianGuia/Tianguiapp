import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguia/screens/chats_screen.dart';
import 'package:tianguia/screens/mis_productos_screen.dart';
import 'package:tianguia/screens/ofertas_screen.dart';
import 'package:tianguia/services/catalogo_service.dart';
import 'package:tianguia/services/chat_service.dart';
import 'package:tianguia/services/vendedor_service.dart';
import '../support/backend_fake.dart';

void main() {
  late BackendFake backend;
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(backend.dispose);
  });

  testWidgets('sin puestos, explica el requisito e impide guardar productos',
      (tester) async {
    backend = await crearBackendWidget((r) {
      if (r.url.path.endsWith('/categorias') ||
          r.url.path.endsWith('/puestos')) {
        return jsonResponse([]);
      }
      return unexpected(r);
    });
    await backend.login();
    await tester.pumpWidget(MaterialApp(
        home: ProductoFormScreen(
            idVendedor: vendedorId,
            vendedorService: VendedorService(client: backend.client),
            catalogoService: CatalogoService(client: backend.client))));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Crea un puesto desde Mi puesto antes de guardar un producto.'),
        findsOneWidget);
    await tester.scrollUntilVisible(find.text('GUARDAR PRODUCTO'), 200,
        scrollable: find.byType(Scrollable).first);
    final guardar = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'GUARDAR PRODUCTO'));
    expect(guardar.onPressed, isNull);
    expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets(
      'guardar requiere elegir un puesto aunque existan puestos activos',
      (tester) async {
    backend = await crearBackendWidget((r) {
      if (r.url.path.endsWith('/categorias')) return jsonResponse([]);
      if (r.url.path.endsWith('/puestos')) return jsonResponse([puestoFila()]);
      return unexpected(r);
    });
    await backend.login();
    await tester.pumpWidget(MaterialApp(
        home: ProductoFormScreen(
            idVendedor: vendedorId,
            vendedorService: VendedorService(client: backend.client),
            catalogoService: CatalogoService(client: backend.client))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Camisa');
    final guardar = find.widgetWithText(FilledButton, 'GUARDAR PRODUCTO');
    await tester.scrollUntilVisible(find.text('GUARDAR PRODUCTO'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(guardar);
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un puesto activo para el producto'),
        findsOneWidget);
    expect(backend.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('lista una tarjeta por oferta individual', (tester) async {
    backend = await crearBackendWidget((r) => r.url.path.endsWith('/ofertas')
        ? jsonResponse(
            [ofertaFila(), ofertaFila(id: 'oferta2', producto: 'producto2')])
        : unexpected(r));
    await tester.pumpWidget(MaterialApp(
        home: OfertasScreen(
            idVendedor: vendedorId,
            service: VendedorService(client: backend.client))));
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.textContaining('Producto producto2'), findsOneWidget);
  });

  testWidgets('lista chats sin contexto con tres participantes',
      (tester) async {
    backend = await crearBackendWidget((r) {
      if (r.url.path.endsWith('/participantes')) {
        return jsonResponse([
          {'id_conversacion': 'conversacion'}
        ]);
      }
      if (r.url.path.endsWith('/conversaciones')) {
        return jsonResponse([conversacionFila()]);
      }
      if (r.url.path.endsWith('/conversaciones_ocultas')) {
        return jsonResponse([]);
      }
      return unexpected(r);
    });
    await backend.login();
    await tester.pumpWidget(MaterialApp(
        home: ChatsScreen(service: ChatService(client: backend.client))));
    await tester.pumpAndSettle();
    expect(find.text('Conversación'), findsOneWidget);
    expect(find.text('3 participantes · activa'), findsOneWidget);
  });
}
