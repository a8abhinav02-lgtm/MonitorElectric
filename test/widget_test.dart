import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:termo_trafo/main.dart';
import 'package:termo_trafo/views/asset_form_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('TermoTrafoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TermoTrafoApp(),
      ),
    );
    // Pump frames to render UI without hanging on infinite animations
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('TERMO-TRAFO SCADA'), findsOneWidget);
  });

  testWidgets('TermoTrafoApp resiliencia ante fuente del sistema ampliada (Accesibilidad)', (WidgetTester tester) async {
    // Simular pantalla de smartphone de 6 pulgadas (~392 x 800 dp)
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;

    await tester.pumpWidget(
      const ProviderScope(
        child: TermoTrafoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('TERMO-TRAFO SCADA'), findsOneWidget);

    // Restaurar tamaño físico del tester
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  });

  testWidgets('TermoTrafoApp expansión de tarjeta sin desbordamientos RenderFlex en 360dp', (WidgetTester tester) async {
    // Pantalla estrecha de 360 x 800 dp
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 1080 / 3.0 = 360 dp

    await tester.pumpWidget(
      const ProviderScope(
        child: TermoTrafoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Buscar una tarjeta de activo y hacer tap para expandirla
    final cardFinder = find.byType(Card);
    if (cardFinder.evaluate().isNotEmpty) {
      await tester.tap(cardFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('TERMO-TRAFO SCADA'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  });

  testWidgets('AssetFormScreen para Interruptor no produce desbordamientos en 360dp con fuente ampliada', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;

    FlutterErrorDetails? caughtDetails;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(1.4),
              size: Size(360, 640),
              padding: EdgeInsets.only(bottom: 48), // Simula barra de navegación del sistema
            ),
            child: AssetFormScreen(
              subareaId: 1,
              subareaCategory: 'CIRCUIT_BREAKER',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    FlutterError.onError = oldHandler;

    expect(caughtDetails, isNull);
    expect(find.text('REGISTRAR INTERRUPTOR'), findsOneWidget);
    expect(find.text('PUNTOS DE INSPECCIÓN (IR)'), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  });

  testWidgets('Diálogo de Normas Técnicas (?) no produce desbordamientos en 360dp con fuente ampliada', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;

    FlutterErrorDetails? caughtDetails;
    final oldHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      caughtDetails = details;
    };

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(1.4),
              size: Size(360, 640),
            ),
            child: AssetFormScreen(
              subareaId: 1,
              subareaCategory: 'CIRCUIT_BREAKER',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tocar el botón de ayuda (?) en el AppBar
    final helpButton = find.byIcon(Icons.help_outline_rounded);
    expect(helpButton, findsOneWidget);
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    FlutterError.onError = oldHandler;

    // Verificar que el diálogo se abre correctamente y no produce excepciones RenderFlex
    expect(caughtDetails, isNull);
    expect(find.text('Normas Técnicas Consideradas'), findsOneWidget);
    expect(find.text('1. Transformadores de Potencia'), findsOneWidget);
    expect(find.text('2. Interruptores BT y MT'), findsOneWidget);
    expect(find.text('3. Desbalance Térmico (ΔT Termografía)'), findsOneWidget);

    // Cerrar el diálogo
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
  });

  testWidgets('Selector desplegable de Tipo de Activo conmuta entre Transformador e Interruptor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AssetFormScreen(
            subareaId: 1,
            subareaCategory: 'TRANSFORMER',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Inicialmente es Transformador
    expect(find.text('REGISTRAR TRANSFORMADOR'), findsOneWidget);

    // Abrir dropdown y seleccionar Interruptor
    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(dropdown, findsOneWidget);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    // Tocar la opción Interruptor en el menú emergente
    await tester.tap(find.text('Interruptor').last);
    await tester.pumpAndSettle();

    // Verificar que el formulario conmutó a Interruptor
    expect(find.text('REGISTRAR INTERRUPTOR'), findsOneWidget);
    expect(find.text('NIVEL DE TENSIÓN Y NORMATIVA APLICABLE'), findsOneWidget);
  });
}
