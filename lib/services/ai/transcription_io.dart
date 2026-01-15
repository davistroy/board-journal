import 'dart:io';
import 'dart:typed_data';

/// Type alias for File on mobile platforms.
typedef FileType = File;

/// Gets an environment variable on mobile platforms.
String? getEnvironmentVariable(String name) {
  return Platform.environment[name];
}

/// Creates a File object from a path.
File createFile(String path) {
  return File(path);
}

/// Checks if a file exists.
Future<bool> fileExists(File file) async {
  return file.exists();
}

/// Gets the path of a file.
String getFilePath(File file) {
  return file.path;
}

/// Reads file bytes.
Future<Uint8List> readFileBytes(File file) async {
  return file.readAsBytes();
}

/// Deletes a file.
Future<void> deleteFile(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}
