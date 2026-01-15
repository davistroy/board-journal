import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Type alias for secure storage on mobile platforms.
typedef SecureStorageType = FlutterSecureStorage;

/// Creates secure storage with platform-appropriate options.
FlutterSecureStorage createSecureStorage() {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
}

/// Writes a value to secure storage.
Future<void> write(FlutterSecureStorage storage, String key, String value) async {
  await storage.write(key: key, value: value);
}

/// Reads a value from secure storage.
Future<String?> read(FlutterSecureStorage storage, String key) async {
  return storage.read(key: key);
}

/// Deletes a value from secure storage.
Future<void> delete(FlutterSecureStorage storage, String key) async {
  await storage.delete(key: key);
}
