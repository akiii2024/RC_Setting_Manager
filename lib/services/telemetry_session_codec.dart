import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/telemetry.dart';
import '../models/telemetry_ai.dart';
import 'telemetry_analysis_service.dart';
import 'telemetry_feature_service.dart';

class TelemetrySessionCodec {
  const TelemetrySessionCodec();

  static const format = 'sanwa-telemetry-graph';
  static const version = 2;
  static const maxAnalysisBytes = 20 * 1024 * 1024;

  Uint8List encode(
    TelemetrySession session, {
    bool includeVideo = true,
  }) {
    final manifest = <String, dynamic>{
      'version': version,
      'format': format,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'sessionId': session.id,
      'csv': {'filename': session.csvFileName},
      'video': includeVideo && session.videoBytes != null
          ? {
              'filename': session.videoFileName ?? 'video.mp4',
              'syncMode': session.videoSyncMode,
              'offsetMs': session.videoOffsetMillis,
            }
          : null,
      'view': {
        'selectedMetrics': session.selectedMetrics,
        'viewWindowSeconds': session.viewWindowSeconds,
      },
      'courseMap': {
        ...session.courseOptions.toJson(),
        'editedPoints': session.editedCoursePoints
            ?.map((point) => point.toJson())
            .toList(growable: false),
      },
      'aiCoach': session.aiAnalysis?.toJson(),
    };
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'manifest.json',
          const JsonEncoder.withIndent('  ').convert(manifest),
        ),
      )
      ..addFile(ArchiveFile.string(session.csvFileName, session.csvText));
    final videoBytes = session.videoBytes;
    if (includeVideo && videoBytes != null) {
      archive.addFile(
        ArchiveFile(
          session.videoFileName ?? 'video.mp4',
          videoBytes.length,
          videoBytes,
        )..compression = CompressionType.none,
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  TelemetrySession decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const TelemetryFormatException('.stgファイルが空です。');
    }
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const TelemetryFormatException('.stgファイルを展開できません。');
    }
    if (archive.length > 16) {
      throw const TelemetryFormatException('.stg内のファイル数が多すぎます。');
    }
    final manifestFile = _find(archive, 'manifest.json');
    if (manifestFile == null) {
      throw const TelemetryFormatException('manifest.jsonが見つかりません。');
    }
    final manifest = _decodeJson(_text(manifestFile), 'manifest.json');
    if (manifest['format'] != null && manifest['format'] != format) {
      throw const TelemetryFormatException('対応していない.stg形式です。');
    }
    final manifestVersion = (manifest['version'] as num?)?.toInt() ?? 1;
    if (manifestVersion < 1 || manifestVersion > version) {
      throw const TelemetryFormatException('対応していない.stgバージョンです。');
    }
    final csvJson = manifest['csv'];
    final csvFileName = csvJson is Map<String, dynamic>
        ? csvJson['filename'] as String? ?? 'telemetry.csv'
        : 'telemetry.csv';
    final csvFile = _find(archive, csvFileName);
    if (csvFile == null || csvFile.size > maxAnalysisBytes) {
      throw const TelemetryFormatException('CSVがないか、20 MiBを超えています。');
    }
    final session = TelemetryAnalysisService.parseCsv(
      text: _text(csvFile),
      fileName: csvFileName,
      sessionId: manifest['sessionId'] as String?,
    );

    final view = manifest['view'];
    if (view is Map<String, dynamic>) {
      final metrics = view['selectedMetrics'];
      if (metrics is List) {
        session.selectedMetrics = metrics
            .whereType<String>()
            .where(session.metrics.contains)
            .toList(growable: false);
      }
      session.viewWindowSeconds =
          (view['viewWindowSeconds'] as num?)?.toDouble() ?? 0;
    }
    final course = manifest['courseMap'];
    if (course is Map<String, dynamic>) {
      session.courseOptions = CourseOptions.fromJson(course);
      final edited = course['editedPoints'];
      if (edited is List) {
        session.editedCoursePoints = edited
            .whereType<Map>()
            .map(
                (item) => CoursePoint.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false);
      }
    }
    final video = manifest['video'];
    if (video is Map<String, dynamic>) {
      final videoFileName = video['filename'] as String?;
      final videoFile =
          videoFileName == null ? null : _find(archive, videoFileName);
      if (videoFile != null) {
        session.videoFileName = videoFileName;
        session.videoBytes = Uint8List.fromList(videoFile.content as List<int>);
      }
      session.videoSyncMode = video['syncMode'] as String? ?? 'start';
      session.videoOffsetMillis = (video['offsetMs'] as num?)?.round() ?? 0;
    }
    final aiCoach = manifest['aiCoach'];
    if (aiCoach is Map) {
      try {
        final result = TelemetryAiResult.fromJson(
          Map<String, dynamic>.from(aiCoach),
        );
        final currentFingerprint =
            TelemetryFeatureService.build(session).inputFingerprint;
        if (result.schemaVersion == 1 &&
            result.inputFingerprint == currentFingerprint) {
          session.aiAnalysis = result;
        }
      } catch (_) {
        // AI結果は再生成可能な付加情報。CSV本体の読込は継続する。
      }
    }
    return session;
  }

  Uint8List encodeCourse(List<CoursePoint> points, int lapDurationMillis) {
    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ').convert({
          'version': 1,
          'lapDuration': lapDurationMillis,
          'points': points.map((point) => point.toJson()).toList(),
        }),
      ),
    );
  }

  List<CoursePoint> decodeCourse(Uint8List bytes) {
    final json = _decodeJson(utf8.decode(bytes), 'course_map.json');
    final points = json['points'];
    if (points is! List) {
      throw const TelemetryFormatException('コースポイントがありません。');
    }
    return points
        .whereType<Map>()
        .map((value) => CoursePoint.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  ArchiveFile? _find(Archive archive, String name) {
    final safeName = name.replaceAll('\\', '/').split('/').last;
    for (final file in archive) {
      if (file.name.replaceAll('\\', '/').split('/').last == safeName) {
        return file;
      }
    }
    return null;
  }

  String _text(ArchiveFile file) => utf8.decode(file.content as List<int>);

  Map<String, dynamic> _decodeJson(String text, String label) {
    try {
      final value = jsonDecode(text);
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // The user-facing exception below has the actionable context.
    }
    throw TelemetryFormatException('$labelを読み取れません。');
  }
}
