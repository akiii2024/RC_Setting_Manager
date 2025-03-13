class VisibilitySettings {
  final String carId;
  final Map<String, bool> settingsVisibility;

  VisibilitySettings({
    required this.carId,
    required this.settingsVisibility,
  });

  // JSONからのデシリアライズ
  factory VisibilitySettings.fromJson(Map<String, dynamic> json) {
    return VisibilitySettings(
      carId: json['carId'] as String,
      settingsVisibility:
          Map<String, bool>.from(json['settingsVisibility'] as Map),
    );
  }

  // JSONへのシリアライズ
  Map<String, dynamic> toJson() {
    return {
      'carId': carId,
      'settingsVisibility': settingsVisibility,
    };
  }

  // デフォルトの可視性設定を作成
  factory VisibilitySettings.createDefault(String carId) {
    return VisibilitySettings(
      carId: carId,
      settingsVisibility: {
        // 基本情報
        'date': true,
        'track': true,
        'surface': true,
        'airTemp': true,
        'humidity': true,
        'trackTemp': true,
        'condition': true,

        // フロント設定
        'frontCamber': true,
        'frontRideHeight': true,
        'frontDamperPosition': true,
        'frontSpring': true,
        'frontToe': true,

        // フロント詳細設定
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

        //フロントダンパー設定
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

        // リア設定
        'rearCamber': true,
        'rearRideHeight': true,
        'rearDamperPosition': true,
        'rearSpring': true,
        'rearToe': true,

        // リア詳細設定
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

        // リアダンパー設定
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

        // トップ設定
        'upperDeckScrewPosition': true,
        'upperDeckflexType': true,
        'ballastFrontRight': true,
        'ballastFrontLeft': true,
        'ballastMiddle': true,
        'ballastBattery': true,

        //トップ詳細設定
        'knucklearmType': true,
        'kuncklearmUprightSpacer': true,
        'steeringPivot': true,
        'steeringSpacer': true,
        'frontSuspensionArmSpacer': true,
        'rearSuspensionType': true,
        'rearSuspensionArmSpacer': true,
        'lowerDeckThickness': true,
        'lowerDeckMaterial': true,

        //その他設定
        'motor': true,
        'spurGear': true,
        'pinionGear': true,
        'battery': true,
        'body': true,
        'bodyWeight': true,
        'frontBodyMountHolePosition': true,
        'rearBodyMountHolePosition': true,
        'wing': true,
        'tire': true,
        'wheel': true,
        'tireInsert': true,
      },
    );
  }
}
