import '../../../../models/car_setting_definition.dart';
import '../../common/basic_settings.dart';
import 'master_speed_common.dart';

final ms1Settings = CarSettingDefinition(
  carId: 'yokomo/ms1_0',
  availableSettings: [
    ...basicSettings,
    ...masterSpeedSpecificSettings(isMs2: false),
  ],
  isHumanVerified: true,
);
