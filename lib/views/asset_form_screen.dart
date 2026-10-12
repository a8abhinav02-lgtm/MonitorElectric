import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../models/measurement_channel.dart';
import '../services/transformer_standards_engine.dart';
import '../providers/app_providers.dart';

class ChannelInput {
  final TextEditingController nameController;
  String probeType;

  ChannelInput({required String name, this.probeType = 'PT100'})
      : nameController = TextEditingController(text: name);

  void dispose() {
    nameController.dispose();
  }
}

class AssetFormScreen extends ConsumerStatefulWidget {
  final int subareaId;
  final Asset? existingAsset;
  final String? subareaCategory;

  const AssetFormScreen({
    super.key,
    required this.subareaId,
    this.existingAsset,
    this.subareaCategory,
  });

  @override
  ConsumerState<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends ConsumerState<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _category;
  late TextEditingController _tagController;
  late TextEditingController _secondaryTagController;

  // Campos específicos de Transformador
  late TextEditingController _powerController;
  late String _assetType;
  late String _insulationClass;

  // Campos específicos de Interruptor
  late String _voltageLevel;
  late String _mountingType;
  late TextEditingController _ratedCurrentController;
  late TextEditingController _deltaTWarningLimitController;
  late TextEditingController _deltaTTripLimitController;

  // Campos compartidos
  late TextEditingController _voltageController;
  late TextEditingController _warningLimitController;
  late TextEditingController _tripLimitController;

  bool _manualOverride = false;
  bool _isSaving = false;
  final List<ChannelInput> _customChannels = [];

