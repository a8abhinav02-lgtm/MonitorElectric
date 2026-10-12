import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/plant.dart';
import '../models/subarea.dart';
import '../models/asset.dart';
import '../models/measurement_channel.dart';
import '../models/temperature_record.dart';
import '../models/channel_value.dart';
import '../models/record_with_values.dart';
import 'database_seeder.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    // Si corre en Windows, Linux o macOS, inicializamos sqlite_common_ffi
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final docDir = await getApplicationSupportDirectory();
      path = join(docDir.path, 'termo_trafo_offline.db');
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'termo_trafo_offline.db');
    }

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Enforce Foreign Keys
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await DatabaseSeeder.seedInitialData(db);
      },
      onOpen: (db) async {
        // Garantizar eliminación de plantas de prueba legadas (M1, M4)
        await db.delete('plants', where: "code IN ('M1', 'M4')");
        // Migración de nombre de subárea a 'Transformadores' si existe
        await db.execute(
            "UPDATE subareas SET name = 'Transformadores' WHERE name = 'Patio de Transformadores';");
        // Eliminar subárea default no deseada
        await db.delete('subareas', where: "name LIKE '%Subestación Principal%'");

        // Migración retroactiva: asegurar columnas para soporte de interruptores
        try {
          await db.execute("ALTER TABLE subareas ADD COLUMN category TEXT NOT NULL DEFAULT 'TRANSFORMER';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN category TEXT NOT NULL DEFAULT 'TRANSFORMER';");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN voltage_level TEXT;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN rated_current_a REAL;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN mounting_type TEXT;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN delta_t_warning_limit REAL DEFAULT 10.0;");
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE assets ADD COLUMN delta_t_trip_limit REAL DEFAULT 15.0;");
        } catch (_) {}
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Plantas
    await db.execute('''
      CREATE TABLE plants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // 2. Subáreas (Transformadores o Interruptores)
    await db.execute('''
      CREATE TABLE subareas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plant_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT 'TRANSFORMER',
        FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
      );
    ''');

    // 3. Activos (Transformadores o Interruptores)
    await db.execute('''
      CREATE TABLE assets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subarea_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        secondary_tag TEXT,
        category TEXT NOT NULL DEFAULT 'TRANSFORMER',
        asset_type TEXT NOT NULL,
        insulation_class TEXT,
        rated_power_kva REAL,
        primary_voltage_kv REAL,
        voltage_level TEXT,
        rated_current_a REAL,
        mounting_type TEXT,
        temp_warning_limit REAL NOT NULL,
        temp_trip_limit REAL NOT NULL,
        delta_t_warning_limit REAL DEFAULT 10.0,
        delta_t_trip_limit REAL DEFAULT 15.0,
        FOREIGN KEY (subarea_id) REFERENCES subareas(id) ON DELETE CASCADE
      );
    ''');

    // 4. Canales de Medición
    await db.execute('''
      CREATE TABLE measurement_channels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        channel_name TEXT NOT NULL,
        probe_type TEXT DEFAULT 'PT100',
        FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
      );
    ''');

    // 5. Lecturas de Temperatura
    await db.execute('''
      CREATE TABLE temperature_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id INTEGER NOT NULL,
        reading_date DATETIME NOT NULL,
        recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        event_notes TEXT,
        special_status TEXT DEFAULT 'NONE',
        FOREIGN KEY (asset_id) REFERENCES assets(id) ON DELETE CASCADE
      );
    ''');

    // 6. Valores por Canal
    await db.execute('''
      CREATE TABLE channel_values (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        record_id INTEGER NOT NULL,
        channel_id INTEGER NOT NULL,
        temperature_val REAL NULL,
        has_error INTEGER DEFAULT 0,
        FOREIGN KEY (record_id) REFERENCES temperature_records(id) ON DELETE CASCADE,
        FOREIGN KEY (channel_id) REFERENCES measurement_channels(id)
      );
    ''');

    // Índices de optimización para consultas temporales
    await db.execute('''
      CREATE INDEX idx_records_asset_date 
      ON temperature_records (asset_id, reading_date DESC);
    ''');
  }

  // --- MÉTODOS DE CONSULTA Y PERSISTENCIA ---

  Future<List<Plant>> getPlants() async {
    final db = await database;
    final res = await db.query('plants', orderBy: 'code ASC');
    return res.map((e) => Plant.fromMap(e)).toList();
  }

  Future<List<Subarea>> getSubareasByPlant(int plantId) async {
    final db = await database;
    final res = await db.query('subareas',
        where: 'plant_id = ?', whereArgs: [plantId], orderBy: 'name ASC');
    return res.map((e) => Subarea.fromMap(e)).toList();
  }

  Future<List<Asset>> getAssetsBySubarea(int subareaId) async {
    final db = await database;
    final res = await db.query('assets',
        where: 'subarea_id = ?', whereArgs: [subareaId], orderBy: 'tag ASC');
    return res.map((e) => Asset.fromMap(e)).toList();
  }

  Future<Asset?> getAssetById(int assetId) async {
    final db = await database;
    final res = await db.query('assets', where: 'id = ?', whereArgs: [assetId]);
    if (res.isEmpty) return null;
    return Asset.fromMap(res.first);
  }

  Future<int> insertPlant(Plant plant) async {
    final db = await database;
    return await db.insert('plants', plant.toMap());
  }

  Future<int> updatePlant(Plant plant) async {
    final db = await database;
    return await db.update(
      'plants',
      plant.toMap(),
      where: 'id = ?',
      whereArgs: [plant.id],
    );
  }

  Future<int> deletePlant(int plantId) async {
    final db = await database;
    return await db.delete('plants', where: 'id = ?', whereArgs: [plantId]);
  }

  Future<int> insertSubarea(Subarea subarea) async {
    final db = await database;
    return await db.insert('subareas', subarea.toMap());
  }

  Future<int> updateSubarea(Subarea subarea) async {
    final db = await database;
    return await db.update(
      'subareas',
      subarea.toMap(),
      where: 'id = ?',
      whereArgs: [subarea.id],
    );
  }

  Future<int> deleteSubarea(int subareaId) async {
    final db = await database;
    return await db.delete('subareas', where: 'id = ?', whereArgs: [subareaId]);
  }

  Future<int> insertAsset(
    Asset asset, {
    List<String>? channelNames,
    List<MeasurementChannel>? channels,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final assetId = await txn.insert('assets', asset.toMap());
      if (channels != null && channels.isNotEmpty) {
        for (final ch in channels) {
          await txn.insert('measurement_channels', {
            'asset_id': assetId,
            'channel_name': ch.channelName,
            'probe_type': ch.probeType,
          });
        }
      } else {
        final names = channelNames ?? (asset.isCircuitBreaker ? ['L1 (R)', 'L2 (S)', 'L3 (T)'] : ['CH1', 'CH2', 'CH3', 'CH4']);
        for (final chName in names) {
          await txn.insert('measurement_channels', {
            'asset_id': assetId,
            'channel_name': chName,
            'probe_type': asset.isCircuitBreaker ? 'INFRARED' : 'PT100',
          });
        }
      }
      return assetId;
    });
  }

  Future<int> updateAsset(
    Asset asset, {
    List<String>? channelNames,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final res = await txn.update(
        'assets',
        asset.toMap(),
        where: 'id = ?',
        whereArgs: [asset.id],
      );
      if (channelNames != null && channelNames.isNotEmpty) {
        await txn.delete('measurement_channels', where: 'asset_id = ?', whereArgs: [asset.id]);
        for (final chName in channelNames) {
          await txn.insert('measurement_channels', {
            'asset_id': asset.id,
            'channel_name': chName,
            'probe_type': asset.isCircuitBreaker ? 'INFRARED' : 'PT100',
          });
        }
      }
      return res;
    });
  }

  Future<List<MeasurementChannel>> getChannelsForAsset(int assetId) async {
    final db = await database;
    final res = await db.query('measurement_channels',
        where: 'asset_id = ?', whereArgs: [assetId], orderBy: 'channel_name ASC');
    return res.map((e) => MeasurementChannel.fromMap(e)).toList();
  }

  Future<int> insertRecordWithValues({
    required TemperatureRecord record,
    required List<ChannelValue> values,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final recordId = await txn.insert('temperature_records', record.toMap());
      for (final val in values) {
        final valMap = val.copyWith(recordId: recordId).toMap();
        await txn.insert('channel_values', valMap);
      }
      return recordId;
    });
  }

  Future<void> updateRecordWithValues({
    required TemperatureRecord record,
    required List<ChannelValue> values,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'temperature_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );

      await txn.delete(
        'channel_values',
        where: 'record_id = ?',
        whereArgs: [record.id],
      );

      for (final val in values) {
        final valMap = val.copyWith(recordId: record.id).toMap();
        await txn.insert('channel_values', valMap);
      }
    });
  }

  Future<RecordWithValues?> getLatestRecordForAsset(int assetId) async {
    final db = await database;
    final res = await db.query(
      'temperature_records',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'reading_date DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    final record = TemperatureRecord.fromMap(res.first);
    final valuesRes = await db.query(
      'channel_values',
      where: 'record_id = ?',
      whereArgs: [record.id],
    );
    final values = valuesRes.map((e) => ChannelValue.fromMap(e)).toList();
    return RecordWithValues(record: record, channelValues: values);
  }

  Future<List<RecordWithValues>> getHistoricalRecordsForAsset(int assetId) async {
    final db = await database;
    final res = await db.query(
      'temperature_records',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      orderBy: 'reading_date ASC',
    );

    final List<RecordWithValues> result = [];
    for (final row in res) {
      final record = TemperatureRecord.fromMap(row);
      final valuesRes = await db.query(
        'channel_values',
        where: 'record_id = ?',
        whereArgs: [record.id],
      );
      final values = valuesRes.map((e) => ChannelValue.fromMap(e)).toList();
      result.add(RecordWithValues(record: record, channelValues: values));
    }
    return result;
  }

  Future<void> deleteRecord(int recordId) async {
    final db = await database;
    await db.delete('temperature_records', where: 'id = ?', whereArgs: [recordId]);
  }

  Future<void> resetAndReseed() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.execute('DELETE FROM plants;');
      await DatabaseSeeder.seedInitialData(txn);
    });
  }
}
