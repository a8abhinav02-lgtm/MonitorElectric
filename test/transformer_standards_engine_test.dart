import 'package:flutter_test/flutter_test.dart';
import 'package:termo_trafo/services/transformer_standards_engine.dart';
import 'package:termo_trafo/models/asset_status.dart';

void main() {
  group('TransformerStandardsEngine Tests', () {
    test('Calcula límites IEC 60076-7 para transformadores en aceite', () {
      final rec = TransformerStandardsEngine.getRecommendedLimits(
        assetType: 'OIL_IMMERSED',
      );
      expect(rec.warningLimit, 85.0);
      expect(rec.tripLimit, 100.0);
      expect(rec.standardName, contains('IEC 60076-7'));
    });

    test('Calcula límites IEC 60076-11 para transformadores secos Clase F (default)', () {
      final rec = TransformerStandardsEngine.getRecommendedLimits(
        assetType: 'DRY_TYPE',
        insulationClass: 'CLASS_F',
      );
      expect(rec.warningLimit, 130.0);
      expect(rec.tripLimit, 150.0);
      expect(rec.standardName, contains('Clase F'));
    });

    test('Calcula límites IEC 60076-11 para transformadores secos Clase B', () {
      final rec = TransformerStandardsEngine.getRecommendedLimits(
        assetType: 'DRY_TYPE',
        insulationClass: 'CLASS_B',
      );
      expect(rec.warningLimit, 100.0);
      expect(rec.tripLimit, 125.0);
    });

    test('Calcula límites IEC 60076-11 para transformadores secos Clase H', () {
      final rec = TransformerStandardsEngine.getRecommendedLimits(
        assetType: 'DRY_TYPE',
        insulationClass: 'CLASS_H',
      );
      expect(rec.warningLimit, 150.0);
      expect(rec.tripLimit, 170.0);
    });
  });

  group('AssetHealthStatus Semáforo Tests', () {
    final now = DateTime(2026, 10, 11);

    test('Evalúa estado Normal cuando temperatura < Warning', () {
      final status = AssetHealthStatus.evaluate(
        maxTemp: 75.0,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'NONE',
        lastReadingDate: DateTime(2026, 10, 5),
        referenceDate: now,
      );
      expect(status.alarmLevel, ThermalAlarmLevel.normal);
      expect(status.isOutdated, false);
      expect(status.statusLabel, 'NORMAL');
    });

    test('Evalúa Advertencia cuando Warning <= temp < Trip', () {
      final status = AssetHealthStatus.evaluate(
        maxTemp: 92.0,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'NONE',
        lastReadingDate: DateTime(2026, 10, 5),
        referenceDate: now,
      );
      expect(status.alarmLevel, ThermalAlarmLevel.warning);
      expect(status.statusLabel, 'ADVERTENCIA');
    });

    test('Evalúa Disparo (Trip) cuando temp >= Trip', () {
      final status = AssetHealthStatus.evaluate(
        maxTemp: 105.0,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'NONE',
        lastReadingDate: DateTime(2026, 10, 5),
        referenceDate: now,
      );
      expect(status.alarmLevel, ThermalAlarmLevel.trip);
      expect(status.statusLabel, 'CRÍTICO / TRIP');
    });

    test('Evalúa Alerta de desactualización si han transcurrido > 15 días', () {
      final status = AssetHealthStatus.evaluate(
        maxTemp: 70.0,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'NONE',
        lastReadingDate: DateTime(2026, 9, 20), // 21 días atrás
        referenceDate: now,
      );
      expect(status.isOutdated, true);
      expect(status.daysSinceLastReading, 21);
    });

    test('Evalúa Estados Especiales (FOC_FAULT, DISPLAY_OFF)', () {
      final focStatus = AssetHealthStatus.evaluate(
        maxTemp: null,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'FOC_FAULT',
        lastReadingDate: DateTime(2026, 10, 5),
        referenceDate: now,
      );
      expect(focStatus.alarmLevel, ThermalAlarmLevel.faultOrOff);
      expect(focStatus.statusLabel, 'Falla FOC');

      final displayStatus = AssetHealthStatus.evaluate(
        maxTemp: null,
        warningLimit: 85.0,
        tripLimit: 100.0,
        specialStatus: 'DISPLAY_OFF',
        lastReadingDate: DateTime(2026, 10, 5),
        referenceDate: now,
      );
      expect(displayStatus.alarmLevel, ThermalAlarmLevel.faultOrOff);
      expect(displayStatus.statusLabel, 'Display Apagado');
    });

    test('Evalúa Desbalance Térmico entre fases ΔT (NETA MTS / NFPA 70B)', () {
      // 1. Normal con ΔT bajo (< 10°C)
      final normalStatus = AssetHealthStatus.evaluate(
        maxTemp: 75.0,
        warningLimit: 90.0,
        tripLimit: 105.0,
        specialStatus: 'NONE',
        deltaTemp: 5.0,
        deltaTWarningLimit: 10.0,
        deltaTTripLimit: 15.0,
        isCircuitBreaker: true,
        lastReadingDate: now,
        referenceDate: now,
      );
      expect(normalStatus.alarmLevel, ThermalAlarmLevel.normal);

      // 2. Advertencia por Desbalance ΔT >= 10°C aunque temp absoluta sea normal
      final warnStatus = AssetHealthStatus.evaluate(
        maxTemp: 78.0,
        warningLimit: 90.0,
        tripLimit: 105.0,
        specialStatus: 'NONE',
        deltaTemp: 11.5,
        deltaTWarningLimit: 10.0,
        deltaTTripLimit: 15.0,
        isCircuitBreaker: true,
        lastReadingDate: now,
        referenceDate: now,
      );
      expect(warnStatus.alarmLevel, ThermalAlarmLevel.warning);
      expect(warnStatus.statusLabel, 'ALARMA (ΔT)');
      expect(warnStatus.diagnosticNote?.contains('Desbalance térmico entre fases'), true);

      // 3. Crítico / Disparo por Desbalance ΔT >= 15°C
      final tripStatus = AssetHealthStatus.evaluate(
        maxTemp: 82.0,
        warningLimit: 90.0,
        tripLimit: 105.0,
        specialStatus: 'NONE',
        deltaTemp: 16.2,
        deltaTWarningLimit: 10.0,
        deltaTTripLimit: 15.0,
        isCircuitBreaker: true,
        lastReadingDate: now,
        referenceDate: now,
      );
      expect(tripStatus.alarmLevel, ThermalAlarmLevel.trip);
      expect(tripStatus.statusLabel, 'CRÍTICO (ΔT)');
      expect(tripStatus.diagnosticNote?.contains('Desbalance crítico entre fases'), true);
    });
  });

  group('Circuit Breaker Standards Engine Tests', () {
    test('Calcula límites IEC 62271-1 para interruptores de Media Tensión (MT)', () {
      final rec = TransformerStandardsEngine.getRecommendedBreakerLimits(
        voltageLevel: 'MT',
      );
      expect(rec.warningLimit, 90.0);
      expect(rec.tripLimit, 105.0);
      expect(rec.deltaTWarningLimit, 10.0);
      expect(rec.deltaTTripLimit, 15.0);
      expect(rec.standardName.contains('IEC 62271-1'), true);
    });

    test('Calcula límites IEC 60947-2 para interruptores de Baja Tensión (BT)', () {
      final rec = TransformerStandardsEngine.getRecommendedBreakerLimits(
        voltageLevel: 'BT',
      );
      expect(rec.warningLimit, 90.0);
      expect(rec.tripLimit, 105.0);
      expect(rec.deltaTWarningLimit, 10.0);
      expect(rec.deltaTTripLimit, 15.0);
      expect(rec.standardName.contains('IEC 60947-2'), true);
    });
  });
}

