class TemperatureRecord {
  final int? id;
  final int assetId;
  final DateTime readingDate;
  final DateTime recordedAt;
  final String? eventNotes;
  final String specialStatus; // 'NONE' | 'FOC_FAULT' | 'DISPLAY_OFF' | 'RTD_ERROR'

  TemperatureRecord({
    this.id,
    required this.assetId,
    required this.readingDate,
    DateTime? recordedAt,
    this.eventNotes,
    this.specialStatus = 'NONE',
  }) : recordedAt = recordedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'asset_id': assetId,
      'reading_date': readingDate.toIso8601String(),
      'recorded_at': recordedAt.toIso8601String(),
      'event_notes': eventNotes,
      'special_status': specialStatus,
    };
  }

  factory TemperatureRecord.fromMap(Map<String, dynamic> map) {
    return TemperatureRecord(
      id: map['id'] as int?,
      assetId: map['asset_id'] as int,
      readingDate: map['reading_date'] != null
          ? DateTime.tryParse(map['reading_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      recordedAt: map['recorded_at'] != null
          ? DateTime.tryParse(map['recorded_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      eventNotes: map['event_notes'] as String?,
      specialStatus: (map['special_status'] as String?) ?? 'NONE',
    );
  }

  TemperatureRecord copyWith({
    int? id,
    int? assetId,
    DateTime? readingDate,
    DateTime? recordedAt,
    String? eventNotes,
    String? specialStatus,
  }) {
    return TemperatureRecord(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      readingDate: readingDate ?? this.readingDate,
      recordedAt: recordedAt ?? this.recordedAt,
      eventNotes: eventNotes ?? this.eventNotes,
      specialStatus: specialStatus ?? this.specialStatus,
    );
  }
}
