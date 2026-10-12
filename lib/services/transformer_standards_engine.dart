import 'package:flutter/material.dart';

class StandardRecommendation {
  final double warningLimit;
  final double tripLimit;
  final double deltaTWarningLimit;
  final double deltaTTripLimit;
  final String standardName;
  final String technicalRationale;

  const StandardRecommendation({
    required this.warningLimit,
    required this.tripLimit,
    this.deltaTWarningLimit = 10.0,
    this.deltaTTripLimit = 15.0,
    required this.standardName,
    required this.technicalRationale,
  });
}

class TransformerStandardsEngine {
  /// Calcula los límites recomendados según IEC 60076-7 / IEEE C57.91 (Aceite)
  /// y IEC 60076-11 / IEEE C57.96 (Seco).
  static StandardRecommendation getRecommendedLimits({
    required String assetType,
    String? insulationClass,
  }) {
    if (assetType == 'OIL_IMMERSED') {
      return const StandardRecommendation(
        warningLimit: 85.0,
        tripLimit: 100.0,
        standardName: 'IEC 60076-7 / IEEE C57.91',
        technicalRationale:
            'Transformador sumergido en líquido aislante mineral. Temperatura máxima de aceite superior: 85°C alarma, 100°C disparo según régimen de carga normal.',
      );
    }

    // DRY_TYPE (Seco)
    final insClass = insulationClass ?? 'CLASS_F';
    switch (insClass) {
      case 'CLASS_B':
        return const StandardRecommendation(
          warningLimit: 100.0,
          tripLimit: 125.0,
          standardName: 'IEC 60076-11 / IEEE C57.96 (Clase B - 130°C)',
          technicalRationale:
              'Aislamiento Clase B (límite térmico 130°C). Elevación máxima admisible de devanados: 80K.',
        );
      case 'CLASS_H':
        return const StandardRecommendation(
          warningLimit: 150.0,
          tripLimit: 170.0,
          standardName: 'IEC 60076-11 / IEEE C57.96 (Clase H - 180°C)',
          technicalRationale:
              'Aislamiento Clase H (límite térmico 180°C). Elevación máxima admisible de devanados: 125K.',
        );
      case 'CLASS_F':
      default:
        return const StandardRecommendation(
          warningLimit: 130.0,
          tripLimit: 150.0,
          standardName: 'IEC 60076-11 / IEEE C57.96 (Clase F - 155°C)',
          technicalRationale:
              'Aislamiento Clase F estándar industrial (límite 155°C). Elevación admisible 100K con temperatura ambiente de 40°C.',
        );
    }
  }

  /// Calcula los límites recomendados para Interruptores BT/MT según IEC 62271-1 e IEC 60947-2
  static StandardRecommendation getRecommendedBreakerLimits({
    required String voltageLevel,
  }) {
    if (voltageLevel == 'MT') {
      return const StandardRecommendation(
        warningLimit: 90.0,
        tripLimit: 105.0,
        standardName: 'IEC 62271-1 / IEEE C37.20.2 (Media Tensión)',
        technicalRationale:
            'Celdas e interruptores de Media Tensión (1 kV - 36 kV). Temperatura máxima admisible en bornes y contactos: 105°C (elevación 65K sobre 40°C ambiente). Alarma de advertencia en 90°C.',
      );
    }
    return const StandardRecommendation(
      warningLimit: 90.0,
      tripLimit: 105.0,
      standardName: 'IEC 60947-2 / UL 489 (Baja Tensión)',
      technicalRationale:
          'Interruptores de Baja Tensión (< 1000 V AC). Temperatura admisible en terminales de conexión: 105°C (elevación 70K/80K sobre ambiente). Alarma de advertencia en 90°C.',
    );
  }

  /// Retorna lista de tipos de activos admitidos para trafos
  static List<String> get assetTypes => const ['DRY_TYPE', 'OIL_IMMERSED'];

  /// Retorna lista de clases de aislamiento para tipo seco
  static List<String> get dryInsulationClasses =>
      const ['CLASS_B', 'CLASS_F', 'CLASS_H'];

