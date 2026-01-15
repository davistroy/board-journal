import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Gets the recording path for mobile platforms.
/// Returns a path in the temp directory for AAC/M4A files.
Future<String> getRecordingPath() async {
  final directory = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${directory.path}/recording_$timestamp.m4a';
}

/// Deletes an audio file on mobile platforms.
Future<void> deleteAudioFile(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore delete errors
  }
}
