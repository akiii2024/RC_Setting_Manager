import 'package:flutter/material.dart';

import '../utils/external_url_launcher.dart';

/// Attribution required when displaying weather data from OpenWeather.
class OpenWeatherAttribution extends StatelessWidget {
  const OpenWeatherAttribution({super.key, this.onOpenUrl});

  static const String url = 'https://openweathermap.org/';

  /// Injectable for widget tests; production opens an HTTPS browser link.
  final Future<void> Function(String url)? onOpenUrl;

  Future<void> _openUrl(BuildContext context) async {
    try {
      await (onOpenUrl ?? openWebUrl)(url);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(Localizations.localeOf(context).languageCode == 'en'
                ? 'Could not open the link.'
                : 'リンクを開けませんでした。'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final linkStyle = textStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    return Semantics(
      container: true,
      label: 'Weather data provided by OpenWeather',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            SizedBox(
              width: 128,
              child: AspectRatio(
                aspectRatio: 600 / 340,
                // OpenWeather's official logo is provided on a white canvas;
                // retain that canvas so the brand remains readable in dark UI.
                child: ColoredBox(
                  color: Colors.white,
                  child: Image.asset(
                    'assets/attribution/openweather.png',
                    fit: BoxFit.contain,
                    semanticLabel: 'OpenWeather logo',
                  ),
                ),
              ),
            ),
            Text('Weather data provided by OpenWeather', style: textStyle),
            Semantics(
              link: true,
              label: url,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: InkWell(
                  onTap: () => _openUrl(context),
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(url, style: linkStyle),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
