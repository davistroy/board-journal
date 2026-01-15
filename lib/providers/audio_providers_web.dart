/// Placeholder for web platform.
/// On web, we use transcribeFromUrl() directly instead of File.
Object createFile(String path) {
  throw UnsupportedError('File operations not supported on web. Use transcribeFromUrl() instead.');
}
