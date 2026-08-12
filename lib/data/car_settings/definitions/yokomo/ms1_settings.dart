import '../../common/basic_settings.dart';
import '../common/car_definition_builder.dart';
import 'master_speed_common.dart';

final ms1Settings = buildCarSettingDefinition(
  carId: 'yokomo/ms1_0',
  basicSettings: basicSettings,
  specificSettings: masterSpeedSpecificSettings(isMs2: false),
  isHumanVerified: false,
);
