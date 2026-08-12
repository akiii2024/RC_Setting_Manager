import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import 'master_speed_common.dart';

final ms2Settings = buildCarSettingDefinition(
  carId: 'yokomo/ms2_0',
  basicSettings: basicSettings,
  specificSettings: masterSpeedSpecificSettings(isMs2: true),
  isHumanVerified: false,
);
