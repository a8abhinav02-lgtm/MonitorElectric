import 'package:sqflite/sqflite.dart';

class DatabaseSeeder {
  static Future<void> seedInitialData(DatabaseExecutor db) async {
    // 1. Planta PPL (Planta Principal) única
    final plantId = await db.insert('plants', {
      'code': 'PPL',
      'name': 'Planta Principal',
      'created_at': DateTime(2025, 1, 1).toIso8601String(),
    });

    // 2. Subárea: Transformadores
    final subareaId = await db.insert('subareas', {
      'plant_id': plantId,
      'name': 'Transformadores',
    });



    // 3. Activos: T3-3, T3-4, T3-5, T3-6 (50EN07), T3-7, T3-20
    final assetsData = [
      {
        'tag': 'T3-3',
        'secondary_tag': null,
        'asset_type': 'OIL_IMMERSED',
        'insulation_class': 'STANDARD_OIL',
        'rated_power_kva': 2500.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 85.0,
        'temp_trip_limit': 100.0,
      },
      {
        'tag': 'T3-4',
        'secondary_tag': null,
        'asset_type': 'DRY_TYPE',
        'insulation_class': 'CLASS_F',
        'rated_power_kva': 1500.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 130.0,
        'temp_trip_limit': 150.0,
      },
      {
        'tag': 'T3-5',
        'secondary_tag': null,
        'asset_type': 'OIL_IMMERSED',
        'insulation_class': 'STANDARD_OIL',
        'rated_power_kva': 2000.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 85.0,
        'temp_trip_limit': 100.0,
      },
      {
        'tag': 'T3-6',
        'secondary_tag': '50EN07',
        'asset_type': 'OIL_IMMERSED',
        'insulation_class': 'STANDARD_OIL',
        'rated_power_kva': 3000.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 85.0,
        'temp_trip_limit': 100.0,
      },
      {
        'tag': 'T3-7',
        'secondary_tag': null,
        'asset_type': 'OIL_IMMERSED',
        'insulation_class': 'STANDARD_OIL',
        'rated_power_kva': 2500.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 85.0,
        'temp_trip_limit': 100.0,
      },
      {
        'tag': 'T3-20',
        'secondary_tag': null,
        'asset_type': 'OIL_IMMERSED',
        'insulation_class': 'STANDARD_OIL',
        'rated_power_kva': 1500.0,
        'primary_voltage_kv': 13.8,
        'temp_warning_limit': 85.0,
        'temp_trip_limit': 100.0,
      },
    ];

    final Map<String, int> assetMap = {};
    final Map<String, List<int>> channelsMap = {};

    for (final a in assetsData) {
      final aId = await db.insert('assets', {
        'subarea_id': subareaId,
        'tag': a['tag'],
        'secondary_tag': a['secondary_tag'],
        'asset_type': a['asset_type'],
        'insulation_class': a['insulation_class'],
        'rated_power_kva': a['rated_power_kva'],
        'primary_voltage_kv': a['primary_voltage_kv'],
        'temp_warning_limit': a['temp_warning_limit'],
        'temp_trip_limit': a['temp_trip_limit'],
      });
      assetMap[a['tag'] as String] = aId;

      // Crear CH1, CH2, CH3
      final ch1Id = await db.insert('measurement_channels', {
        'asset_id': aId,
        'channel_name': 'CH1',
        'probe_type': 'PT100',
      });
      final ch2Id = await db.insert('measurement_channels', {
        'asset_id': aId,
        'channel_name': 'CH2',
        'probe_type': 'PT100',
      });
      final ch3Id = await db.insert('measurement_channels', {
        'asset_id': aId,
        'channel_name': 'CH3',
        'probe_type': 'PT100',
      });
      channelsMap[a['tag'] as String] = [ch1Id, ch2Id, ch3Id];
    }

    // Helper para insertar registro y canales
    Future<void> addRecord({
      required String tag,
      required DateTime date,
      double? ch1,
      double? ch2,
      double? ch3,
      bool ch1Error = false,
      bool ch2Error = false,
      bool ch3Error = false,
      String? notes,
      String specialStatus = 'NONE',
    }) async {
      final aId = assetMap[tag]!;
      final chs = channelsMap[tag]!;

      final recId = await db.insert('temperature_records', {
        'asset_id': aId,
        'reading_date': date.toIso8601String(),
        'recorded_at': date.toIso8601String(),
        'event_notes': notes,
        'special_status': specialStatus,
      });

      // CH1
      await db.insert('channel_values', {
        'record_id': recId,
        'channel_id': chs[0],
        'temperature_val': ch1Error ? null : ch1,
        'has_error': ch1Error ? 1 : 0,
      });
      // CH2
      await db.insert('channel_values', {
        'record_id': recId,
        'channel_id': chs[1],
        'temperature_val': ch2Error ? null : ch2,
        'has_error': ch2Error ? 1 : 0,
      });
      // CH3
      await db.insert('channel_values', {
        'record_id': recId,
        'channel_id': chs[2],
        'temperature_val': ch3Error ? null : ch3,
        'has_error': ch3Error ? 1 : 0,
      });
    }

    // --- 1. HISTORIAL T3-3 ---
    await addRecord(tag: 'T3-3', date: DateTime(2025, 1, 15), ch1: 86, ch2: 89, ch3: 86, notes: 'Provisional inicial');
    await addRecord(tag: 'T3-3', date: DateTime(2025, 3, 25), ch1: 84, ch2: 88, ch3: 85);
    await addRecord(tag: 'T3-3', date: DateTime(2025, 5, 14), ch1: 81, ch2: 84, ch3: 82);
    await addRecord(tag: 'T3-3', date: DateTime(2025, 8, 12), ch1: 88, ch2: 93, ch3: 90);
    await addRecord(tag: 'T3-3', date: DateTime(2025, 11, 27), ch1: 90, ch2: 95, ch3: 90);
    await addRecord(tag: 'T3-3', date: DateTime(2026, 1, 5), ch1: 90, ch2: 95, ch3: 92);
    await addRecord(tag: 'T3-3', date: DateTime(2026, 1, 26), ch1: 70, ch2: 85, ch3: 77);
    await addRecord(
      tag: 'T3-3',
      date: DateTime(2026, 4, 29),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'FOC_FAULT',
      notes: 'Display en falla "FOc"',
    );
    await addRecord(
      tag: 'T3-3',
      date: DateTime(2026, 6, 10),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'FOC_FAULT',
      notes: 'Display en falla "FOC"',
    );

    // --- 2. HISTORIAL T3-4 ---
    await addRecord(tag: 'T3-4', date: DateTime(2025, 2, 7), ch1: 48, ch2: 53, ch3: 52);
    await addRecord(tag: 'T3-4', date: DateTime(2025, 4, 15), ch1: 53, ch2: 58, ch3: 56, notes: 'Provisional');
    await addRecord(
      tag: 'T3-4',
      date: DateTime(2025, 6, 20),
      ch1: 57,
      ch2: 62,
      ch3: 60,
      notes: '30S207, 30S107 Bloqueo compuerta, 30QL07',
    );
    await addRecord(tag: 'T3-4', date: DateTime(2025, 7, 17), ch1: 59, ch2: 62, ch3: 63);
    await addRecord(tag: 'T3-4', date: DateTime(2025, 8, 13), ch1: 54, ch2: 60, ch3: 57);
    await addRecord(tag: 'T3-4', date: DateTime(2025, 11, 6), ch1: 62, ch2: 68, ch3: 65);
    await addRecord(tag: 'T3-4', date: DateTime(2026, 1, 5), ch1: 52, ch2: 57, ch3: 54);
    await addRecord(tag: 'T3-4', date: DateTime(2026, 4, 29), ch1: 63, ch2: 70, ch3: 66);
    await addRecord(tag: 'T3-4', date: DateTime(2026, 6, 10), ch1: 52, ch2: 58, ch3: 55);
    await addRecord(tag: 'T3-4', date: DateTime(2026, 7, 6), ch1: 68, ch2: 70, ch3: 83);
    await addRecord(tag: 'T3-4', date: DateTime(2026, 8, 31), ch1: 67, ch2: 72, ch3: 70);

    // --- 3. HISTORIAL T3-5 ---
    await addRecord(tag: 'T3-5', date: DateTime(2025, 2, 7), ch1: 50, ch2: 56, ch3: 52);
    await addRecord(tag: 'T3-5', date: DateTime(2025, 4, 15), ch1: 50, ch2: 55, ch3: 52, notes: 'Provisional');
    await addRecord(tag: 'T3-5', date: DateTime(2025, 6, 20), ch1: 57, ch2: 63, ch3: 59);
    await addRecord(tag: 'T3-5', date: DateTime(2025, 7, 17), ch1: 55, ch2: 62, ch3: 58);
    await addRecord(tag: 'T3-5', date: DateTime(2025, 8, 13), ch1: 55, ch2: 60, ch3: 56);
    await addRecord(tag: 'T3-5', date: DateTime(2025, 11, 6), ch1: 58, ch2: 59, ch3: 63);
    await addRecord(tag: 'T3-5', date: DateTime(2026, 1, 5), ch1: 50, ch2: 54, ch3: 50);
    await addRecord(
      tag: 'T3-5',
      date: DateTime(2026, 4, 29),
      ch1: 88,
      ch2: 94,
      ch3: 87,
      notes: 'Pico de sobretemperatura en devanados',
    );
    await addRecord(tag: 'T3-5', date: DateTime(2026, 6, 10), ch1: 49, ch2: 54, ch3: 50);
    await addRecord(tag: 'T3-5', date: DateTime(2026, 7, 6), ch1: 60, ch2: 64, ch3: 59);
    await addRecord(tag: 'T3-5', date: DateTime(2026, 8, 31), ch1: 59, ch2: 63, ch3: 58);

    // --- 4. HISTORIAL T3-6 (50EN07) ---
    await addRecord(tag: 'T3-6', date: DateTime(2025, 2, 7), ch1: 72, ch2: 91, ch3: 82);
    await addRecord(tag: 'T3-6', date: DateTime(2025, 5, 29), ch1: 61, ch2: 82, ch3: 77);
    await addRecord(tag: 'T3-6', date: DateTime(2025, 8, 15), ch1: 83, ch2: 86, ch3: 81, notes: 'Provisional');
    await addRecord(
      tag: 'T3-6',
      date: DateTime(2025, 11, 27),
      ch1: 62,
      ch2: 74,
      ch3: 67,
      notes: 'Fuerte ruido contactor 50lv51',
    );
    await addRecord(
      tag: 'T3-6',
      date: DateTime(2026, 4, 29),
      ch1: 97,
      ch2: 118,
      ch3: 105,
      notes: 'Pico crítico extremo. Alarma Trip activada',
    );
    await addRecord(tag: 'T3-6', date: DateTime(2026, 6, 10), ch1: 73, ch2: 86, ch3: 77);
    await addRecord(tag: 'T3-6', date: DateTime(2026, 7, 20), ch1: 77, ch2: 92, ch3: 83, notes: 'Provisional');
    await addRecord(tag: 'T3-6', date: DateTime(2026, 9, 23), ch1: 70, ch2: 82, ch3: 74);

    // --- 5. HISTORIAL T3-7 ---
    await addRecord(tag: 'T3-7', date: DateTime(2025, 2, 7), ch1: 56, ch2: 55, ch3: 59, notes: 'Provisional');
    await addRecord(tag: 'T3-7', date: DateTime(2025, 6, 20), ch1: 48, ch2: 49, ch3: 54);
    await addRecord(tag: 'T3-7', date: DateTime(2025, 7, 17), ch1: 44, ch2: 45, ch3: 49);
    await addRecord(tag: 'T3-7', date: DateTime(2025, 8, 13), ch1: 44, ch2: 45, ch3: 49);
    await addRecord(
      tag: 'T3-7',
      date: DateTime(2025, 11, 6),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'DISPLAY_OFF',
      notes: 'Display fuera de servicio',
    );
    await addRecord(
      tag: 'T3-7',
      date: DateTime(2026, 1, 5),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'DISPLAY_OFF',
      notes: 'Display apagado',
    );
    await addRecord(tag: 'T3-7', date: DateTime(2026, 4, 29), ch1: 39, ch2: 39, ch3: 41);
    await addRecord(tag: 'T3-7', date: DateTime(2026, 6, 10), ch1: 83, ch2: 84, ch3: 87);
    await addRecord(tag: 'T3-7', date: DateTime(2026, 8, 31), ch1: 51, ch2: 50, ch3: 53);

    // --- 6. HISTORIAL T3-20 ---
    await addRecord(tag: 'T3-20', date: DateTime(2025, 1, 15), ch1: 43, ch2: 48, ch3: 48, notes: 'Provisional');
    await addRecord(tag: 'T3-20', date: DateTime(2025, 2, 7), ch1: 49, ch2: 50, ch3: 54);
    await addRecord(
      tag: 'T3-20',
      date: DateTime(2025, 5, 14),
      ch1: 51,
      ch2: 56,
      ch3: null,
      ch3Error: true,
      notes: 'Sensor RTD en error en CH3',
    );
    await addRecord(
      tag: 'T3-20',
      date: DateTime(2026, 4, 29),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'DISPLAY_OFF',
      notes: 'Monitor temperatura apagado',
    );
    await addRecord(
      tag: 'T3-20',
      date: DateTime(2026, 6, 10),
      ch1: null,
      ch2: null,
      ch3: null,
      specialStatus: 'DISPLAY_OFF',
      notes: 'Display apagado',
    );
  }
}
