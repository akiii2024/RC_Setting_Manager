import 'dart:typed_data';

import 'package:video_player/video_player.dart';

Future<VideoPlayerController> createTelemetryVideoController(
  Uint8List bytes,
  String fileName,
) async {
  final extension = fileName.toLowerCase().endsWith('.webm') ? 'webm' : 'mp4';
  return VideoPlayerController.networkUrl(
    Uri.dataFromBytes(bytes, mimeType: 'video/$extension'),
  );
}
