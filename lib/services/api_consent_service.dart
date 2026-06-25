import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ApiConsentType {
  weatherAndLocation,
  aiAndOcr,
}

class ApiConsentService {
  ApiConsentService._();

  static const String _weatherAndLocationConsentKey =
      'weather_location_api_consent_v1';
  static const String _aiAndOcrConsentKey = 'gemini_api_consent_v1';

  static final Map<ApiConsentType, Future<bool>> _pendingRequests = {};

  static String _preferenceKey(ApiConsentType type) {
    return switch (type) {
      ApiConsentType.weatherAndLocation => _weatherAndLocationConsentKey,
      ApiConsentType.aiAndOcr => _aiAndOcrConsentKey,
    };
  }

  static Future<bool> hasConsent(ApiConsentType type) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_preferenceKey(type)) ?? false;
  }

  static Future<void> grantConsent(ApiConsentType type) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey(type), true);
  }

  static Future<void> revokeConsent(ApiConsentType type) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_preferenceKey(type));
  }

  static Future<bool> requestConsent(
    BuildContext context, {
    required ApiConsentType type,
    required bool isEnglish,
  }) async {
    if (await hasConsent(type)) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }

    final pendingRequest = _pendingRequests[type];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _showConsentDialog(
      context,
      type: type,
      isEnglish: isEnglish,
    );
    _pendingRequests[type] = request;

    try {
      return await request;
    } finally {
      if (identical(_pendingRequests[type], request)) {
        _pendingRequests.remove(type);
      }
    }
  }

  static Future<bool> _showConsentDialog(
    BuildContext context, {
    required ApiConsentType type,
    required bool isEnglish,
  }) async {
    if (!context.mounted) {
      return false;
    }

    final accepted = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(_icon(type)),
            title: Text(_title(type, isEnglish)),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_introduction(type, isEnglish)),
                    const SizedBox(height: 16),
                    for (final item in _details(type, isEnglish))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(item)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? 'This confirmation is shown only the first time. '
                              'If you cancel, no related API request will be sent.'
                          : 'この確認は初回のみ表示されます。キャンセルした場合、'
                              '関連するAPI通信は行いません。',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(isEnglish ? 'Cancel' : 'キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isEnglish ? 'Agree and continue' : '同意して続ける'),
              ),
            ],
          ),
        ) ??
        false;

    if (accepted) {
      await grantConsent(type);
    }
    return accepted;
  }

  static IconData _icon(ApiConsentType type) {
    return switch (type) {
      ApiConsentType.weatherAndLocation => Icons.location_on_outlined,
      ApiConsentType.aiAndOcr => Icons.auto_awesome_outlined,
    };
  }

  static String _title(ApiConsentType type, bool isEnglish) {
    return switch (type) {
      ApiConsentType.weatherAndLocation =>
        isEnglish ? 'Use location and weather services' : '位置情報・天気サービスの利用',
      ApiConsentType.aiAndOcr =>
        isEnglish ? 'Use AI and OCR services' : 'AI・OCRサービスの利用',
    };
  }

  static String _introduction(ApiConsentType type, bool isEnglish) {
    return switch (type) {
      ApiConsentType.weatherAndLocation => isEnglish
          ? 'To find nearby tracks and retrieve current weather, the app '
              'uses your device location.'
          : '近くのコース検索と現在の天気取得のため、端末の位置情報を利用します。',
      ApiConsentType.aiAndOcr => isEnglish
          ? 'The app sends the following data to Google Gemini through '
              'Firebase Functions to provide AI advice and OCR.'
          : 'AIアドバイスとOCRを提供するため、以下のデータをFirebase Functions'
              '経由でGoogle Geminiへ送信します。',
    };
  }

  static List<String> _details(ApiConsentType type, bool isEnglish) {
    return switch (type) {
      ApiConsentType.weatherAndLocation => isEnglish
          ? const [
              'Your latitude and longitude are retrieved after browser '
                  'permission is granted.',
              'For weather retrieval, coordinates are sent to OpenWeather '
                  'through Firebase Functions.',
              'Weather results and coordinates may be cached in this browser '
                  'for up to 30 minutes.',
              'Firebase anonymous authentication is used to protect the API.',
            ]
          : const [
              'ブラウザで許可された後、現在地の緯度・経度を取得します。',
              '天気取得時は、Firebase Functionsを経由して座標をOpenWeatherへ'
                  '送信します。',
              '天気結果と座標は、このブラウザ内に最大30分間キャッシュされる場合が'
                  'あります。',
              'API保護のためFirebase匿名認証を使用します。',
            ],
      ApiConsentType.aiAndOcr => isEnglish
          ? const [
              'Selected OCR images and text contained in them.',
              'RC car settings, track/weather context, and messages entered '
                  'for AI advice.',
              'Do not select images containing personal or confidential '
                  'information.',
              'Firebase anonymous authentication is used to protect the API.',
            ]
          : const [
              'OCRで選択した画像と、画像内に含まれる文字情報。',
              'RCカーの設定値、コース・天気情報、AIアドバイスに入力したメッセージ。',
              '個人情報や機密情報が写った画像は選択しないでください。',
              'API保護のためFirebase匿名認証を使用します。',
            ],
    };
  }

  @visibleForTesting
  static void resetPendingRequestsForTesting() {
    _pendingRequests.clear();
  }
}
