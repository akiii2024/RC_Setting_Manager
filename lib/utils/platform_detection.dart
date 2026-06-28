import 'package:flutter/foundation.dart';

bool isIOSWebPlatform({
  bool? isWeb,
  TargetPlatform? platform,
}) {
  return (isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
}
