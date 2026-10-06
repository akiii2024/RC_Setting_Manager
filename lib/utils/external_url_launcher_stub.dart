import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<void> openExternalUrl(String url, {Rect? sharePositionOrigin}) async {
  final result = await SharePlus.instance.share(
    ShareParams(text: url, sharePositionOrigin: sharePositionOrigin),
  );
  if (result.status == ShareResultStatus.unavailable) {
    throw StateError('URL sharing is unavailable.');
  }
}
