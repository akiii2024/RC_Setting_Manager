import 'signed_angle_input_field.dart';

/// キャンバーは符号なしの初期方向をネガティブにする。
class CamberInputField extends SignedAngleInputField {
  const CamberInputField({
    super.key,
    required super.settingKey,
    required super.onChanged,
    super.initialValue,
    super.unit,
    super.labelText,
    super.errorText,
    super.isEnglish = false,
  }) : super(
          negativeLabel: isEnglish ? 'Negative camber' : 'ネガティブキャンバー',
          positiveLabel: isEnglish ? 'Positive camber' : 'ポジティブキャンバー',
        );
}
