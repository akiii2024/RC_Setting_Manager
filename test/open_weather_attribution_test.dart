import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rc_setting_manager/widgets/open_weather_attribution.dart';

void main() {
  testWidgets('shows OpenWeather attribution and opens its URL',
      (tester) async {
    String? openedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenWeatherAttribution(
            onOpenUrl: (url) async => openedUrl = url,
          ),
        ),
      ),
    );

    expect(find.text('Weather data provided by OpenWeather'), findsOneWidget);
    expect(find.text(OpenWeatherAttribution.url), findsOneWidget);
    expect(find.bySemanticsLabel('OpenWeather logo'), findsOneWidget);

    await tester.tap(find.text(OpenWeatherAttribution.url));
    await tester.pump();

    expect(openedUrl, OpenWeatherAttribution.url);
  });

  testWidgets('wraps attribution at narrow width and follows dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Scaffold(
            body: SizedBox(
              width: 360,
              child: OpenWeatherAttribution(),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(OpenWeatherAttribution), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a recoverable message when opening the link fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenWeatherAttribution(
            onOpenUrl: (_) async => throw StateError('unavailable'),
          ),
        ),
      ),
    );

    await tester.tap(find.text(OpenWeatherAttribution.url));
    await tester.pump();

    expect(find.text('Could not open the link.'), findsOneWidget);
  });
}
