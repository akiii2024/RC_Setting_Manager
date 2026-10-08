import 'package:flutter/services.dart';

class AppMetadata {
  const AppMetadata._();

  static Future<String> loadVersion() async {
    final pubspec = await rootBundle.loadString('pubspec.yaml');
    return parseVersion(pubspec);
  }

  static String parseVersion(String pubspec) {
    final match = RegExp(r'^version:[ \t]*([^#\r\n]*)', multiLine: true)
        .firstMatch(pubspec);
    var version = match?.group(1)?.trim() ?? '';
    if (version.length >= 2 &&
        ((version.startsWith("'") && version.endsWith("'")) ||
            (version.startsWith('"') && version.endsWith('"')))) {
      version = version.substring(1, version.length - 1);
    }
    if (version.isEmpty) {
      throw StateError('Version is missing from pubspec.yaml');
    }
    return version;
  }
}
