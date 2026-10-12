class ChannelValue {
  final int? id;
  final int recordId;
  final int channelId;
  final double? temperatureVal;
  final int hasError; // 0: Normal, 1: Error RTD

  ChannelValue({
    this.id,
    required this.recordId,
    required this.channelId,
    this.temperatureVal,
    this.hasError = 0,
  });

  bool get isFaulty => hasError == 1 || temperatureVal == null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'record_id': recordId,
      'channel_id': channelId,
      'temperature_val': temperatureVal,
      'has_error': hasError,
    };
  }

  factory ChannelValue.fromMap(Map<String, dynamic> map) {
    return ChannelValue(
      id: map['id'] as int?,
      recordId: map['record_id'] as int,
      channelId: map['channel_id'] as int,
      temperatureVal: map['temperature_val'] != null
          ? (map['temperature_val'] as num).toDouble()
          : null,
      hasError: (map['has_error'] as int?) ?? 0,
    );
  }

  ChannelValue copyWith({
    int? id,
    int? recordId,
    int? channelId,
    double? temperatureVal,
    int? hasError,
  }) {
    return ChannelValue(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      channelId: channelId ?? this.channelId,
      temperatureVal: temperatureVal ?? this.temperatureVal,
      hasError: hasError ?? this.hasError,
    );
  }
}
