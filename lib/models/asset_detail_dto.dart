import 'asset.dart';
import 'measurement_channel.dart';
import 'record_with_values.dart';
import 'asset_status.dart';

class AssetDetailDto {
  final Asset asset;
  final List<MeasurementChannel> channels;
  final RecordWithValues? latestRecord;
  final AssetHealthStatus healthStatus;

  AssetDetailDto({
    required this.asset,
    required this.channels,
    this.latestRecord,
    required this.healthStatus,
  });

  factory AssetDetailDto.fromData({
    required Asset asset,
    required List<MeasurementChannel> channels,
    RecordWithValues? latestRecord,
    required DateTime systemNow,
  }) {
    final maxTemp = latestRecord?.maxTemperature;
    final deltaTemp = latestRecord?.deltaTemperature;
    final health = AssetHealthStatus.evaluate(
      maxTemp: maxTemp,
      deltaTemp: deltaTemp,
      warningLimit: asset.tempWarningLimit,
      tripLimit: asset.tempTripLimit,
      deltaTWarningLimit: asset.deltaTWarningLimit,
      deltaTTripLimit: asset.deltaTTripLimit,
      isCircuitBreaker: asset.isCircuitBreaker,
      specialStatus: latestRecord?.record.specialStatus,
      lastReadingDate: latestRecord?.record.readingDate,
      referenceDate: systemNow,
    );

    return AssetDetailDto(
      asset: asset,
      channels: channels,
      latestRecord: latestRecord,
      healthStatus: health,
    );
  }
}
