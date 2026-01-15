import 'dart:typed_data';

/// Dummy type for web platform (File not available).
/// On web, we use transcribeFromUrl() instead.
typedef FileType = Object;

/// Web build-time environment variables are injected via --dart-define.
/// Returns null because Platform.environment doesn't work on web.
/// Use String.fromEnvironment() in the calling code instead.
String? getEnvironmentVariable(String name) {
  // On web, environment variables should be injected at build time
  // using --dart-define=KEY=value
  switch (name) {
    case 'DEEPGRAM_API_KEY':
      const key = String.fromEnvironment('DEEPGRAM_API_KEY', defaultValue: '');
      return key.isEmpty ? null : key;
    case 'OPENAI_API_KEY':
      const key = String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
      return key.isEmpty ? null : key;
    default:
      return null;
  }
}

/// Creates a placeholder object (not used on web).
Object createFile(String path) {
  throw UnsupportedError('File operations not supported on web');
}

/// File operations not supported on web.
Future<bool> fileExists(Object file) async {
  throw UnsupportedError('File operations not supported on web');
}

/// File operations not supported on web.
String getFilePath(Object file) {
  throw UnsupportedError('File operations not supported on web');
}

/// File operations not supported on web.
Future<Uint8List> readFileBytes(Object file) async {
  throw UnsupportedError('File operations not supported on web');
}

/// File operations not supported on web.
Future<void> deleteFile(Object file) async {
  throw UnsupportedError('File operations not supported on web');
}
