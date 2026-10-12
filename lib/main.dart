import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'views/plants_overview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Forzar operación estrictamente en modo vertical (Portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    const ProviderScope(
      child: TermoTrafoApp(),
    ),
  );
}

class TermoTrafoApp extends StatelessWidget {
  const TermoTrafoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Termo-Trafo SCADA',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Normalización inteligente: acotar el factor de escala de texto entre 0.85 y 1.15
        // para que la interfaz se adapte con elegancia a fuentes del sistema sin deformar tarjetas SCADA
        final constrainedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: constrainedTextScaler),
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8), // Electric Cyan
          secondary: Color(0xFF0284C7),
          surface: Color(0xFF1E293B), // Slate Surface
          onSurface: Colors.white,
          error: Color(0xFFEF4444), // Industrial Red
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 2,
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const PlantsOverviewScreen(),
    );
  }
}