  /// Nombre amigable del tipo
  static String formatAssetType(String type) {
    switch (type) {
      case 'DRY_TYPE':
        return 'Tipo Seco (Dry Type)';
      case 'OIL_IMMERSED':
        return 'Sumergido en Aceite (Oil Immersed)';
      case 'CIRCUIT_BREAKER':
        return 'Interruptor de Potencia';
      default:
        return type;
    }
  }

  /// Nombre amigable de la clase de aislamiento
  static String formatInsulationClass(String? insClass) {
    switch (insClass) {
      case 'CLASS_B':
        return 'Clase B (130 °C)';
      case 'CLASS_F':
        return 'Clase F (155 °C) [Estándar]';
      case 'CLASS_H':
        return 'Clase H (180 °C)';
      case 'STANDARD_OIL':
        return 'Aceite Mineral Estándar';
      default:
        return insClass ?? 'N/A';
    }
  }

  /// Modal interactivo de ayuda con las normas técnicas consideradas
  static void showTechnicalStandardsHelpDialog(BuildContext context, {String? category}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.help_outline_rounded, color: Color(0xFF38BDF8), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Normas Técnicas Consideradas',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TRANSFORMADORES
                  _buildNormSection(
                    title: '1. Transformadores de Potencia',
                    icon: Icons.electric_bolt_rounded,
                    color: const Color(0xFFFBBF24),
                    items: [
                      _buildNormItem(
                        norm: 'IEC 60076-7 / IEEE C57.91 (Aceite)',
                        desc: 'Límite de temperatura en aceite superior: 85°C Alarma, 100°C Disparo. Devanados: 98°C a 110°C según régimen de carga normal.',
                      ),
                      _buildNormItem(
                        norm: 'IEC 60076-11 / IEEE C57.96 (Tipo Seco)',
                        desc: 'Límites térmicos según clase de aislamiento:\n• Clase B (130°C): W: 100°C / T: 125°C\n• Clase F (155°C): W: 130°C / T: 150°C [Estándar]\n• Clase H (180°C): W: 150°C / T: 170°C',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. INTERRUPTORES DE POTENCIA
                  _buildNormSection(
                    title: '2. Interruptores BT y MT',
                    icon: Icons.toggle_on_rounded,
                    color: const Color(0xFF38BDF8),
                    items: [
                      _buildNormItem(
                        norm: 'IEC 62271-1 / IEC 62271-100 (Media Tensión)',
                        desc: 'Aparamenta de Media Tensión (1 kV a 36 kV). Temperatura máxima admisible en bornes y contactos principales: 105°C (elevación de 65K sobre ambiente de 40°C). Umbral recomendado: 90°C Alarma, 105°C Disparo.',
                      ),
                      _buildNormItem(
                        norm: 'IEC 60947-2 / UL 489 (Baja Tensión)',
                        desc: 'Interruptores automáticos en Baja Tensión (< 1000 V). Límite de calentamiento en terminales de conexión para conductores: 105°C máximo. Umbral recomendado: 90°C Alarma, 105°C Disparo.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. DESBALANCE TÉRMICO (TERMOGRAFÍA)
                  _buildNormSection(
                    title: '3. Desbalance Térmico (ΔT Termografía)',
                    icon: Icons.thermostat_rounded,
                    color: const Color(0xFFEF4444),
                    items: [
                      _buildNormItem(
                        norm: 'ANSI/NETA MTS-2023 (Tabla 100.18) & NFPA 70B',
                        desc: 'Diferencia térmica entre fases con carga similar (ΔT = Tmax - Tmin):\n• ΔT ≤ 3 °C: Condición Normal.\n• 4 °C a 9 °C: Monitorear tendencia.\n• ΔT ≥ 10 °C: ALARMA (Falso contacto o desbalance).\n• ΔT ≥ 15 °C: CRÍTICO / DISPARO (Intervención inmediata por riesgo inminente de daño en contactos).',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildNormSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  static Widget _buildNormItem({required String norm, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            norm,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, height: 1.3),
          ),
        ],
      ),
    );
  }
}
