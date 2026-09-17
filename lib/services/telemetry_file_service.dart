import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/telemetry.dart';
import 'telemetry_analysis_service.dart';
import 'telemetry_session_codec.dart';

abstract final class TelemetryFileService {
  static const _codec = TelemetrySessionCodec();

  static Future<TelemetrySession?> pickCsv() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > TelemetrySessionCodec.maxAnalysisBytes) {
      throw const TelemetryFormatException('CSVは20 MiB以下にしてください。');
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw const TelemetryFormatException('CSVファイルを読み込めませんでした。');
    }
    return TelemetryAnalysisService.parseCsv(
      text: _decodeCsv(bytes),
      fileName: file.name,
    );
  }

  static Future<TelemetrySession?> pickStg() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['stg'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const TelemetryFormatException('.stgファイルを読み込めませんでした。');
    }
    return _codec.decode(bytes);
  }

  static Future<(String, Uint8List)?> pickVideo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const TelemetryFormatException('動画ファイルを読み込めませんでした。');
    }
    return (file.name, bytes);
  }

  static Future<void> saveStg(TelemetrySession session) async {
    final baseName = session.csvFileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    await FilePicker.saveFile(
      dialogTitle: 'テレメトリーセッションを保存',
      fileName: '$baseName.stg',
      bytes: _codec.encode(session),
    );
  }

  static Future<void> saveCourse(
    List<CoursePoint> points,
    int durationMillis,
  ) async {
    await FilePicker.saveFile(
      dialogTitle: 'コースマップを保存',
      fileName: 'course_map.json',
      bytes: _codec.encodeCourse(points, durationMillis),
    );
  }

  static Future<List<CoursePoint>?> pickCourse() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const TelemetryFormatException('コースJSONを読み込めませんでした。');
    }
    return _codec.decodeCourse(bytes);
  }

  static String _decodeCsv(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }
}
