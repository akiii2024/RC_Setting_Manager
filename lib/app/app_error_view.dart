import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppErrorView {
  static Widget build(FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('An unexpected UI error occurred.'),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text('${details.exception}'),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text('${details.stack}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
