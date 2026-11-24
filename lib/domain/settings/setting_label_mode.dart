enum SettingLabelMode {
  auto,
  japanese,
  english;

  static SettingLabelMode? fromStoredValue(Object? value) {
    return values.asNameMap()[value];
  }
}
