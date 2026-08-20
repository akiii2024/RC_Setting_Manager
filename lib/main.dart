import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app_bootstrap.dart';

export 'app/app.dart' show AuthWrapper, MyApp;

Future<void> main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  _registerFontLicenses();
  return bootstrapApplication();
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final notoSansJpLicense = await rootBundle.loadString(
      'assets/fonts/OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(
      const ['Noto Sans JP'],
      notoSansJpLicense,
    );

    final interLicense = await rootBundle.loadString(
      'assets/google_fonts/Inter-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['Inter'], interLicense);

    final spaceGroteskLicense = await rootBundle.loadString(
      'assets/google_fonts/SpaceGrotesk-OFL.txt',
    );
    yield LicenseEntryWithLineBreaks(
      const ['Space Grotesk'],
      spaceGroteskLicense,
    );
  });
}
