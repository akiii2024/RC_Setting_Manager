import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fonts and supplemental notices that Flutter does not collect automatically.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(() async* {
    const licenses = <String, List<String>>{
      'assets/fonts/OFL.txt': ['Noto Sans JP'],
      'assets/google_fonts/Inter-OFL.txt': ['Inter'],
      'assets/google_fonts/SpaceGrotesk-OFL.txt': ['Space Grotesk'],
      'assets/licenses/image-LICENSE-other.md': ['image'],
      'assets/licenses/archive-LICENSE-other.md': ['archive'],
      'assets/licenses/Apache-2.0.txt': ['image'],
    };
    for (final entry in licenses.entries) {
      yield LicenseEntryWithLineBreaks(
        entry.value,
        await rootBundle.loadString(entry.key),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      yield LicenseEntryWithLineBreaks(
        const ['Android native SDKs'],
        await rootBundle.loadString('assets/licenses/android_native.txt'),
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      const asset = 'assets/licenses/ios_native.txt';
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      if (manifest.listAssets().contains(asset)) {
        yield LicenseEntryWithLineBreaks(
          const ['Apple native SDKs'],
          await rootBundle.loadString(asset),
        );
      }
    }
  });
}
