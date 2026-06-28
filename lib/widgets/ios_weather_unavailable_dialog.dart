import 'package:flutter/material.dart';

Future<void> showIOSWeatherUnavailableDialog(
  BuildContext context, {
  required bool isEnglish,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        isEnglish ? 'Weather information is unavailable' : '天気情報を取得できません',
      ),
      content: Text(
        isEnglish
            ? 'Automatic weather retrieval is currently unavailable on the '
                'iOS version. Please enter the temperature and humidity '
                'manually.'
            : 'iOS版では現在、天気情報の自動取得を利用できません。'
                '気温と湿度は手動で入力してください。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(isEnglish ? 'OK' : '閉じる'),
        ),
      ],
    ),
  );
}
