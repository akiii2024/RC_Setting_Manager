import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/telemetry.dart';
import 'telemetry_repository.dart';
import 'telemetry_session_codec.dart';

typedef TelemetrySyncCallback = Future<void> Function(
  TelemetrySyncJob job,
  TelemetrySyncState state,
);

class TelemetrySyncService {
  TelemetrySyncService({
    TelemetryRepository? repository,
    FirebaseStorage? storage,
  })  : _repository = repository ?? HiveTelemetryRepository.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final TelemetryRepository _repository;
  final FirebaseStorage _storage;
  final TelemetrySessionCodec _codec = const TelemetrySessionCodec();
  Timer? _retryTimer;
  Duration _retryDelay = const Duration(seconds: 5);

  Future<void> syncPending({
    required String uid,
    required TelemetrySyncCallback onStateChanged,
  }) async {
    _retryTimer?.cancel();
    var failed = false;
    for (final job in await _repository.loadJobs()) {
      if (job.ownerUid != null && job.ownerUid != uid) continue;
      try {
        final ref = _storage.ref(_path(uid, job.sessionId));
        if (job.operation == 'delete') {
          try {
            await ref.delete();
          } on FirebaseException catch (error) {
            if (error.code != 'object-not-found') rethrow;
          }
        } else {
          final session = await _repository.loadSession(job.sessionId);
          if (session == null) {
            await onStateChanged(job, TelemetrySyncState.unavailable);
            await _repository.deleteJob(job.sessionId);
            continue;
          }
          final bytes = _codec.encode(session, includeVideo: false);
          if (bytes.length > TelemetrySessionCodec.maxAnalysisBytes) {
            throw StateError('Analysis session exceeds 20 MiB.');
          }
          await ref.putData(
            bytes,
            SettableMetadata(
              contentType: 'application/zip',
              customMetadata: {
                'format': TelemetrySessionCodec.format,
                'sessionId': job.sessionId,
              },
            ),
          );
        }
        await onStateChanged(job, TelemetrySyncState.synced);
        await _repository.deleteJob(job.sessionId);
        _retryDelay = const Duration(seconds: 5);
      } catch (error) {
        failed = true;
        await _repository.saveJob(
          TelemetrySyncJob(
            sessionId: job.sessionId,
            runLogId: job.runLogId,
            operation: job.operation,
            createdAt: job.createdAt,
            ownerUid: job.ownerUid ?? uid,
            attempts: job.attempts + 1,
            lastError: error.toString(),
          ),
        );
        await onStateChanged(job, TelemetrySyncState.failed);
      }
    }
    if (failed) {
      _retryTimer = Timer(_retryDelay, () {
        unawaited(syncPending(uid: uid, onStateChanged: onStateChanged));
      });
      _retryDelay = Duration(
        seconds: (_retryDelay.inSeconds * 2).clamp(5, 300),
      );
    }
  }

  Future<void> download(String uid, String sessionId) async {
    final bytes = await _storage
        .ref(_path(uid, sessionId))
        .getData(TelemetrySessionCodec.maxAnalysisBytes);
    if (bytes == null) throw StateError('Telemetry session is unavailable.');
    await _repository.saveSession(_codec.decode(bytes));
  }

  void dispose() => _retryTimer?.cancel();

  String _path(String uid, String sessionId) =>
      'telemetry_sessions/$uid/$sessionId/analysis.stg';
}
