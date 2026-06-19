import '../../../../models/car_setting_definition.dart';
import '../../common/basic_settings.dart';
import 'master_speed_common.dart';

final ms2Settings = CarSettingDefinition(
  carId: 'yokomo/ms2_0',
  availableSettings: [
    ...basicSettings,
    ...masterSpeedSpecificSettings(isMs2: true),
  ],
  isHumanVerified: true,
);
