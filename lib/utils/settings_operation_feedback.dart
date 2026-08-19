import 'dart:async';

import 'package:flutter/material.dart';

import '../models/settings_operation_result.dart';

/// Displays consistent, localized feedback for SettingsProvider mutations.
///
/// Returns whether the local operation completed successfully. Cloud warnings
/// are reported without turning a committed local operation into a failure.
bool handleSettingsOperationResult<T>(
  BuildContext context,
  SettingsOperationResult<T> result, {
  required bool isEnglish,
}) {
  if (!context.mounted) {
    return result.isSuccess;
  }

  switch (result) {
    case SettingsOperationFailure<T>(:final failure):
      final isCloudOperation = failure.operation == 'syncToFirebase' ||
          failure.operation == 'loadFromFirebase';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCloudOperation
                ? (isEnglish
                    ? 'Cloud synchronization failed. Local data was not changed.'
                    : 'クラウド同期に失敗しました。端末のデータは変更されていません。')
                : (isEnglish
                    ? 'Could not save on this device. The change was not applied.'
                    : '端末への保存に失敗しました。変更は適用されていません。'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return false;
    case SettingsOperationSuccess<T>(:final warning):
      if (warning != null) {
        final messenger = ScaffoldMessenger.of(context);
        final warningSnackBar = SnackBar(
          content: Text(
            isEnglish
                ? 'Saved on this device, but cloud sync failed. Try syncing again later.'
                : '端末には保存しましたが、クラウド同期に失敗しました。後で再同期してください。',
          ),
          backgroundColor: Colors.orange,
        );
        // Callers may immediately enqueue a success SnackBar and pop their
        // route after a locally committed operation. Run after that synchronous
        // continuation so the durable sync warning remains the final feedback.
        scheduleMicrotask(() {
          if (!messenger.mounted) return;
          messenger.clearSnackBars();
          messenger.showSnackBar(warningSnackBar);
        });
      }
      return true;
  }
}
