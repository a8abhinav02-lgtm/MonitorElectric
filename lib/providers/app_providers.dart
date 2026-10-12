import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';
import '../models/plant.dart';
import '../models/subarea.dart';
import '../models/asset.dart';
import '../models/asset_detail_dto.dart';
import '../models/record_with_values.dart';
import '../models/temperature_record.dart';
import '../models/channel_value.dart';
import '../models/measurement_channel.dart';

/// 1. Ancla temporal capturada al inicio de la aplicación
final systemBaselineTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

/// 2. Servicio de base de datos local SQLite
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 3. Lista de Plantas disponibles
final plantsProvider = FutureProvider<List<Plant>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getPlants();
});

/// 4. Notifier para la planta seleccionada (Riverpod 3+)
class SelectedPlantNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectPlant(int? id) => state = id;
}

final selectedPlantIdProvider =
    NotifierProvider<SelectedPlantNotifier, int?>(SelectedPlantNotifier.new);

/// 5. Subáreas de la planta seleccionada
final subareasProvider = FutureProvider<List<Subarea>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final plantId = ref.watch(selectedPlantIdProvider);
  if (plantId == null) return [];
  return await dbService.getSubareasByPlant(plantId);
});

/// 6. Notifier para la subárea seleccionada (Riverpod 3+)
class SelectedSubareaNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void selectSubarea(int? id) => state = id;
}

final selectedSubareaIdProvider =
    NotifierProvider<SelectedSubareaNotifier, int?>(SelectedSubareaNotifier.new);

/// 7. Listado de activos con detalles (canales, última lectura y semáforo de alarma)
final assetsWithDetailProvider = FutureProvider<List<AssetDetailDto>>((ref) async {
  final dbService = ref.watch(databaseServiceProvider);
  final subareaId = ref.watch(selectedSubareaIdProvider);
  final baselineDate = ref.watch(systemBaselineTimeProvider);

  if (subareaId == null) return [];

  final assets = await dbService.getAssetsBySubarea(subareaId);
  final List<AssetDetailDto> dtos = [];

  for (final asset in assets) {
    final channels = await dbService.getChannelsForAsset(asset.id!);
    final latestRecord = await dbService.getLatestRecordForAsset(asset.id!);
    dtos.add(
      AssetDetailDto.fromData(
        asset: asset,
        channels: channels,
        latestRecord: latestRecord,
        systemNow: baselineDate,
      ),
    );
  }

  return dtos;
});

/// 8. Historial completo de un transformador específico
final assetHistoryProvider =
    FutureProvider.family<List<RecordWithValues>, int>((ref, assetId) async {
  final dbService = ref.watch(databaseServiceProvider);
  return await dbService.getHistoricalRecordsForAsset(assetId);
});

/// 9. Información de un transformador específico
final assetDetailProvider =
    FutureProvider.family<AssetDetailDto?, int>((ref, assetId) async {
  final dbService = ref.watch(databaseServiceProvider);
  final baselineDate = ref.watch(systemBaselineTimeProvider);

  final asset = await dbService.getAssetById(assetId);
  if (asset == null) return null;

  final channels = await dbService.getChannelsForAsset(assetId);
  final latestRecord = await dbService.getLatestRecordForAsset(assetId);

  return AssetDetailDto.fromData(
    asset: asset,
    channels: channels,
    latestRecord: latestRecord,
    systemNow: baselineDate,
  );
});

/// 10. Controlador de Operaciones CRUD
final appOperationsProvider = Provider((ref) => AppOperations(ref));

class AppOperations {
  final Ref _ref;
  AppOperations(this._ref);

  Future<int> saveTemperatureRecord({
    required TemperatureRecord record,
    required List<ChannelValue> values,
  }) async {
    final dbService = _ref.read(databaseServiceProvider);
    final id = await dbService.insertRecordWithValues(record: record, values: values);

    // Invalida proveedores para refresco reactivo automático
    _ref.invalidate(assetsWithDetailProvider);
    _ref.invalidate(assetHistoryProvider(record.assetId));
    _ref.invalidate(assetDetailProvider(record.assetId));

    return id;
  }

  Future<void> updateTemperatureRecord({
    required TemperatureRecord record,
    required List<ChannelValue> values,
  }) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.updateRecordWithValues(record: record, values: values);

    // Invalida proveedores para refresco reactivo automático
    _ref.invalidate(assetsWithDetailProvider);
    _ref.invalidate(assetHistoryProvider(record.assetId));
    _ref.invalidate(assetDetailProvider(record.assetId));
  }

  Future<int> createPlant({
    required String code,
    required String name,
  }) async {
    final dbService = _ref.read(databaseServiceProvider);
    final plant = Plant(code: code, name: name);
    final id = await dbService.insertPlant(plant);
    _ref.invalidate(plantsProvider);
    return id;
  }

  Future<void> updatePlant(Plant plant) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.updatePlant(plant);
    _ref.invalidate(plantsProvider);
  }

  Future<void> deletePlant(int plantId) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.deletePlant(plantId);
    _ref.invalidate(plantsProvider);
    _ref.invalidate(subareasProvider);
    _ref.invalidate(assetsWithDetailProvider);
  }

  Future<int> createSubarea({
    required int plantId,
    required String name,
    String category = 'TRANSFORMER',
  }) async {
    final dbService = _ref.read(databaseServiceProvider);
    final subarea = Subarea(plantId: plantId, name: name, category: category);
    final id = await dbService.insertSubarea(subarea);
    _ref.invalidate(subareasProvider);
    return id;
  }

  Future<void> updateSubarea(Subarea subarea) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.updateSubarea(subarea);
    _ref.invalidate(subareasProvider);
  }

  Future<void> deleteSubarea(int subareaId) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.deleteSubarea(subareaId);
    _ref.invalidate(subareasProvider);
    _ref.invalidate(assetsWithDetailProvider);
  }

  Future<int> saveAsset({
    required Asset asset,
    List<String>? channelNames,
    List<MeasurementChannel>? channels,
  }) async {
    final dbService = _ref.read(databaseServiceProvider);
    final id = await dbService.insertAsset(
      asset,
      channelNames: channelNames,
      channels: channels,
    );
    _ref.invalidate(assetsWithDetailProvider);
    return id;
  }

  Future<void> updateAsset(Asset asset, {List<String>? channelNames}) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.updateAsset(asset, channelNames: channelNames);
    _ref.invalidate(assetsWithDetailProvider);
    _ref.invalidate(assetDetailProvider(asset.id!));
  }

  Future<void> deleteRecord(int recordId, int assetId) async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.deleteRecord(recordId);
    _ref.invalidate(assetsWithDetailProvider);
    _ref.invalidate(assetHistoryProvider(assetId));
    _ref.invalidate(assetDetailProvider(assetId));
  }

  Future<void> reseedData() async {
    final dbService = _ref.read(databaseServiceProvider);
    await dbService.resetAndReseed();
    _ref.invalidate(plantsProvider);
    _ref.invalidate(subareasProvider);
    _ref.invalidate(assetsWithDetailProvider);
  }
}
