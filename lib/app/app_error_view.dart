import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppErrorView {
  static const Key retryButtonKey = Key('application-bootstrap-retry');

  static Widget build(FlutterErrorDetails details) {
    // ErrorWidget can be inserted under unbounded constraints or before a
    // MaterialApp exists. Keep this fallback independent of both.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xfffff4f4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 40, color: Colors.red),
              const SizedBox(height: 8),
              const Text(
                'An unexpected UI error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  '${details.exception}',
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget initializationFailure({
    required Object error,
    required StackTrace stackTrace,
    required VoidCallback onRetry,
  }) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Application failed to start.'),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text('$error'),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text('$stackTrace'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: retryButtonKey,
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