  @override
  void initState() {
    super.initState();
    final a = widget.existingAsset;

    _category = a?.category ?? widget.subareaCategory ?? 'TRANSFORMER';
    _tagController = TextEditingController(text: a?.tag ?? '');
    _secondaryTagController = TextEditingController(text: a?.secondaryTag ?? '');

    // Inicializar Transformador
    _assetType = a?.assetType ?? 'DRY_TYPE';
    _insulationClass = a?.insulationClass ?? 'CLASS_F';
    _powerController = TextEditingController(
      text: a?.ratedPowerKva != null ? a!.ratedPowerKva.toString() : '2000',
    );

    // Inicializar Interruptor
    _voltageLevel = a?.voltageLevel ?? 'MT';
    _mountingType = a?.mountingType ?? 'DRAWOUT';
    _ratedCurrentController = TextEditingController(
      text: a?.ratedCurrentA != null ? a!.ratedCurrentA!.toStringAsFixed(0) : '1250',
    );
    _deltaTWarningLimitController = TextEditingController(
      text: (a?.deltaTWarningLimit ?? 10.0).toStringAsFixed(1),
    );
    _deltaTTripLimitController = TextEditingController(
      text: (a?.deltaTTripLimit ?? 15.0).toStringAsFixed(1),
    );

    // Compartidos
    _voltageController = TextEditingController(
      text: a?.primaryVoltageKv != null
          ? a!.primaryVoltageKv.toString()
          : (_category == 'CIRCUIT_BREAKER' ? (_voltageLevel == 'MT' ? '13.8' : '0.48') : '13.8'),
    );

    _warningLimitController = TextEditingController();
    _tripLimitController = TextEditingController();

    if (a != null) {
      _warningLimitController.text = a.tempWarningLimit.toString();
      _tripLimitController.text = a.tempTripLimit.toString();
    } else {
      _applyStandardLimits();
      if (_category == 'CIRCUIT_BREAKER') {
        _customChannels.addAll([
          ChannelInput(name: 'Fase L1 (R)', probeType: 'INFRARED'),
          ChannelInput(name: 'Fase L2 (S)', probeType: 'INFRARED'),
          ChannelInput(name: 'Fase L3 (T)', probeType: 'INFRARED'),
        ]);
      } else {
        _customChannels.addAll([
          ChannelInput(name: 'CH1 - Fase A', probeType: 'PT100'),
          ChannelInput(name: 'CH2 - Fase B', probeType: 'PT100'),
          ChannelInput(name: 'CH3 - Fase C', probeType: 'PT100'),
          ChannelInput(name: 'CH4 - Núcleo/Aceite', probeType: 'PT100'),
        ]);
      }
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _secondaryTagController.dispose();
    _powerController.dispose();
    _voltageController.dispose();
    _ratedCurrentController.dispose();
    _deltaTWarningLimitController.dispose();
    _deltaTTripLimitController.dispose();
    _warningLimitController.dispose();
    _tripLimitController.dispose();
    for (final ch in _customChannels) {
      ch.dispose();
    }
    super.dispose();
  }

  void _applyStandardLimits() {
    if (_category == 'CIRCUIT_BREAKER') {
      final rec = TransformerStandardsEngine.getRecommendedBreakerLimits(
        voltageLevel: _voltageLevel,
      );
      _warningLimitController.text = rec.warningLimit.toString();
      _tripLimitController.text = rec.tripLimit.toString();
      _deltaTWarningLimitController.text = rec.deltaTWarningLimit.toString();
      _deltaTTripLimitController.text = rec.deltaTTripLimit.toString();
    } else {
      final recommendation = TransformerStandardsEngine.getRecommendedLimits(
        assetType: _assetType,
        insulationClass: _insulationClass,
      );
      _warningLimitController.text = recommendation.warningLimit.toString();
      _tripLimitController.text = recommendation.tripLimit.toString();
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final warning = double.parse(_warningLimitController.text.trim());
      final trip = double.parse(_tripLimitController.text.trim());
      final power = double.tryParse(_powerController.text.trim());
      final voltage = double.tryParse(_voltageController.text.trim());
      final current = double.tryParse(_ratedCurrentController.text.trim());
      final deltaTWarn = double.tryParse(_deltaTWarningLimitController.text.trim()) ?? 10.0;
      final deltaTTrip = double.tryParse(_deltaTTripLimitController.text.trim()) ?? 15.0;

      final asset = Asset(
        id: widget.existingAsset?.id,
        subareaId: widget.subareaId,
        tag: _tagController.text.trim(),
        secondaryTag: _secondaryTagController.text.trim().isEmpty
            ? null
            : _secondaryTagController.text.trim(),
        category: _category,
        voltageLevel: _category == 'CIRCUIT_BREAKER' ? _voltageLevel : null,
        ratedCurrentA: _category == 'CIRCUIT_BREAKER' ? current : null,
        mountingType: _category == 'CIRCUIT_BREAKER' ? _mountingType : null,
        deltaTWarningLimit: deltaTWarn,
        deltaTTripLimit: deltaTTrip,
        assetType: _category == 'CIRCUIT_BREAKER'
            ? (_voltageLevel == 'MT' ? 'BREAKER_MT' : 'BREAKER_BT')
            : _assetType,
        insulationClass: _category == 'CIRCUIT_BREAKER'
            ? 'STANDARD_BREAKER'
            : (_assetType == 'OIL_IMMERSED' ? 'STANDARD_OIL' : _insulationClass),
        ratedPowerKva: _category == 'CIRCUIT_BREAKER' ? null : power,
        primaryVoltageKv: voltage,
        tempWarningLimit: warning,
        tempTripLimit: trip,
      );

      if (widget.existingAsset == null) {
        if (_customChannels.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debe definir al menos un punto de medición'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final channels = _customChannels
            .map((c) => MeasurementChannel(
                  assetId: 0,
                  channelName: c.nameController.text.trim(),
                  probeType: c.probeType,
                ))
            .toList();

        await ref.read(appOperationsProvider).saveAsset(
              asset: asset,
              channels: channels,
            );
      } else {
        await ref.read(appOperationsProvider).updateAsset(asset);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingAsset == null
                ? (_category == 'CIRCUIT_BREAKER' ? 'Interruptor creado con éxito' : 'Transformador creado con éxito')
                : 'Activo actualizado con éxito'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.redAccent),
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
    final isBreaker = _category == 'CIRCUIT_BREAKER';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          widget.existingAsset == null
              ? (isBreaker ? 'Nuevo Interruptor' : 'Nuevo Transformador')
              : (isBreaker ? 'Editar Interruptor' : 'Editar Transformador'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Normas Técnicas y Criterios (?)',
            onPressed: () => TransformerStandardsEngine.showTechnicalStandardsHelpDialog(
              context,
              category: _category,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAsset,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.existingAsset == null
                      ? (isBreaker ? 'REGISTRAR INTERRUPTOR' : 'REGISTRAR TRANSFORMADOR')
                      : 'GUARDAR CAMBIOS',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Selector de Tipo de Activo (Desplegable)
                if (widget.existingAsset == null) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tipo de Activo *',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TRANSFORMER',
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text('Transformador')),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'CIRCUIT_BREAKER',
                        child: Row(
                          children: [
                            Icon(Icons.alt_route_rounded, color: Color(0xFF38BDF8), size: 20),
                            SizedBox(width: 10),
                            Expanded(child: Text('Interruptor')),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _category) {
                        setState(() {
                          _category = val;
                          _applyStandardLimits();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Tags Principal y Secundario
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _tagController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: isBreaker ? 'Tag Principal *' : 'Tag Principal *',
                          hintText: isBreaker ? 'ej. INT-01, 52-1' : 'ej. T3-8',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) =>
                            (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _secondaryTagController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tag Secundario',
                          hintText: isBreaker ? 'ej. CB-MT-03' : 'ej. 50EN07',
                          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==========================================
                // SECCIÓN CONDICIONAL: INTERRUPTOR
                // ==========================================
                if (isBreaker) ...[
                  // Nivel de Tensión
                  const Text(
                    'NIVEL DE TENSIÓN Y NORMATIVA APLICABLE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFFFBBF24)),
                        label: const Text('MT (IEC 62271-1)'),
                        selected: _voltageLevel == 'MT',
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _voltageLevel == 'MT' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _voltageLevel = 'MT';
                              if (_voltageController.text == '0.48') _voltageController.text = '13.8';
                              if (!_manualOverride) _applyStandardLimits();
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.flash_auto_rounded, size: 16, color: Color(0xFF38BDF8)),
                        label: const Text('BT (IEC 60947-2)'),
                        selected: _voltageLevel == 'BT',
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _voltageLevel == 'BT' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _voltageLevel = 'BT';
                              if (_voltageController.text == '13.8') _voltageController.text = '0.48';
                              if (!_manualOverride) _applyStandardLimits();
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tipo de Montaje
                  const Text(
                    'TIPO DE MONTAJE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Extraíble (Drawout)'),
                        selected: _mountingType == 'DRAWOUT',
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _mountingType == 'DRAWOUT' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _mountingType = 'DRAWOUT');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Fijo (Fixed)'),
                        selected: _mountingType == 'FIXED',
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _mountingType == 'FIXED' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _mountingType = 'FIXED');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Parámetros Eléctricos
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ratedCurrentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Corriente In (A)',
                            hintText: 'ej. 1250',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _voltageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            labelText: _voltageLevel == 'MT' ? 'Tensión (kV)' : 'Tensión (kV o V)',
                            hintText: _voltageLevel == 'MT' ? 'ej. 13.8' : 'ej. 0.48',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Panel Normativo para Interruptores
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _voltageLevel == 'MT'
                                    ? 'Norma: IEC 62271-1 & NETA MTS'
                                    : 'Norma: IEC 60947-2 & NETA MTS',
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _voltageLevel == 'MT'
                              ? 'IEC 62271-1 fija 105 °C máximo en bornes/contactos. NETA MTS / NFPA 70B evalúan el desbalance térmico entre fases: ΔT ≥ 10 °C (Alarma) y ΔT ≥ 15 °C (Disparo / Crítico).'
                              : 'IEC 60947-2 fija 105 °C máximo en terminales. NETA MTS / NFPA 70B alerta ante desbalance entre fases ΔT ≥ 10 °C y acción correctiva inmediata si ΔT ≥ 15 °C.',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () {
                                setState(() {
                                  _manualOverride = !_manualOverride;
                                  if (!_manualOverride) _applyStandardLimits();
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _manualOverride,
                                    activeColor: const Color(0xFFF59E0B),
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (val) {
                                      setState(() {
                                        _manualOverride = val ?? false;
                                        if (!_manualOverride) _applyStandardLimits();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  const Flexible(
                                    child: Text(
                                      'Ajuste manual de límites',
                                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_manualOverride)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _manualOverride = false;
                                    _applyStandardLimits();
                                  });
                                },
                                icon: const Icon(Icons.restore_rounded, size: 14, color: Color(0xFF38BDF8)),
                                label: const Text(
                                  'Auto-Norma',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Límites de Temperatura Absoluta
                  const Text(
                    'LÍMITES TÉRMICOS ABSOLUTOS (IEC)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _warningLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Alarma Abs. °C *',
                            labelStyle: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tripLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Disparo Abs. °C *',
                            labelStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            final w = double.tryParse(_warningLimitController.text);
                            if (w != null && n <= w) return 'Trip > Warn';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Límites de Desbalance Térmico entre Fases (Delta T)
                  const Text(
                    'CRITERIO DE DESBALANCE TÉRMICO ENTRE FASES (NETA / NFPA 70B)',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _deltaTWarningLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Alarma ΔT Fases *',
                            labelStyle: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _deltaTTripLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Disparo ΔT Fases *',
                            labelStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            final w = double.tryParse(_deltaTWarningLimitController.text);
                            if (w != null && n <= w) return 'ΔTrip > ΔWarn';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // ==========================================
                  // SECCIÓN CONDICIONAL: TRANSFORMADOR
                  // ==========================================
                  const Text(
                    'TIPO DE CONSTRUCCIÓN',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Seco (Dry Type)'),
                        selected: _assetType == 'DRY_TYPE',
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _assetType == 'DRY_TYPE' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _assetType = 'DRY_TYPE';
                              if (!_manualOverride) _applyStandardLimits();
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Aceite (Oil Immersed)'),
                        selected: _assetType == 'OIL_IMMERSED',
                        selectedColor: const Color(0xFF0284C7),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: TextStyle(
                          color: _assetType == 'OIL_IMMERSED' ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _assetType = 'OIL_IMMERSED';
                              _applyStandardLimits();
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Clase de Aislamiento (si es Seco)
                  if (_assetType == 'DRY_TYPE') ...[
                    const Text(
                      'CLASE TÉRMICA DE AISLAMIENTO',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Clase B (130 °C)'),
                          selected: _insulationClass == 'CLASS_B',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: _insulationClass == 'CLASS_B' ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _insulationClass = 'CLASS_B';
                                _applyStandardLimits();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Clase F (155 °C) [Estándar]'),
                          selected: _insulationClass == 'CLASS_F',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: _insulationClass == 'CLASS_F' ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _insulationClass = 'CLASS_F';
                                _applyStandardLimits();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Clase H (180 °C)'),
                          selected: _insulationClass == 'CLASS_H',
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: const Color(0xFF1E293B),
                          labelStyle: TextStyle(
                            color: _insulationClass == 'CLASS_H' ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _insulationClass = 'CLASS_H';
                                _applyStandardLimits();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Panel Normativo para Transformadores
                  Builder(
                    builder: (context) {
                      final recommendation = TransformerStandardsEngine.getRecommendedLimits(
                        assetType: _assetType,
                        insulationClass: _insulationClass,
                      );
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Normativa: ${recommendation.standardName}',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              recommendation.technicalRationale,
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    setState(() {
                                      _manualOverride = !_manualOverride;
                                      if (!_manualOverride) _applyStandardLimits();
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _manualOverride,
                                        activeColor: const Color(0xFFF59E0B),
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (val) {
                                          setState(() {
                                            _manualOverride = val ?? false;
                                            if (!_manualOverride) _applyStandardLimits();
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      const Flexible(
                                        child: Text(
                                          'Ajuste manual de límites',
                                          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_manualOverride)
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _manualOverride = false;
                                        _applyStandardLimits();
                                      });
                                    },
                                    icon: const Icon(Icons.restore_rounded, size: 14, color: Color(0xFF38BDF8)),
                                    label: const Text(
                                      'Auto-Norma',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Límites de Temperatura
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _warningLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Alarma °C *',
                            labelStyle: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tripLimitController,
                          enabled: _manualOverride,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 17,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Disparo °C *',
                            labelStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            final n = double.tryParse(val ?? '');
                            if (n == null) return 'Inválido';
                            final w = double.tryParse(_warningLimitController.text);
                            if (w != null && n <= w) return 'Trip > Warn';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Datos de Placa Eléctrica
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _powerController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Potencia (kVA)',
                            hintText: 'ej. 2000',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _voltageController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Tensión (kV)',
                            hintText: 'ej. 13.8',
                            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ==========================================
                // PUNTOS DE MEDICIÓN TÉRMICA / CANALES
                // ==========================================
                if (widget.existingAsset == null) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isBreaker ? Icons.camera_alt_outlined : Icons.sensors_rounded,
                            color: const Color(0xFF38BDF8),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isBreaker
                                  ? 'PUNTOS DE INSPECCIÓN (IR)'
                                  : 'PUNTOS DE MEDICIÓN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            final idx = _customChannels.length + 1;
                            _customChannels.add(
                              ChannelInput(
                                name: isBreaker ? 'Punto $idx' : 'CH$idx',
                                probeType: isBreaker ? 'INFRARED' : 'PT100',
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline_rounded,
                            size: 16, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Agregar',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBreaker
                        ? 'Define los puntos termográficos visibles en campo (ej. Fase L1, L2, L3, Bornes de Entrada o Salida).'
                        : 'Configura manualmente cada punto de medición (Fase A, B, C, Aceite, etc.) y su tipo de sensor.',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _customChannels.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = _customChannels[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.nameController,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  labelText: isBreaker ? 'Punto #${idx + 1}' : 'Canal #${idx + 1}',
                                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                  isDense: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty ? 'Requerido' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: item.probeType,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF1E293B),
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'INFRARED',
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Termografía (IR)'),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PT100',
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('PT100 (RTD)'),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'TC_K',
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Termocupla K'),
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'TC_J',
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Termocupla J'),
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          item.probeType = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            if (_customChannels.length > 1) ...[
                              IconButton(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    final removed = _customChannels.removeAt(idx);
                                    removed.dispose();
                                  });
                                },
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFEF4444), size: 20),
                                tooltip: 'Eliminar Punto',
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
