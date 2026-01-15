/// Gets the recording path for web platform.
/// Returns empty string because record package uses blob URLs on web.
Future<String> getRecordingPath() async {
  // Web: record package uses blob URLs, path must be empty
  return '';
}

/// Deletes an audio file on web platform.
/// No-op because blob URLs are automatically garbage collected.
Future<void> deleteAudioFile(String filePath) async {
  // Web: blob URLs are automatically garbage collected by the browser.
  // No explicit deletion needed.
}
