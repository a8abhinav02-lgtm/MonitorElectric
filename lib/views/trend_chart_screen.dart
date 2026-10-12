import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../providers/app_providers.dart';
import '../models/asset_detail_dto.dart';
import '../models/record_with_values.dart';
import 'new_record_screen.dart';

class TrendChartScreen extends ConsumerStatefulWidget {
  final int assetId;

  const TrendChartScreen({
    super.key,
    required this.assetId,
  });

  @override
  ConsumerState<TrendChartScreen> createState() => _TrendChartScreenState();
}

class _TrendChartScreenState extends ConsumerState<TrendChartScreen> {
  final GlobalKey _chartKey = GlobalKey();
  bool _showCh1 = true;
  bool _showCh2 = true;
  bool _showCh3 = true;
  bool _showWarningLine = true;
  bool _showTripLine = true;
  bool _isHistoryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final assetDetailAsync = ref.watch(assetDetailProvider(widget.assetId));
    final historyAsync = ref.watch(assetHistoryProvider(widget.assetId));
    final baselineDate = ref.watch(systemBaselineTimeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: assetDetailAsync.when(
          data: (dto) => Text(
            'Tendencia Térmica: ${dto?.asset.tag ?? ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          loading: () => const Text('Cargando tendencia...'),
          error: (e, _) => const Text('Error'),
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Gráfica y Reporte',
            icon: const Icon(Icons.file_download_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              final dto = assetDetailAsync.value;
              final history = historyAsync.value;
              if (dto != null && history != null && history.isNotEmpty) {
                _showExportModal(context, dto, history);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No hay registros históricos para exportar')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Nueva Lectura',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => NewRecordScreen(assetId: widget.assetId),
                ),
              );
            },
          ),
        ],
      ),
      body: assetDetailAsync.when(
        data: (dto) {
          if (dto == null) {
            return const Center(child: Text('Activo no encontrado', style: TextStyle(color: Colors.white70)));
          }
          return historyAsync.when(
            data: (history) => _buildContent(context, dto, history, baselineDate),
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
            error: (err, stack) => Center(child: Text('Error al cargar historial: $err', style: const TextStyle(color: Colors.redAccent))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AssetDetailDto dto,
    List<RecordWithValues> history,
    DateTime baselineDate,
  ) {
    final asset = dto.asset;
    final channels = dto.channels;
    final dateFormat = DateFormat('dd/MM/yy');

    if (history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.show_chart_rounded, size: 64, color: Color(0xFF475569)),
            const SizedBox(height: 12),
            const Text('Sin lecturas registradas para este activo', style: TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => NewRecordScreen(assetId: widget.assetId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Registrar Primera Medición'),
            ),
          ],
        ),
      );
    }

    // Preparar series de datos para fl_chart
    // Eje X: Índices 0..N-1 basados en la lista de registros cronológicos
    final List<FlSpot> ch1Spots = [];
    final List<FlSpot> ch2Spots = [];
    final List<FlSpot> ch3Spots = [];
    final List<int> faultIndices = [];

    final ch1Id = channels.isNotEmpty ? channels[0].id : null;
    final ch2Id = channels.length > 1 ? channels[1].id : null;
    final ch3Id = channels.length > 2 ? channels[2].id : null;

    double minY = 30.0;
    double maxY = max(asset.tempTripLimit + 15, 110.0);

    for (int i = 0; i < history.length; i++) {
      final rec = history[i];
      if (rec.record.specialStatus != 'NONE') {
        faultIndices.add(i);
      }

      if (ch1Id != null) {
        final val = rec.getValueForChannel(ch1Id);
        if (val != null) {
          ch1Spots.add(FlSpot(i.toDouble(), val));
          minY = min(minY, val - 10);
          maxY = max(maxY, val + 10);
        }
      }
      if (ch2Id != null) {
        final val = rec.getValueForChannel(ch2Id);
        if (val != null) {
          ch2Spots.add(FlSpot(i.toDouble(), val));
          minY = min(minY, val - 10);
          maxY = max(maxY, val + 10);
        }
      }
      if (ch3Id != null) {
        final val = rec.getValueForChannel(ch3Id);
        if (val != null) {
          ch3Spots.add(FlSpot(i.toDouble(), val));
          minY = min(minY, val - 10);
          maxY = max(maxY, val + 10);
        }
      }
    }

    minY = (minY / 10).floor() * 10.0;
    maxY = (maxY / 10).ceil() * 10.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de Información Técnica de Normativa y Límites
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activo: ${asset.tag} ${asset.secondaryTag != null ? "(${asset.secondaryTag})" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alarma Warning: ${asset.tempWarningLimit.toStringAsFixed(0)}°C  |  Disparo Trip: ${asset.tempTripLimit.toStringAsFixed(0)}°C',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Filtros interactivos de canal y líneas normativas
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('CH1 (Azul)'),
                  selected: _showCh1,
                  selectedColor: const Color(0xFF0284C7),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _showCh1 ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => _showCh1 = val),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('CH2 (Rojo)'),
                  selected: _showCh2,
                  selectedColor: const Color(0xFFDC2626),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _showCh2 ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => _showCh2 = val),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('CH3 (Verde)'),
                  selected: _showCh3,
                  selectedColor: const Color(0xFF16A34A),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _showCh3 ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => _showCh3 = val),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Límite Warning'),
                  selected: _showWarningLine,
                  selectedColor: const Color(0xFFD97706),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _showWarningLine ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => _showWarningLine = val),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Límite Trip'),
                  selected: _showTripLine,
                  selectedColor: const Color(0xFFB91C1C),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _showTripLine ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFF1E293B),
                  onSelected: (val) => setState(() => _showTripLine = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gráfica interactiva fl_chart (Capturable en alta resolución)
          RepaintBoundary(
            key: _chartKey,
            child: Container(
              height: 320,
              padding: const EdgeInsets.only(top: 24, right: 20, left: 10, bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: max((history.length - 1).toDouble(), 1.0),
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0xFF334155),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (value) => const FlLine(
                    color: Color(0xFF243046),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: max(1, (history.length / 5).floor()).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < history.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              dateFormat.format(history[index].record.readingDate),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (_showWarningLine)
                      HorizontalLine(
                        y: asset.tempWarningLimit,
                        color: const Color(0xFFF59E0B),
                        strokeWidth: 2,
                        dashArray: [8, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 6, bottom: 2),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'WARN ${line.y.toStringAsFixed(0)}°C',
                        ),
                      ),
                    if (_showTripLine)
                      HorizontalLine(
                        y: asset.tempTripLimit,
                        color: const Color(0xFFEF4444),
                        strokeWidth: 2,
                        dashArray: [8, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 6, bottom: 2),
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'TRIP ${line.y.toStringAsFixed(0)}°C',
                        ),
                      ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final rec = (idx >= 0 && idx < history.length) ? history[idx] : null;
                        final dateStr = rec != null ? dateFormat.format(rec.record.readingDate) : '';
                        final noteStr = (rec?.record.eventNotes != null && rec!.record.eventNotes!.isNotEmpty)
                            ? '\nNota: ${rec.record.eventNotes}'
                            : '';
                        final specialStr = (rec?.record.specialStatus != 'NONE')
                            ? '\nEstado: ${rec?.record.specialStatus}'
                            : '';

                        return LineTooltipItem(
                          '$dateStr\n${spot.barIndex == 0 ? "CH1" : spot.barIndex == 1 ? "CH2" : "CH3"}: ${spot.y.toStringAsFixed(1)} °C$specialStr$noteStr',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // Canal 1: Azul Eléctrico
                  if (_showCh1)
                    LineChartBarData(
                      spots: ch1Spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF38BDF8),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: const Color(0xFF38BDF8),
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                  // Canal 2: Rojo / Coral
                  if (_showCh2)
                    LineChartBarData(
                      spots: ch2Spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFFF87171),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: const Color(0xFFF87171),
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                  // Canal 3: Verde Neón
                  if (_showCh3)
                    LineChartBarData(
                      spots: ch3Spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: const Color(0xFF34D399),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: const Color(0xFF34D399),
                          strokeWidth: 1.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

          // Indicador de estados de falla en el historial
          if (faultIndices.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF334155).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF475569)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF94A3B8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se detectaron ${faultIndices.length} periodos con anomalía o monitor fuera de servicio (FOC / Display Apagado).',
                      style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Historial cronológico detallado (Colapsado por defecto)
          InkWell(
            onTap: () {
              setState(() {
                _isHistoryExpanded = !_isHistoryExpanded;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: Color(0xFF38BDF8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'HISTÓRICO DE TEMPERATURA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${history.length} lecturas',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _isHistoryExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isHistoryExpanded) ...[
            const SizedBox(height: 10),
            ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              // Presentamos del más reciente al más antiguo
              final revIndex = history.length - 1 - idx;
              final rec = history[revIndex];
              final date = rec.record.readingDate;
              final maxTemp = rec.maxTemperature;
              final isTrip = maxTemp != null && maxTemp >= asset.tempTripLimit;
              final isWarn = maxTemp != null && maxTemp >= asset.tempWarningLimit;

              Color borderCol = const Color(0xFF334155);
              if (rec.record.specialStatus != 'NONE') {
                borderCol = const Color(0xFF64748B);
              } else if (isTrip) {
                borderCol = const Color(0xFFEF4444);
              } else if (isWarn) {
                borderCol = const Color(0xFFF59E0B);
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol.withValues(alpha: 0.6), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    dateFormat.format(date),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (rec.record.specialStatus != 'NONE')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF475569),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  rec.record.specialStatus,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (maxTemp != null)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Pico: ${maxTemp.toStringAsFixed(1)} °C',
                                  style: TextStyle(
                                    color: isTrip
                                        ? const Color(0xFFEF4444)
                                        : isWarn
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFF34D399),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => NewRecordScreen(
                                      assetId: widget.assetId,
                                      existingRecord: rec,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => _confirmDeleteRecord(
                                rec.record.id!,
                                rec.record.readingDate,
                                asset.id!,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Desglose de canales
                    if (rec.record.specialStatus == 'NONE')
                      Wrap(
                        spacing: 12,
                        children: channels.map((ch) {
                          final val = rec.getValueForChannel(ch.id!);
                          final isErr = rec.isChannelError(ch.id!);
                          return Text(
                            '${ch.channelName}: ${isErr ? "ERR RTD" : "${val?.toStringAsFixed(1) ?? '--'}°C"}',
                            style: TextStyle(
                              color: isErr
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          );
                        }).toList(),
                      ),

                    // Notas técnicas
                    if (rec.record.eventNotes != null && rec.record.eventNotes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              rec.record.eventNotes!,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    ),
  );
}

  Future<void> _confirmDeleteRecord(
    int recordId,
    DateTime date,
    int assetId,
  ) async {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Eliminar Registro', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la lectura del ${dateFormat.format(date)}?\n\nEsta acción recalculará los gráficos de tendencia y el estado del activo.',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appOperationsProvider).deleteRecord(recordId, assetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro de temperatura eliminado correctamente'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<Directory> _getExportDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && await downloads.exists()) return downloads;
    } catch (_) {}

    if (Platform.isAndroid) {
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (await androidDownload.exists()) {
        return androidDownload;
      }
    }

    return await getApplicationDocumentsDirectory();
  }

  Future<Uint8List?> _captureChartPng() async {
    try {
      final boundary =
          _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing chart image: $e');
      return null;
    }
  }

  void _showExportModal(
    BuildContext context,
    AssetDetailDto dto,
    List<RecordWithValues> history,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.file_download_outlined,
                        color: Color(0xFF38BDF8), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Exportar Diagnóstico: ${dto.asset.tag}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Selecciona el formato de exportación local deseado:',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 16),
                // 1. PDF
                _buildExportOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: const Color(0xFFEF4444),
                  title: 'Reporte Técnico Formal (PDF)',
                  subtitle:
                      'Documento oficial con ficha técnica, gráfica incrustada y tabla de lecturas',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportPdfReport(context, dto, history);
                  },
                ),
                const SizedBox(height: 8),
                // 2. PNG
                _buildExportOptionTile(
                  icon: Icons.image_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Gráfica en Imagen PNG',
                  subtitle:
                      'Captura gráfica en ultra-alta resolución (3.0x pixel ratio)',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportImage(context, dto, isJpg: false);
                  },
                ),
                const SizedBox(height: 8),
                // 3. JPG
                _buildExportOptionTile(
                  icon: Icons.photo_camera_back_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Gráfica en Imagen JPG',
                  subtitle:
                      'Captura fotográfica comprimida para mensajería o reportes ligeros',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportImage(context, dto, isJpg: true);
                  },
                ),
                const SizedBox(height: 8),
                // 4. CSV
                _buildExportOptionTile(
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Series de Tiempo en CSV',
                  subtitle:
                      'Datos tabulares crudos para hojas de cálculo y análisis en Excel',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _exportCsvData(context, dto, history);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            color: Color(0xFF64748B), size: 14),
      ),
    );
  }

  Future<void> _exportImage(
    BuildContext context,
    AssetDetailDto dto, {
    required bool isJpg,
  }) async {
    try {
      final pngBytes = await _captureChartPng();
      if (pngBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No fue posible renderizar la imagen del gráfico.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      Uint8List fileBytes;
      String extension;
      if (isJpg) {
        final decoded = img.decodeImage(pngBytes);
        if (decoded == null) {
          throw Exception('No se pudo decodificar el buffer para compresión JPG');
        }
        fileBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
        extension = 'jpg';
      } else {
        fileBytes = pngBytes;
        extension = 'png';
      }

      final dir = await _getExportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Grafica_${dto.asset.tag}_$timestamp.$extension';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(fileBytes);

      if (!context.mounted) return;
      _showExportSuccessDialog(
        context,
        dto: dto,
        title: 'Imagen ${extension.toUpperCase()} Exportada',
        file: file,
        formatDesc:
            'Captura gráfica de alta resolución guardada en el dispositivo.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportPdfReport(
    BuildContext context,
    AssetDetailDto dto,
    List<RecordWithValues> history,
  ) async {
    try {
      final chartImageBytes = await _captureChartPng();
      final pdf = pw.Document();
      final asset = dto.asset;
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SISTEMA SCADA - MONITOREO TÉRMICO',
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('Reporte Técnico Diagnóstico de Transformador',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(
                  'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 10),
            // Ficha Técnica
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ACTIVO: ${asset.tag} ${asset.secondaryTag != null ? "(${asset.secondaryTag})" : ""}',
                            style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Tecnología: ${asset.assetType == "OIL_IMMERSED" ? "En Aceite (IEC 60076-7)" : "Seco (IEC 60076-11)"}',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('Aislamiento: ${asset.insulationClass ?? "Estándar"}',
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            'Potencia: ${asset.ratedPowerKva?.toStringAsFixed(0) ?? "N/A"} kVA | Tensión: ${asset.primaryVoltageKv?.toStringAsFixed(1) ?? "N/A"} kV',
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            'Alarma Warning: ${asset.tempWarningLimit.toStringAsFixed(0)} °C',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange800)),
                        pw.Text(
                            'Disparo Trip: ${asset.tempTripLimit.toStringAsFixed(0)} °C',
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.red800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Gráfica Incrustada
            if (chartImageBytes != null) ...[
              pw.Text('TENDENCIA TÉRMICA MULTICANAL',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 6),
              pw.Container(
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Image(
                  pw.MemoryImage(chartImageBytes),
                  height: 190,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 12),
            ],

            // Tabla de Registros
            pw.Text('HISTÓRICO CRONOLÓGICO DE MEDICIONES (${history.length} LECTURAS)',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              headers: [
                'Fecha',
                ...dto.channels.map((c) => c.channelName),
                'Pico (°C)',
                'Estatus',
                'Notas Técnicas',
              ],
              data: history.map((rec) {
                final date = dateFormat.format(rec.record.readingDate);
                final chVals = dto.channels.map((ch) {
                  if (rec.isChannelError(ch.id!)) return 'ERR';
                  final v = rec.getValueForChannel(ch.id!);
                  return v?.toStringAsFixed(1) ?? '--';
                }).toList();
                final maxT = rec.maxTemperature?.toStringAsFixed(1) ?? '--';
                final status = rec.record.specialStatus != 'NONE'
                    ? rec.record.specialStatus
                    : 'NORMAL';
                final notes = rec.record.eventNotes ?? '';
                return [date, ...chVals, maxT, status, notes];
              }).toList(),
            ),
          ],
        ),
      );

      final dir = await _getExportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Reporte_${dto.asset.tag}_$timestamp.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (!context.mounted) return;
      _showExportSuccessDialog(
        context,
        dto: dto,
        title: 'Reporte Técnico PDF Generado',
        file: file,
        formatDesc:
            'Reporte formal con ficha técnica, gráfica incrustada y tabla de mediciones.',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _exportCsvData(
    BuildContext context,
    AssetDetailDto dto,
    List<RecordWithValues> history,
  ) async {
    try {
      final asset = dto.asset;
      final channels = dto.channels;
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

      final channelHeaders =
          channels.map((c) => '"${c.channelName} (C)"').join(',');
      final StringBuffer csv = StringBuffer();
      csv.writeln(
          'Tag,Secundario,Fecha_Lectura,Estado_Especial,Pico_Temp_C,$channelHeaders,Alarma_Warn_C,Alarma_Trip_C,Notas_Patio');

      for (final rec in history) {
        final dateStr = dateFormat.format(rec.record.readingDate);
        final statusStr = rec.record.specialStatus;
        final maxTempStr = rec.maxTemperature?.toStringAsFixed(1) ?? '';
        final notesStr = rec.record.eventNotes?.replaceAll('"', '""') ?? '';

        final channelVals = channels.map((ch) {
          final isErr = rec.isChannelError(ch.id!);
          if (isErr) return 'ERR_RTD';
          final val = rec.getValueForChannel(ch.id!);
          return val?.toStringAsFixed(1) ?? '';
        }).join(',');

        csv.writeln(
            '"${asset.tag}","${asset.secondaryTag ?? ""}","$dateStr","$statusStr","$maxTempStr",$channelVals,${asset.tempWarningLimit},${asset.tempTripLimit},"$notesStr"');
      }

      final csvContent = csv.toString();
      final dir = await _getExportDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'Historico_${asset.tag}_$timestamp.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvContent);

      if (!context.mounted) return;
      _showExportSuccessDialog(
        context,
        dto: dto,
        title: 'Datos CSV Exportados',
        file: file,
        formatDesc:
            'Se exportaron ${history.length} registros cronológicos en formato tabular para Excel.',
        copyContent: csvContent,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar CSV: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog(
    BuildContext context, {
    required AssetDetailDto dto,
    required String title,
    required File file,
    required String formatDesc,
    String? copyContent,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.file_download_done_rounded,
                color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDesc,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UBICACIÓN LOCAL DEL ARCHIVO:',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      file.path,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(file.path)],
                    text: 'Diagnóstico térmico de ${dto.asset.tag} - $title',
                  ),
                );
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No fue posible abrir menú compartir: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Compartir / Enviar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
          ),
          if (copyContent != null)
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyContent));
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datos CSV copiados al portapapeles'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: file.path));
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ruta de archivo copiada al portapapeles'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar Ruta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }
}

