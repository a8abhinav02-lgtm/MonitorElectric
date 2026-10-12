import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/asset_detail_dto.dart';
import '../../services/transformer_standards_engine.dart';
import 'status_badge.dart';

class AssetCard extends StatefulWidget {
  final AssetDetailDto dto;
  final VoidCallback onTap;
  final VoidCallback onAddReading;
  final VoidCallback onEdit;

  const AssetCard({
    super.key,
    required this.dto,
    required this.onTap,
    required this.onAddReading,
    required this.onEdit,
  });

  @override
  State<AssetCard> createState() => _AssetCardState();
}

class _AssetCardState extends State<AssetCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dto = widget.dto;
    final asset = dto.asset;
    final latestRecord = dto.latestRecord;
    final health = dto.healthStatus;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final maxTemp = latestRecord?.maxTemperature;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: health.statusColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Compacto (Siempre Visible)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                asset.tag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (asset.secondaryTag != null &&
                                asset.secondaryTag!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    asset.secondaryTag!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          asset.isCircuitBreaker
                              ? 'Interruptor ${asset.voltageLevel == "MT" ? "Media Tensión (MT)" : "Baja Tensión (BT)"} • ${asset.mountingType == "DRAWOUT" ? "Extraíble" : "Fijo"}'
                              : '${TransformerStandardsEngine.formatAssetType(asset.assetType)} • ${TransformerStandardsEngine.formatInsulationClass(asset.insulationClass)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Indicador Térmico + Semáforo + Chevron Desplegable
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (latestRecord != null &&
                          latestRecord.record.specialStatus != 'NONE')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            latestRecord.record.specialStatus,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (maxTemp != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: health.statusColor.withValues(alpha: 0.4)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${maxTemp.toStringAsFixed(1)} °C',
                              style: TextStyle(
                                color: health.statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      StatusBadge(healthStatus: health, compact: true),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),

              // Contenido Expandido
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 10),

                // Barra de Datos Operativos Adaptativa (Voltaje, Carga/Potencia, Norma)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            asset.isCircuitBreaker ? Icons.alt_route_rounded : Icons.bolt_rounded,
                            size: 14,
                            color: const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            asset.isCircuitBreaker
                                ? '${asset.primaryVoltageKv != null ? "${asset.primaryVoltageKv} kV" : "--"} • ${asset.ratedCurrentA != null ? "In: ${asset.ratedCurrentA!.toStringAsFixed(0)} A" : "--"}'
                                : '${asset.primaryVoltageKv != null ? "${asset.primaryVoltageKv} kV" : "--"} • ${asset.ratedPowerKva != null ? "${asset.ratedPowerKva!.toStringAsFixed(0)} kVA" : "--"}',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Text(
                        asset.isCircuitBreaker
                            ? (asset.voltageLevel == 'MT' ? 'IEC 62271-1 (MT)' : 'IEC 60947-2 (BT)')
                            : (asset.assetType == 'OIL_IMMERSED'
                                ? 'IEC 60076-7 (Aceite)'
                                : 'IEC 60076-11 (Seco)'),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Límites técnicos y última lectura
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LÍMITES CONFIGURADOS',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'W: ${asset.tempWarningLimit.toStringAsFixed(0)}°C',
                                  style: const TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'T: ${asset.tempTripLimit.toStringAsFixed(0)}°C',
                                  style: const TextStyle(
                                    color: Color(0xFFF87171),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (asset.isCircuitBreaker) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ΔT Warn: ${asset.deltaTWarningLimit.toStringAsFixed(0)}°C',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'ΔT Trip: ${asset.deltaTTripLimit.toStringAsFixed(0)}°C',
                                    style: const TextStyle(
                                      color: Color(0xFFF87171),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ÚLTIMA LECTURA',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (latestRecord != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                dateFormat.format(latestRecord.record.readingDate),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            )
                          else
                            const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Sin registros',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Valores individuales por canal (CH1, CH2, CH3, etc.)
                if (latestRecord != null &&
                    latestRecord.record.specialStatus == 'NONE') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: dto.channels.map((ch) {
                        final val = latestRecord.getValueForChannel(ch.id!);
                        final isErr = latestRecord.isChannelError(ch.id!);
                        return Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  ch.channelName,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (isErr)
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'ERR RTD',
                                    style: TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (val != null)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${val.toStringAsFixed(1)} °C',
                                    style: TextStyle(
                                      color: val >= asset.tempTripLimit
                                          ? const Color(0xFFEF4444)
                                          : val >= asset.tempWarningLimit
                                              ? const Color(0xFFFBBF24)
                                              : const Color(0xFF38BDF8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  '--',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (latestRecord.deltaTemperature != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (latestRecord.deltaTemperature! >= asset.deltaTTripLimit)
                            ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                            : (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit)
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (latestRecord.deltaTemperature! >= asset.deltaTTripLimit)
                              ? const Color(0xFFEF4444)
                              : (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit)
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF334155),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit)
                                ? Icons.warning_amber_rounded
                                : Icons.compare_arrows_rounded,
                            size: 16,
                            color: (latestRecord.deltaTemperature! >= asset.deltaTTripLimit)
                                ? const Color(0xFFF87171)
                                : (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit)
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Desbalance entre fases (ΔT = Tmax - Tmin): ${latestRecord.deltaTemperature!.toStringAsFixed(1)} °C'
                              '${latestRecord.deltaTemperature! >= asset.deltaTTripLimit ? " • CRÍTICO (NETA MTS)" : (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit ? " • ALARMA (NETA MTS)" : " • Normal")}',
                              style: TextStyle(
                                color: (latestRecord.deltaTemperature! >= asset.deltaTTripLimit)
                                    ? const Color(0xFFF87171)
                                    : (latestRecord.deltaTemperature! >= asset.deltaTWarningLimit)
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFCBD5E1),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (health.diagnosticNote != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: health.statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: health.statusColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: health.statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              health.diagnosticNote!,
                              style: TextStyle(
                                color: health.statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else if (latestRecord != null &&
                    latestRecord.record.specialStatus != 'NONE') ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF475569)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estado especial: ${latestRecord.record.specialStatus} ${latestRecord.record.eventNotes != null ? "(${latestRecord.record.eventNotes})" : ""}',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Alerta de desactualización (> 15 días)
                if (health.isOutdated) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB45309).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            color: Color(0xFFFBBF24), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Sin lecturas hace ${health.daysSinceLastReading} días (> 15d)',
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Botones de acción adaptativos: Parámetros, Tendencia & Nueva Lectura
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Parámetros'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFCBD5E1),
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.show_chart_rounded, size: 14),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Tendencia'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onAddReading,
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Lectura'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
