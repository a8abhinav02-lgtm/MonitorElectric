class MeasurementChannel {
  final int? id;
  final int assetId;
  final String channelName;
  final String probeType;

  MeasurementChannel({
    this.id,
    required this.assetId,
    required this.channelName,
    this.probeType = 'PT100',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'asset_id': assetId,
      'channel_name': channelName,
      'probe_type': probeType,
    };
  }

  factory MeasurementChannel.fromMap(Map<String, dynamic> map) {
    return MeasurementChannel(
      id: map['id'] as int?,
      assetId: map['asset_id'] as int,
      channelName: map['channel_name'] as String,
      probeType: (map['probe_type'] as String?) ?? 'PT100',
    );
  }

  MeasurementChannel copyWith({
    int? id,
    int? assetId,
    String? channelName,
    String probeType = 'PT100',
  }) {
    return MeasurementChannel(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      channelName: channelName ?? this.channelName,
      probeType: probeType,
    );
  }
}
