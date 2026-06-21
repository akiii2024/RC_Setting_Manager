import '../models/run_log.dart';

int? parseBestLapMillis(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.contains(':')) {
    final parts = normalized.split(':');
    if (parts.length != 2) {
      return null;
    }

    final minutes = int.tryParse(parts[0]);
    final seconds = double.tryParse(parts[1]);
    if (minutes == null ||
        seconds == null ||
        minutes < 0 ||
        seconds < 0 ||
        seconds >= 60) {
      return null;
    }

    final totalSeconds = (minutes * 60) + seconds;
    if (totalSeconds <= 0) {
      return null;
    }
    return (totalSeconds * 1000).round();
  }

  final seconds = double.tryParse(normalized);
  if (seconds == null || seconds <= 0) {
    return null;
  }
  return (seconds * 1000).round();
}

String formatBestLapMillis(int millis) {
  if (millis <= 0) {
    return '-';
  }

  final totalSeconds = millis / 1000;
  if (totalSeconds >= 60) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds - (minutes * 60);
    return '$minutes:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
  }

  return totalSeconds.toStringAsFixed(2);
}

String formatRunConditions(RunLog runLog, bool isEnglish) {
  final parts = <String>[];

  if (runLog.airTempC != null) {
    parts.add(
      '${isEnglish ? "Air" : "気温"} ${_formatNumber(runLog.airTempC!)}°C',
    );
  }
  if (runLog.humidityPercent != null) {
    parts.add(
      '${isEnglish ? "Humidity" : "湿度"} ${_formatNumber(runLog.humidityPercent!)}%',
    );
  }
  final weatherCondition = runLog.weatherCondition.trim();
  if (weatherCondition.isNotEmpty) {
    parts.add('${isEnglish ? "Weather" : "天候"} $weatherCondition');
  }
  if (runLog.trackTempC != null) {
    parts.add(
      '${isEnglish ? "Track" : "路面"} ${_formatNumber(runLog.trackTempC!)}°C',
    );
  }

  final trackCondition = runLog.trackCondition.trim();
  if (trackCondition.isNotEmpty) {
    parts.add('${isEnglish ? "Track condition" : "路面状況"} $trackCondition');
  }

  return parts.join(' / ');
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}
