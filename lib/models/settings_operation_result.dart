/// 永続化に失敗した処理の分類。
enum SettingsPersistenceFailureKind {
  read,
  write,
  invalidData,
}

/// ローカル永続化に失敗した際の、UI文言に依存しない診断情報。
final class SettingsPersistenceFailure {
  const SettingsPersistenceFailure({
    required this.kind,
    required this.operation,
    required this.cause,
    required this.stackTrace,
  });

  final SettingsPersistenceFailureKind kind;
  final String operation;
  final Object cause;
  final StackTrace stackTrace;
}

/// ローカル保存は完了したがクラウド同期だけ失敗した際の診断情報。
final class SettingsSyncWarning {
  const SettingsSyncWarning({
    required this.operation,
    required this.cause,
    required this.stackTrace,
  });

  final String operation;
  final Object cause;
  final StackTrace stackTrace;
}

/// SettingsProvider のデータ変更操作が返す型付き結果。
sealed class SettingsOperationResult<T> {
  const SettingsOperationResult();

  const factory SettingsOperationResult.success({
    T? value,
    SettingsSyncWarning? warning,
  }) = SettingsOperationSuccess<T>;

  const factory SettingsOperationResult.failure(
    SettingsPersistenceFailure failure,
  ) = SettingsOperationFailure<T>;

  bool get isSuccess => this is SettingsOperationSuccess<T>;

  bool get isFailure => this is SettingsOperationFailure<T>;
}

final class SettingsOperationSuccess<T> extends SettingsOperationResult<T> {
  const SettingsOperationSuccess({this.value, this.warning});

  final T? value;
  final SettingsSyncWarning? warning;
}

final class SettingsOperationFailure<T> extends SettingsOperationResult<T> {
  const SettingsOperationFailure(this.failure);

  final SettingsPersistenceFailure failure;
}
