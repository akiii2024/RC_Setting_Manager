/// キャンバー角の入力は、符号が省略された場合だけネガティブと解釈する。
bool isCamberSettingKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.endsWith('camber') || normalized.endsWith('camberangle');
}

/// トー角はトーインを正、トーアウトを負として扱う。
bool isToeSettingKey(String key) {
  final normalized = key.toLowerCase();
  return normalized.endsWith('toe') || normalized.endsWith('toeangle');
}

bool isSignedAngleSettingKey(String key) {
  return isCamberSettingKey(key) || isToeSettingKey(key);
}

/// 数値入力に含まれる全角の数字・小数点・符号をASCIIへ正規化する。
///
/// 長音記号など、数値入力として意味を持たない文字は変換しない。
String normalizeSettingNumberInput(String input) {
  return input.trim().replaceAllMapped(RegExp(r'[０-９．＋－−]'), (match) {
    final character = match.group(0)!;
    if (character == '．') return '.';
    if (character == '＋') return '+';
    if (character == '－' || character == '−') return '-';
    return String.fromCharCode(character.codeUnitAt(0) - 0xfee0);
  });
}

double? parseSettingNumberInput(String key, String input) {
  final text = normalizeSettingNumberInput(input);
  final value = double.tryParse(text);
  if (value == null || !isCamberSettingKey(key) || value == 0) return value;
  if (text.startsWith('+') || text.startsWith('-')) return value;
  return -value.abs();
}

/// 保存済みのポジティブキャンバーは、再編集で符号を失わないよう明示する。
String formatSettingNumberInput(String key, Object? value) {
  final text = normalizeSettingNumberInput(value?.toString() ?? '0');
  final number = double.tryParse(text);
  if (isCamberSettingKey(key) &&
      number != null &&
      number > 0 &&
      !text.startsWith('+')) {
    return '+$text';
  }
  return text;
}
