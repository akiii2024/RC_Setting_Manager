import 'package:google_fonts/google_fonts.dart';

import 'app/app_bootstrap.dart';
import 'app/third_party_licenses.dart';

export 'app/app.dart' show AuthWrapper, MyApp;

Future<void> main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  registerThirdPartyLicenses();
  return bootstrapApplication();
}
