import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_providers.dart';
import '../models/temperature_record.dart';
import '../models/channel_value.dart';
import '../models/record_with_values.dart';

class NewRecordScreen extends ConsumerStatefulWidget {
  final int assetId;
  final RecordWithValues? existingRecord;

  const NewRecordScreen({
    super.key,
    required this.assetId,
    this.existingRecord,
  });

  @override
  ConsumerState<NewRecordScreen> createState() => _NewRecordScreenState();
}

class _NewRecordScreenState extends ConsumerState<NewRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  String _specialStatus = 'NONE'; // 'NONE' | 'FOC_FAULT' | 'DISPLAY_OFF' | 'RTD_ERROR'
  final TextEditingController _notesController = TextEditingController();
  bool _initializedWithExisting = false;

  // Controladores y estados por canal (CH1, CH2, CH3)
  final Map<int, TextEditingController> _tempControllers = {};
  final Map<int, bool> _rtdErrors = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRecord != null) {
      _selectedDate = widget.existingRecord!.record.readingDate;
      _specialStatus = widget.existingRecord!.record.specialStatus;
      _notesController.text = widget.existingRecord!.record.eventNotes ?? '';
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _tempControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_isSaving) return;

    if (_specialStatus == 'NONE') {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor complete los campos obligatorios o marque error de RTD'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final channels = await ref.read(databaseServiceProvider).getChannelsForAsset(widget.assetId);

      final record = TemperatureRecord(
        assetId: widget.assetId,
        readingDate: _selectedDate,
        recordedAt: DateTime.now(),
        eventNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        specialStatus: _specialStatus,
      );

      final List<ChannelValue> values = [];
      for (final ch in channels) {
        final isError = _rtdErrors[ch.id] ?? false;
        final textVal = _tempControllers[ch.id]?.text.trim() ?? '';
        final double? tempVal = (isError || _specialStatus != 'NONE' || textVal.isEmpty)
            ? null
            : double.tryParse(textVal);

        values.add(
          ChannelValue(
            recordId: 0, // se asigna dentro de la transacción
            channelId: ch.id!,
            temperatureVal: tempVal,
            hasError: isError ? 1 : 0,
          ),
        );
      }

      if (widget.existingRecord != null) {
        final updatedRecord = widget.existingRecord!.record.copyWith(
          readingDate: _selectedDate,
          eventNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          specialStatus: _specialStatus,
        );
        await ref.read(appOperationsProvider).updateTemperatureRecord(
              record: updatedRecord,
              values: values,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lectura actualizada exitosamente'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        await ref.read(appOperationsProvider).saveTemperatureRecord(
              record: record,
              values: values,
            );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lectura guardada exitosamente'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetDetailAsync = ref.watch(assetDetailProvider(widget.assetId));
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: assetDetailAsync.when(
          data: (dto) => Text(
            widget.existingRecord != null
                ? 'Editar Lectura: ${dto?.asset.tag ?? ""}'
                : 'Captura Rápida: ${dto?.asset.tag ?? ""}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          loading: () => const Text('Captura de Lectura'),
          error: (e, _) => const Text('Captura de Lectura'),
        ),
      ),
      body: assetDetailAsync.when(
        data: (dto) {
          if (dto == null) {
            return const Center(child: Text('Activo no encontrado', style: TextStyle(color: Colors.white)));
          }

          // Inicializar controladores para cada canal con precarga si es edición
          if (widget.existingRecord != null && !_initializedWithExisting) {
            for (final ch in dto.channels) {
              final val = widget.existingRecord!.getValueForChannel(ch.id!);
              final isErr = widget.existingRecord!.isChannelError(ch.id!);
              _tempControllers[ch.id!] = TextEditingController(
                text: val != null ? val.toStringAsFixed(1) : '',
              );
              _rtdErrors[ch.id!] = isErr;
            }
            _initializedWithExisting = true;
          } else {
            for (final ch in dto.channels) {
              _tempControllers.putIfAbsent(ch.id!, () => TextEditingController());
              _rtdErrors.putIfAbsent(ch.id!, () => false);
            }
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Selector de Fecha y Hora
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FECHA Y HORA DE LA MEDICIÓN',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(_selectedDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                          label: const Text('Modificar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 2. Selector de Estado Rápido
                  const Text(
                    'ESTADO DEL MONITOR EN PATIO',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusRadio(
                          label: 'Normal',
                          value: 'NONE',
                          color: const Color(0xFF10B981),
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusRadio(
                          label: 'Display Off',
                          value: 'DISPLAY_OFF',
                          color: const Color(0xFF64748B),
                          icon: Icons.tv_off_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusRadio(
                          label: 'Falla FOC',
                          value: 'FOC_FAULT',
                          color: const Color(0xFFEF4444),
                          icon: Icons.error_outline_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Campos Numéricos por Canal si el estado es NORMAL
                  if (_specialStatus == 'NONE') ...[
                    const Text(
                      'TEMPERATURAS POR CANAL (°C)',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...dto.channels.map((ch) {
                      final isError = _rtdErrors[ch.id!] ?? false;
                      final controller = _tempControllers[ch.id!]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isError
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  ch.channelName,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Campo numérico grande
                            Expanded(
                              child: isError
                                  ? const Text(
                                      'Error RTD',
                                      style: TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    )
                                  : TextFormField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Ej. 75.5',
                                        hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 16),
                                        suffixText: '°C',
                                        suffixStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      validator: (val) {
                                        if (isError) return null;
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Requerido';
                                        }
                                        final numVal = double.tryParse(val.trim());
                                        if (numVal == null) {
                                          return 'Inválido';
                                        }
                                        if (numVal < -20 || numVal > 250) {
                                          return '-20 a 250°C';
                                        }
                                        return null;
                                      },
                                    ),
                            ),

                            // Checkbox Error RTD
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _rtdErrors[ch.id!] = !isError;
                                  if (!isError) {
                                    controller.clear();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: isError,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      activeColor: const Color(0xFFEF4444),
                                      onChanged: (val) {
                                        setState(() {
                                          _rtdErrors[ch.id!] = val ?? false;
                                          if (val == true) {
                                            controller.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 2),
                                    const Text(
                                      'Error RTD',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _specialStatus == 'DISPLAY_OFF'
                                  ? 'El display del monitor se encuentra apagado. Se registrará la incidencia sin valores de temperatura.'
                                  : 'Falla de comunicación u óptica "FOc" en el monitor. Se registrará el código de alarma.',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // 4. Notas de Patio / Eventos
                  const Text(
                    'NOTAS DE PATIO Y OBSERVACIONES',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      hintText: 'Ej. Ruido en contactor 50lv51, Bloqueo de compuerta, ventiladores activos...',
                      hintStyle: const TextStyle(color: Color(0xFF475569)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 5. Botón grande para guardar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveRecord,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, size: 22),
                      label: Text(
                        _isSaving
                            ? 'Guardando en Base Local...'
                            : (widget.existingRecord != null
                                ? 'ACTUALIZAR LECTURA'
                                : 'GUARDAR LECTURA'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8))),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildStatusRadio({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _specialStatus == value;
    return InkWell(
      onTap: () => setState(() => _specialStatus = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF94A3B8), size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
