import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createTelemetryVideoController(
  Uint8List bytes,
  String fileName,
) async {
  final directory = await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${directory.path}/telemetry-$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return VideoPlayerController.file(file);
}
