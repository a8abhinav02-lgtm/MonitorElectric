import 'temperature_record.dart';
import 'channel_value.dart';

class RecordWithValues {
  final TemperatureRecord record;
  final List<ChannelValue> channelValues;

  RecordWithValues({
    required this.record,
    required this.channelValues,
  });

  double? get maxTemperature {
    double? maxVal;
    for (final cv in channelValues) {
      if (cv.hasError == 0 && cv.temperatureVal != null) {
        if (maxVal == null || cv.temperatureVal! > maxVal) {
          maxVal = cv.temperatureVal;
        }
      }
    }
    return maxVal;
  }

  double? get minTemperature {
    double? minVal;
    for (final cv in channelValues) {
      if (cv.hasError == 0 && cv.temperatureVal != null) {
        if (minVal == null || cv.temperatureVal! < minVal) {
          minVal = cv.temperatureVal;
        }
      }
    }
    return minVal;
  }

  double? get deltaTemperature {
    final max = maxTemperature;
    final min = minTemperature;
    final validCount = channelValues.where((cv) => cv.hasError == 0 && cv.temperatureVal != null).length;
    if (max != null && min != null && validCount >= 2) {
      return max - min;
    }
    return null;
  }

  double? getValueForChannel(int channelId) {
    for (final cv in channelValues) {
      if (cv.channelId == channelId && cv.hasError == 0) {
        return cv.temperatureVal;
      }
    }
    return null;
  }

  bool isChannelError(int channelId) {
    for (final cv in channelValues) {
      if (cv.channelId == channelId) {
        return cv.hasError == 1 || cv.temperatureVal == null;
      }
    }
    return false;
  }
}
