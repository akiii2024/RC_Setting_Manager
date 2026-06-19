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
