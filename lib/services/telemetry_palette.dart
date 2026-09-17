import 'package:flutter/material.dart';

@immutable
class TelemetryPalette extends ThemeExtension<TelemetryPalette> {
  const TelemetryPalette({
    required this.series,
    required this.playhead,
    required this.brake,
    required this.course,
  });

  final List<Color> series;
  final Color playhead;
  final Color brake;
  final Color course;

  static const light = TelemetryPalette(
    series: [
      Color(0xFF3F56C5),
      Color(0xFF006B75),
      Color(0xFF8B5000),
      Color(0xFFA22B52),
      Color(0xFF66558F),
      Color(0xFF3E6255),
    ],
    playhead: Color(0xFFBA1A1A),
    brake: Color(0xFFA22B52),
    course: Color(0xFF006B75),
  );

  static const dark = TelemetryPalette(
    series: [
      Color(0xFFBCC3FF),
      Color(0xFF82D3DD),
      Color(0xFFFFB86B),
      Color(0xFFFFB0C8),
      Color(0xFFD1BCFF),
      Color(0xFFA8D7C4),
    ],
    playhead: Color(0xFFFFB4AB),
    brake: Color(0xFFFFB0C8),
    course: Color(0xFF82D3DD),
  );

  static TelemetryPalette of(BuildContext context) =>
      Theme.of(context).extension<TelemetryPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  TelemetryPalette copyWith(
          {List<Color>? series,
          Color? playhead,
          Color? brake,
          Color? course}) =>
      TelemetryPalette(
        series: series ?? this.series,
        playhead: playhead ?? this.playhead,
        brake: brake ?? this.brake,
        course: course ?? this.course,
      );

  @override
  TelemetryPalette lerp(covariant TelemetryPalette? other, double t) {
    if (other == null) return this;
    return TelemetryPalette(
      series: List.generate(
          series.length,
          (index) => Color.lerp(
              series[index], other.series[index % other.series.length], t)!),
      playhead: Color.lerp(playhead, other.playhead, t)!,
      brake: Color.lerp(brake, other.brake, t)!,
      course: Color.lerp(course, other.course, t)!,
    );
  }
}
