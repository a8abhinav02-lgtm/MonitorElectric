class Asset {
  final int? id;
  final int subareaId;
  final String tag;
  final String? secondaryTag;
  final String category; // 'TRANSFORMER' | 'CIRCUIT_BREAKER'
  final String assetType; // Para Trafo: 'DRY_TYPE' | 'OIL_IMMERSED'. Para Breaker: 'CIRCUIT_BREAKER'
  final String? insulationClass; // Para Trafo: 'CLASS_B' | 'CLASS_F' | 'CLASS_H' | 'STANDARD_OIL'
  final double? ratedPowerKva; // Para Trafo
  final double? primaryVoltageKv; // Tensión operativa en kV o V
  final String? voltageLevel; // Para Breaker: 'BT' | 'MT'
  final double? ratedCurrentA; // Para Breaker: In en Amperios
  final String? mountingType; // Para Breaker: 'FIXED' | 'DRAWOUT'
  final double tempWarningLimit;
  final double tempTripLimit;
  final double deltaTWarningLimit; // Umbral de desbalance térmico advertencia (10°C por defecto)
  final double deltaTTripLimit; // Umbral de desbalance térmico disparo (15°C por defecto)

  Asset({
    this.id,
    required this.subareaId,
    required this.tag,
    this.secondaryTag,
    this.category = 'TRANSFORMER',
    required this.assetType,
    this.insulationClass,
    this.ratedPowerKva,
    this.primaryVoltageKv,
    this.voltageLevel,
    this.ratedCurrentA,
    this.mountingType,
    required this.tempWarningLimit,
    required this.tempTripLimit,
    this.deltaTWarningLimit = 10.0,
    this.deltaTTripLimit = 15.0,
  });

  bool get isCircuitBreaker => category == 'CIRCUIT_BREAKER';
  bool get isTransformer => category == 'TRANSFORMER';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'subarea_id': subareaId,
      'tag': tag,
      'secondary_tag': secondaryTag,
      'category': category,
      'asset_type': assetType,
      'insulation_class': insulationClass,
      'rated_power_kva': ratedPowerKva,
      'primary_voltage_kv': primaryVoltageKv,
      'voltage_level': voltageLevel,
      'rated_current_a': ratedCurrentA,
      'mounting_type': mountingType,
      'temp_warning_limit': tempWarningLimit,
      'temp_trip_limit': tempTripLimit,
      'delta_t_warning_limit': deltaTWarningLimit,
      'delta_t_trip_limit': deltaTTripLimit,
    };
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as int?,
      subareaId: map['subarea_id'] as int,
      tag: map['tag'] as String,
      secondaryTag: map['secondary_tag'] as String?,
      category: (map['category'] as String?) ?? 'TRANSFORMER',
      assetType: (map['asset_type'] as String?) ?? 'DRY_TYPE',
      insulationClass: map['insulation_class'] as String?,
      ratedPowerKva: map['rated_power_kva'] != null
          ? (map['rated_power_kva'] as num).toDouble()
          : null,
      primaryVoltageKv: map['primary_voltage_kv'] != null
          ? (map['primary_voltage_kv'] as num).toDouble()
          : null,
      voltageLevel: map['voltage_level'] as String?,
      ratedCurrentA: map['rated_current_a'] != null
          ? (map['rated_current_a'] as num).toDouble()
          : null,
      mountingType: map['mounting_type'] as String?,
      tempWarningLimit: (map['temp_warning_limit'] as num).toDouble(),
      tempTripLimit: (map['temp_trip_limit'] as num).toDouble(),
      deltaTWarningLimit: map['delta_t_warning_limit'] != null
          ? (map['delta_t_warning_limit'] as num).toDouble()
          : 10.0,
      deltaTTripLimit: map['delta_t_trip_limit'] != null
          ? (map['delta_t_trip_limit'] as num).toDouble()
          : 15.0,
    );
  }

  Asset copyWith({
    int? id,
    int? subareaId,
    String? tag,
    String? secondaryTag,
    String? category,
    String? assetType,
    String? insulationClass,
    double? ratedPowerKva,
    double? primaryVoltageKv,
    String? voltageLevel,
    double? ratedCurrentA,
    String? mountingType,
    double? tempWarningLimit,
    double? tempTripLimit,
    double? deltaTWarningLimit,
    double? deltaTTripLimit,
  }) {
    return Asset(
      id: id ?? this.id,
      subareaId: subareaId ?? this.subareaId,
      tag: tag ?? this.tag,
      secondaryTag: secondaryTag ?? this.secondaryTag,
      category: category ?? this.category,
      assetType: assetType ?? this.assetType,
      insulationClass: insulationClass ?? this.insulationClass,
      ratedPowerKva: ratedPowerKva ?? this.ratedPowerKva,
      primaryVoltageKv: primaryVoltageKv ?? this.primaryVoltageKv,
      voltageLevel: voltageLevel ?? this.voltageLevel,
      ratedCurrentA: ratedCurrentA ?? this.ratedCurrentA,
      mountingType: mountingType ?? this.mountingType,
      tempWarningLimit: tempWarningLimit ?? this.tempWarningLimit,
      tempTripLimit: tempTripLimit ?? this.tempTripLimit,
      deltaTWarningLimit: deltaTWarningLimit ?? this.deltaTWarningLimit,
      deltaTTripLimit: deltaTTripLimit ?? this.deltaTTripLimit,
    );
  }
}
