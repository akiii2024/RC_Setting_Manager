import 'car_setting_definition.dart';

class VisibilitySettings {
  final String carId;
  final Map<String, bool> settingsVisibility;

  VisibilitySettings({
    required this.carId,
    required this.settingsVisibility,
  });

  // Deserialize from JSON
  factory VisibilitySettings.fromJson(Map<String, dynamic> json) {
    return VisibilitySettings(
      carId: json['carId'] as String,
      settingsVisibility:
          Map<String, bool>.from(json['settingsVisibility'] as Map),
    );
  }

  // Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'carId': carId,
      'settingsVisibility': settingsVisibility,
    };
  }

  // 車種固有の設定項目に対応した標準的な表示設定を全てtrueで作成
  factory VisibilitySettings.createDefault(String carId,
      {List<String>? availableSettings}) {
    // 車種固有の設定項目がある場合はそれを使用
    if (availableSettings != null && availableSettings.isNotEmpty) {
      Map<String, bool> visibility = {};
      for (var setting in availableSettings) {
        visibility[setting] = true;
      }
      return VisibilitySettings(
        carId: carId,
        settingsVisibility: visibility,
      );
    }

    // そうでない場合は従来通りの設定項目リストを使用
    return VisibilitySettings(
      carId: carId,
      settingsVisibility: {
        // Basic Information
        'date': true,
        'track': true,
        'surface': true,
        'airTemp': true,
        'humidity': true,
        'trackTemp': true,
        'condition': true,

        // Front Settings
        'frontCamber': true,
        'frontRideHeight': true,
        'frontDamperPosition': true,
        'frontSpring': true,
        'frontToe': true,

        // Front Detailed Settings
        'frontUpperArmSpacer': true,
        'frontUpperArmSpacerInside': true,
        'frontUpperArmSpacerOutside': true,
        'frontLowerArmSpacer': true,
        'frontWheelHub': true,
        'frontWheelHubSpacer': true,
        'frontDroop': true,
        'frontDiffarentialPosition': true,
        'frontSusMountFront': true,
        'frontSusMountRear': true,
        'frontSusMountFrontShaftPosition': true,
        'frontSusMountRearShaftPosition': true,
        'frontCasterAngle': true,
        'frontStabilizer': true,
        'frontDrive': true,
        'frontDifferentialOil': true,
        'frontDumperPosition': true,

        // Front Damper Settings
        'frontDamperOffsetStay': true,
        'frontDamperOffsetArm': true,
        'frontDumperType': true,
        'frontDumperOilSeal': true,
        'frontDumperPistonSize': true,
        'frontDumperPistonHole': true,
        'frontDumperOilHardness': true,
        'frontDumperOilName': true,
        'frontDumperStroke': true,
        'frontDumperAirHole': true,

        // Rear Settings
        'rearCamber': true,
        'rearRideHeight': true,
        'rearDamperPosition': true,
        'rearSpring': true,
        'rearToe': true,

        // Rear Detailed Settings
        'rearUpperArmSpacer': true,
        'rearUpperArmSpacerInside': true,
        'rearUpperArmSpacerOutside': true,
        'rearLowerArmSpacer': true,
        'rearWheelHub': true,
        'rearWheelHubSpacer': true,
        'rearDroop': true,
        'rearDiffarentialPosition': true,
        'rearSusMountFront': true,
        'rearSusMountRear': true,
        'rearSusMountFrontShaftPosition': true,
        'rearSusMountRearShaftPosition': true,
        'rearStabilizer': true,
        'rearDrive': true,
        'rearDifferentialOil': true,
        'rearDumperPosition': true,

        // Rear Damper Settings
        'rearDamperOffsetStay': true,
        'rearDamperOffsetArm': true,
        'rearDumperType': true,
        'rearDumperOilSeal': true,
        'rearDumperPistonSize': true,
        'rearDumperPistonHole': true,
        'rearDumperOilHardness': true,
        'rearDumperOilName': true,
        'rearDumperStroke': true,
        'rearDumperAirHole': true,

        // Top Settings
        'upperDeckScrewPosition': true,
        'upperDeckflexType': true,
        'ballastFrontRight': true,
        'ballastFrontLeft': true,
        'ballastMiddle': true,
        'ballastBattery': true,

        // Top Detailed Settings
        'knucklearmType': true,
        'kuncklearmUprightSpacer': true,
        'steeringPivot': true,
        'steeringSpacer': true,
        'frontSuspensionArmSpacer': true,
        'rearSuspensionType': true,
        'rearSuspensionArmSpacer': true,
        'lowerDeckThickness': true,
        'lowerDeckMaterial': true,

        // Other Settings
        'motor': true,
        'spurGear': true,
        'pinionGear': true,
        'battery': true,
        'body': true,
        'bodyWeight': true,
        'wing': true,
        'frontBodyMountHolePosition': true,
        'rearBodyMountHolePosition': true,
        'tire': true,
        'wheel': true,
        'tireInner': true,

        // TRF421固有の設定項目
        'frontSusMountPosition': true,
        'rearSusMountPosition': true,
        'frontSuspensionArmThickness': true,
        'rearSuspensionArmThickness': true,
      },
    );
  }
}
