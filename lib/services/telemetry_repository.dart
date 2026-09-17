import 'dart:typed_data';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/telemetry.dart';
import 'telemetry_session_codec.dart';

abstract interface class TelemetryRepository {
  Future<void> saveSession(TelemetrySession session);
  Future<TelemetrySession?> loadSession(String sessionId);
  Future<bool> hasSession(String sessionId);
  Future<void> deleteSession(String sessionId);
  Future<void> saveJob(TelemetrySyncJob job);
  Future<List<TelemetrySyncJob>> loadJobs();
  Future<void> deleteJob(String sessionId);
}

class HiveTelemetryRepository implements TelemetryRepository {
  HiveTelemetryRepository._();

  static final HiveTelemetryRepository instance = HiveTelemetryRepository._();
  static const _sessionBoxName = 'telemetry_sessions_v1';
  static const _videoBoxName = 'telemetry_videos_v1';
  static const _jobBoxName = 'telemetry_sync_jobs_v1';
  static Future<void>? _initialization;

  final TelemetrySessionCodec _codec = const TelemetrySessionCodec();

  Future<void> _initialize() => _initialization ??= Hive.initFlutter();

  Future<Box<dynamic>> _sessions() async {
    await _initialize();
    return Hive.openBox<dynamic>(_sessionBoxName);
  }

  Future<Box<dynamic>> _jobs() async {
    await _initialize();
    return Hive.openBox<dynamic>(_jobBoxName);
  }

  Future<Box<dynamic>> _videos() async {
    await _initialize();
    return Hive.openBox<dynamic>(_videoBoxName);
  }

  @override
  Future<void> saveSession(TelemetrySession session) async {
    final sessions = await _sessions();
    final videos = await _videos();
    await sessions.put(session.id, _codec.encode(session, includeVideo: false));
    final videoBytes = session.videoBytes;
    if (videoBytes == null) {
      await videos.delete(session.id);
    } else {
      await videos.put(session.id, {
        'fileName': session.videoFileName ?? 'video.mp4',
        'bytes': videoBytes,
      });
    }
  }

  @override
  Future<TelemetrySession?> loadSession(String sessionId) async {
    final box = await _sessions();
    final value = box.get(sessionId);
    final session = switch (value) {
      Uint8List() => _codec.decode(value),
      List<int>() => _codec.decode(Uint8List.fromList(value)),
      _ => null,
    };
    if (session == null) return null;
    final video = (await _videos()).get(sessionId);
    if (video is Map) {
      final bytes = video['bytes'];
      session.videoFileName = video['fileName'] as String?;
      if (bytes is Uint8List) session.videoBytes = bytes;
      if (bytes is List<int>) session.videoBytes = Uint8List.fromList(bytes);
    }
    return session;
  }

  @override
  Future<bool> hasSession(String sessionId) async {
    final box = await _sessions();
    return box.containsKey(sessionId);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final box = await _sessions();
    await box.delete(sessionId);
    await (await _videos()).delete(sessionId);
  }

  @override
  Future<void> saveJob(TelemetrySyncJob job) async {
    final box = await _jobs();
    await box.put(job.sessionId, job.toJson());
  }

  @override
  Future<List<TelemetrySyncJob>> loadJobs() async {
    final box = await _jobs();
    return box.values
        .whereType<Map>()
        .map((value) =>
            TelemetrySyncJob.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  @override
  Future<void> deleteJob(String sessionId) async {
    final box = await _jobs();
    await box.delete(sessionId);
  }
}
