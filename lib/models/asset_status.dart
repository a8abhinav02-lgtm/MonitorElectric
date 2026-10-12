import 'package:flutter/material.dart';

enum ThermalAlarmLevel {
  normal,
  warning,
  trip,
  faultOrOff,
  noData,
}

class AssetHealthStatus {
  final ThermalAlarmLevel alarmLevel;
  final double? maxTemperature;
  final double? deltaTemperature;
  final int daysSinceLastReading;
  final bool isOutdated;
  final String statusLabel;
  final Color statusColor;
  final String? diagnosticNote;

  const AssetHealthStatus({
    required this.alarmLevel,
    this.maxTemperature,
    this.deltaTemperature,
    required this.daysSinceLastReading,
    required this.isOutdated,
    required this.statusLabel,
    required this.statusColor,
    this.diagnosticNote,
  });

  factory AssetHealthStatus.evaluate({
    required double? maxTemp,
    double? deltaTemp,
    required double warningLimit,
    required double tripLimit,
    double deltaTWarningLimit = 10.0,
    double deltaTTripLimit = 15.0,
    bool isCircuitBreaker = false,
    required String? specialStatus,
    required DateTime? lastReadingDate,
    required DateTime referenceDate,
  }) {
    final days = lastReadingDate == null
        ? 999
        : referenceDate.difference(lastReadingDate).inDays;
    final outdated = days > 15;

    if (specialStatus != null &&
        (specialStatus == 'FOC_FAULT' ||
            specialStatus == 'DISPLAY_OFF' ||
            specialStatus == 'RTD_ERROR')) {
      final label = specialStatus == 'FOC_FAULT'
          ? 'Falla FOC'
          : specialStatus == 'DISPLAY_OFF'
              ? 'Display Apagado'
              : 'Error RTD';
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.faultOrOff,
        maxTemperature: maxTemp,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: label,
        statusColor: const Color(0xFF78909C), // Slate/Gray
      );
    }

    if (maxTemp == null) {
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.noData,
        maxTemperature: null,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: 'Sin Datos',
        statusColor: const Color(0xFF607D8B),
      );
    }

    // 1. Evaluación por límite absoluto de disparo
    if (maxTemp >= tripLimit) {
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.trip,
        maxTemperature: maxTemp,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: 'CRÍTICO / TRIP',
        statusColor: const Color(0xFFE53935), // Industrial Red
        diagnosticNote: 'Límite absoluto superado (${maxTemp.toStringAsFixed(1)} °C >= ${tripLimit.toStringAsFixed(0)} °C)',
      );
    }

    // 2. Evaluación por desbalance de fases crítico (NETA MTS / NFPA 70B)
    if (deltaTemp != null && deltaTemp >= deltaTTripLimit) {
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.trip,
        maxTemperature: maxTemp,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: 'CRÍTICO (ΔT)',
        statusColor: const Color(0xFFE53935),
        diagnosticNote: 'Desbalance crítico entre fases: ΔT = ${deltaTemp.toStringAsFixed(1)} °C (Límite NETA: ${deltaTTripLimit.toStringAsFixed(0)} °C)',
      );
    }

    // 3. Evaluación por límite absoluto de advertencia
    if (maxTemp >= warningLimit) {
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.warning,
        maxTemperature: maxTemp,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: 'ADVERTENCIA',
        statusColor: const Color(0xFFFFA000), // Industrial Amber
        diagnosticNote: 'Umbral de advertencia alcanzado (${maxTemp.toStringAsFixed(1)} °C >= ${warningLimit.toStringAsFixed(0)} °C)',
      );
    }

    // 4. Evaluación por desbalance de fases de advertencia (NETA MTS)
    if (deltaTemp != null && deltaTemp >= deltaTWarningLimit) {
      return AssetHealthStatus(
        alarmLevel: ThermalAlarmLevel.warning,
        maxTemperature: maxTemp,
        deltaTemperature: deltaTemp,
        daysSinceLastReading: days,
        isOutdated: outdated,
        statusLabel: 'ALARMA (ΔT)',
        statusColor: const Color(0xFFFFA000),
        diagnosticNote: 'Desbalance térmico entre fases: ΔT = ${deltaTemp.toStringAsFixed(1)} °C (Límite: ${deltaTWarningLimit.toStringAsFixed(0)} °C)',
      );
    }

    // 5. Estado Normal
    return AssetHealthStatus(
      alarmLevel: ThermalAlarmLevel.normal,
      maxTemperature: maxTemp,
      deltaTemperature: deltaTemp,
      daysSinceLastReading: days,
      isOutdated: outdated,
      statusLabel: 'NORMAL',
      statusColor: const Color(0xFF00E676), // Industrial Neon Green
    );
  }
}
