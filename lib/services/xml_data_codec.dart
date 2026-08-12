import 'package:xml/xml.dart';

import '../models/saved_setting.dart';

/// XMLの値表現と旧形式の既定値をモデル値へ変換する純粋ロジック。
class XmlDataCodec {
  const XmlDataCodec._();

  static SavedSettingKind parseSavedSettingKind(String? value) {
    if (value != null) {
      for (final kind in SavedSettingKind.values) {
        if (kind.name == value) {
          return kind;
        }
      }
    }
    return SavedSettingKind.manual;
  }

  /// 保存済みセッティングで従来使われてきた、double優先の変換。
  static dynamic parseSavedSettingValue(String value) {
    if (double.tryParse(value) != null) {
      return double.parse(value);
    }
    if (int.tryParse(value) != null) {
      return int.parse(value);
    }
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      return value.toLowerCase() == 'true';
    }
    return value;
  }

  /// 走行ログの変更値で従来使われてきた、int優先の変換。
  static dynamic parseRunChangeValue(String value) {
    if (int.tryParse(value) != null) {
      return int.parse(value);
    }
    if (double.tryParse(value) != null) {
      return double.parse(value);
    }
    if (value.toLowerCase() == 'true' || value.toLowerCase() == 'false') {
      return value.toLowerCase() == 'true';
    }
    return value;
  }

  static double? parseOptionalDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  static String? emptyToNull(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

/// XMLパース前後の構造検証を、ファイル入出力から分離する。
class XmlImportValidator {
  const XmlImportValidator._();

  static void validateContentLength(String xmlContent, int maxCharacters) {
    if (xmlContent.length > maxCharacters) {
      throw const FormatException('XMLデータは5 MiB以下にしてください。');
    }
  }

  static void validateRoot(XmlElement root) {
    if (root.name.local != 'RCCarSettingsData') {
      throw Exception(
        'Invalid XML format: Root element must be RCCarSettingsData',
      );
    }
  }
}
