import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Opens attribution hyperlinks in a browser on Android and iOS.
Future<void> openWebUrl(String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' || uri.host.isEmpty) {
    throw ArgumentError.value(url, 'url', 'An HTTPS URL is required.');
  }
  await const MethodChannel('com.aki.rcsettings/external_links')
      .invokeMethod<void>('openUrl', {'url': uri.toString()});
}

Future<void> openExternalUrl(String url, {Rect? sharePositionOrigin}) async {
  final result = await SharePlus.instance.share(
    ShareParams(text: url, sharePositionOrigin: sharePositionOrigin),
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('URL sharing is unavailable.');
  }
}
