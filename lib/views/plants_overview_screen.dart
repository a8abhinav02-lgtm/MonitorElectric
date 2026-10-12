import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../models/asset_status.dart';
import '../models/asset_detail_dto.dart';
import '../models/plant.dart';
import '../models/subarea.dart';
import '../services/transformer_standards_engine.dart';
import 'widgets/asset_card.dart';
import 'widgets/kpi_summary_card.dart';
import 'trend_chart_screen.dart';
import 'new_record_screen.dart';
import 'asset_form_screen.dart';

class PlantsOverviewScreen extends ConsumerStatefulWidget {
  const PlantsOverviewScreen({super.key});

  @override
  ConsumerState<PlantsOverviewScreen> createState() => _PlantsOverviewScreenState();
}

class _PlantsOverviewScreenState extends ConsumerState<PlantsOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plantsAsync = ref.watch(plantsProvider);
    final selectedPlantId = ref.watch(selectedPlantIdProvider);
    final subareasAsync = ref.watch(subareasProvider);
    final selectedSubareaId = ref.watch(selectedSubareaIdProvider);
    final assetsAsync = ref.watch(assetsWithDetailProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF38BDF8), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TERMO-TRAFO SCADA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Monitoreo Térmico Predictivo Offline',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Normas Técnicas y Criterios (?)',
            onPressed: () =>
                TransformerStandardsEngine.showTechnicalStandardsHelpDialog(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: const Color(0xFF1E293B),
            onSelected: (val) async {
              if (val == 'reseed') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Text('Reinicializar Datos', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      '¿Desea restaurar la base de datos local con los datos precargados del Seeder normativo?',
                      style: TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                        child: const Text('Restaurar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(appOperationsProvider).reseedData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Datos restaurados correctamente'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'reseed',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text('Restaurar Datos Históricos', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: plantsAsync.when(
        data: (plants) {
          if (plants.isEmpty) {
            return const Center(child: Text('No hay plantas registradas', style: TextStyle(color: Colors.white)));
          }

          // Inicializar selección de planta si aún es null
          if (selectedPlantId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedPlantIdProvider.notifier).selectPlant(plants.first.id);
            });
          }

          return Column(
            children: [
              // 1. Selector Desplegable de Planta según plantas creadas + Botón Nueva Planta
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.factory_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'PLANTA:',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: plants.any((p) => p.id == selectedPlantId)
                                ? selectedPlantId
                                : plants.first.id,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            icon: const Icon(Icons.arrow_drop_down_circle_outlined,
                                color: Color(0xFF38BDF8), size: 18),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            items: plants.map((plant) {
                              return DropdownMenuItem<int>(
                                value: plant.id,
                                child: Text(
                                  '${plant.code} - ${plant.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newPlantId) {
                              if (newPlantId != null) {
                                ref
                                    .read(selectedPlantIdProvider.notifier)
                                    .selectPlant(newPlantId);
                                ref
                                    .read(selectedSubareaIdProvider.notifier)
                                    .selectSubarea(null);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showCreatePlantDialog(context),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: Color(0xFF38BDF8), size: 22),
                      tooltip: 'Crear Nueva Planta',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      color: const Color(0xFF1E293B),
                      tooltip: 'Opciones de Planta',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        final currentPlant = plants.firstWhere(
                          (p) => p.id == (selectedPlantId ?? plants.first.id),
                          orElse: () => plants.first,
                        );
                        if (val == 'edit') {
                          _showEditPlantDialog(context, currentPlant);
                        } else if (val == 'delete') {
                          _confirmDeletePlant(context, currentPlant);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 8),
                              Text('Editar Planta', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar Planta', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Selector Jerárquico de Subárea + Botón Nueva Subárea
              subareasAsync.when(
                data: (subareas) {
                  if (subareas.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: const Color(0xFF1E293B),
                      child: Row(
                        children: [
                          const Text('Sin subáreas en esta planta',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: selectedPlantId != null
                                ? () => _showCreateSubareaDialog(context, selectedPlantId)
                                : null,
                            icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                            label: const Text('Crear Subárea',
                                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }

                  if (selectedSubareaId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(selectedSubareaIdProvider.notifier).selectSubarea(subareas.first.id);
                    });
                  }

                  return Container(
                    color: const Color(0xFF1E293B),
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ...subareas.map((sub) {
                            final isSel = selectedSubareaId == sub.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onLongPress: () => _showSubareaOptions(context, sub),
                                child: FilterChip(
                                  avatar: Icon(
                                    sub.isCircuitBreaker
                                        ? Icons.alt_route_rounded
                                        : Icons.bolt_rounded,
                                    size: 15,
                                    color: isSel
                                        ? Colors.white
                                        : (sub.isCircuitBreaker
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFFFBBF24)),
                                  ),
                                  label: Text(sub.name),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF2563EB),
                                  checkmarkColor: Colors.white,
                                  backgroundColor: const Color(0xFF0F172A),
                                  labelStyle: TextStyle(
                                    color: isSel ? Colors.white : const Color(0xFF94A3B8),
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                  onSelected: (sel) {
                                    if (sel) {
                                      ref.read(selectedSubareaIdProvider.notifier).selectSubarea(sub.id);
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ActionChip(
                              avatar: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF38BDF8)),
                              label: const Text('Subárea',
                                  style: TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xFF0F172A),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              onPressed: selectedPlantId != null
                                  ? () => _showCreateSubareaDialog(context, selectedPlantId)
                                  : null,
                            ),
                          ),
                          if (subareas.any((s) => s.id == selectedSubareaId)) ...[
                            IconButton(
                              onPressed: () {
                                final activeSub = subareas.firstWhere((s) => s.id == selectedSubareaId);
                                _showSubareaOptions(context, activeSub);
                              },
                              icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8), size: 20),
                              tooltip: 'Gestionar Subárea Seleccionada',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(color: Color(0xFF38BDF8)),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
              ),

              const Divider(color: Color(0xFF334155), height: 1),

              // 3. Barra de Búsqueda de Activos
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por tag (ej. T3-6, 50EN07)...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                  ),
                ),
              ),

              // 4. Panel de Contenido: KPIs y Listado de Tarjetas de Activos
              Expanded(
                child: assetsAsync.when(
                  data: (dtos) {
                    final filtered = dtos.where((d) {
                      if (_searchQuery.isEmpty) return true;
                      final t1 = d.asset.tag.toLowerCase();
                      final t2 = d.asset.secondaryTag?.toLowerCase() ?? '';
                      return t1.contains(_searchQuery) || t2.contains(_searchQuery);
                    }).toList();

                    // Conteo para KPIs
                    int countNormal = 0;
                    int countWarning = 0;
                    int countTrip = 0;
                    int countFault = 0;

                    for (final d in dtos) {
                      switch (d.healthStatus.alarmLevel) {
                        case ThermalAlarmLevel.normal:
                          countNormal++;
                          break;
                        case ThermalAlarmLevel.warning:
                          countWarning++;
                          break;
                        case ThermalAlarmLevel.trip:
                          countTrip++;
                          break;
                        case ThermalAlarmLevel.faultOrOff:
                        case ThermalAlarmLevel.noData:
                          countFault++;
                          break;
                      }
                    }

                    return RefreshIndicator(
                      color: const Color(0xFF38BDF8),
                      backgroundColor: const Color(0xFF1E293B),
                      onRefresh: () async {
                        ref.invalidate(assetsWithDetailProvider);
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        children: [
                          // Barra de KPIs SCADA
                          Row(
                            children: [
                              Expanded(
                                child: KpiSummaryCard(
                                  label: 'Normal',
                                  value: countNormal.toString(),
                                  color: const Color(0xFF10B981),
                                  icon: Icons.check_circle_rounded,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: KpiSummaryCard(
                                  label: 'Alarma',
                                  value: countWarning.toString(),
                                  color: const Color(0xFFF59E0B),
                                  icon: Icons.warning_rounded,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: KpiSummaryCard(
                                  label: 'Trip Crítico',
                                  value: countTrip.toString(),
                                  color: const Color(0xFFEF4444),
                                  icon: Icons.dangerous_rounded,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: KpiSummaryCard(
                                  label: 'Falla / Off',
                                  value: countFault.toString(),
                                  color: const Color(0xFF64748B),
                                  icon: Icons.error_outline_rounded,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          if (filtered.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF475569)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No se encontraron transformadores con "$_searchQuery"'
                                        : 'No hay activos registrados en esta subárea',
                                    style: const TextStyle(color: Color(0xFF94A3B8)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isTablet = constraints.maxWidth >= 600;
                                if (isTablet) {
                                  final col1 = <AssetDetailDto>[];
                                  final col2 = <AssetDetailDto>[];
                                  for (int i = 0; i < filtered.length; i++) {
                                    if (i % 2 == 0) {
                                      col1.add(filtered[i]);
                                    } else {
                                      col2.add(filtered[i]);
                                    }
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: col1.map((d) => _buildAssetCard(context, d)).toList(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          children: col2.map((d) => _buildAssetCard(context, d)).toList(),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return Column(
                                  children: filtered.map((d) => _buildAssetCard(context, d)).toList(),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                  ),
                  error: (e, stack) => Center(
                    child: Text('Error al cargar activos: $e', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
        error: (e, stack) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('NUEVO ACTIVO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        onPressed: () {
          final subareaId = ref.read(selectedSubareaIdProvider);
          if (subareaId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Seleccione una subárea primero')),
            );
            return;
          }
          final currentSubareas = subareasAsync.value ?? [];
          final activeSub = currentSubareas.firstWhere(
            (s) => s.id == subareaId,
            orElse: () => currentSubareas.first,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => AssetFormScreen(
                subareaId: subareaId,
                subareaCategory: activeSub.category,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreatePlantDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.factory_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('Nueva Planta', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Código de Planta (ej. PPL, SUB-01)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF475569)),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Nombre de Planta (ej. Planta Principal)',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF475569)),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final code = codeCtrl.text.trim().toUpperCase();
                final name = nameCtrl.text.trim();
                Navigator.of(ctx).pop();
                try {
                  final newId = await ref.read(appOperationsProvider).createPlant(
                        code: code,
                        name: name,
                      );
                  ref.read(selectedPlantIdProvider.notifier).selectPlant(newId);
                  ref.read(selectedSubareaIdProvider.notifier).selectSubarea(null);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Planta $code creada con éxito'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al crear planta: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
            ),
            child: const Text('Crear Planta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateSubareaDialog(
      BuildContext context, int plantId) async {
    final nameCtrl = TextEditingController(text: 'Transformadores');
    final formKey = GlobalKey<FormState>();
    String category = 'TRANSFORMER';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.domain_add_rounded, color: Color(0xFF38BDF8), size: 22),
              SizedBox(width: 8),
              Text('Nueva Subárea', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Tipo de Activos a Gestionar *',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
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
                      if (val != null && val != category) {
                        setDialogState(() {
                          category = val;
                          if (val == 'CIRCUIT_BREAKER') {
                            if (nameCtrl.text.isEmpty || nameCtrl.text == 'Transformadores') {
                              nameCtrl.text = 'Patio de Interruptores';
                            }
                          } else {
                            if (nameCtrl.text.isEmpty || nameCtrl.text == 'Patio de Interruptores') {
                              nameCtrl.text = 'Transformadores';
                            }
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category == 'TRANSFORMER'
                                ? 'Monitoreo de devanados y aceite según IEC 60076-7 / 60076-11.'
                                : 'Termografía de bornes, contactos y desbalance térmico ΔT (IEC 62271-1, IEC 60947-2, NETA MTS).',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: category == 'TRANSFORMER'
                          ? 'Nombre de Subárea (ej. Transformadores Secos)'
                          : 'Nombre de Subárea (ej. Celdas MT 13.8kV / BT)',
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF475569)),
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final name = nameCtrl.text.trim();
                  Navigator.of(ctx).pop();
                  try {
                    final newId = await ref.read(appOperationsProvider).createSubarea(
                          plantId: plantId,
                          name: name,
                          category: category,
                        );
                    ref
                        .read(selectedSubareaIdProvider.notifier)
                        .selectSubarea(newId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Subárea "$name" creada con éxito'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al crear subárea: $e'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
              ),
              child: const Text('Crear Subárea', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(BuildContext context, AssetDetailDto dto) {
    return AssetCard(
      dto: dto,
      onEdit: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AssetFormScreen(
              subareaId: dto.asset.subareaId,
              existingAsset: dto.asset,
              subareaCategory: dto.asset.category,
            ),
          ),
        );
      },
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => TrendChartScreen(assetId: dto.asset.id!),
          ),
        );
      },
      onAddReading: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => NewRecordScreen(assetId: dto.asset.id!),
          ),
        );
      },
    );
  }

  Future<void> _showEditPlantDialog(BuildContext context, Plant plant) async {
    final codeCtrl = TextEditingController(text: plant.code);
    final nameCtrl = TextEditingController(text: plant.name);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('Editar Planta', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Código de Planta',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF475569)),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Nombre de Planta',
                  labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF475569)),
                  ),
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final updated = plant.copyWith(
                  code: codeCtrl.text.trim().toUpperCase(),
                  name: nameCtrl.text.trim(),
                );
                Navigator.of(ctx).pop();
                try {
                  await ref.read(appOperationsProvider).updatePlant(updated);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Planta actualizada correctamente'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar planta: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePlant(BuildContext context, Plant plant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Eliminar Planta', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la planta "${plant.code} - ${plant.name}"?\n\nADVERTENCIA: Esta acción eliminará en cascada todas sus subáreas, activos y registros históricos asociados.',
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
            child: const Text('Eliminar Permanentemente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appOperationsProvider).deletePlant(plant.id!);
      ref.read(selectedPlantIdProvider.notifier).selectPlant(null);
      ref.read(selectedSubareaIdProvider.notifier).selectSubarea(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Planta "${plant.name}" eliminada'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _showSubareaOptions(BuildContext context, Subarea subarea) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF475569),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.domain_rounded, color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Subárea: ${subarea.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF334155)),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8)),
                title: const Text('Editar Nombre de Subárea', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showEditSubareaDialog(context, subarea);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                title: const Text('Eliminar Subárea', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _confirmDeleteSubarea(context, subarea);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditSubareaDialog(BuildContext context, Subarea subarea) async {
    final nameCtrl = TextEditingController(text: subarea.name);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Text('Editar Subárea', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Nombre de Subárea',
              labelStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF475569)),
              ),
            ),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Requerido' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final updated = subarea.copyWith(name: nameCtrl.text.trim());
                Navigator.of(ctx).pop();
                try {
                  await ref.read(appOperationsProvider).updateSubarea(updated);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subárea actualizada correctamente'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al actualizar subárea: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSubarea(BuildContext context, Subarea subarea) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Eliminar Subárea', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente la subárea "${subarea.name}"?\n\nEsta acción eliminará en cascada todos sus transformadores y registros históricos asociados.',
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
            child: const Text('Eliminar Permanentemente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(appOperationsProvider).deleteSubarea(subarea.id!);
      ref.read(selectedSubareaIdProvider.notifier).selectSubarea(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subárea "${subarea.name}" eliminada'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
