/// Dummy type for web platform (FlutterSecureStorage not available).
/// On web, TokenStorage uses SharedPreferences directly.
typedef SecureStorageType = Object;

/// Web doesn't use secure storage - returns null.
/// TokenStorage uses SharedPreferences on web instead.
Object? createSecureStorage() {
  return null;
}

/// Not used on web - throws error if called.
Future<void> write(Object storage, String key, String value) async {
  throw UnsupportedError('Secure storage not available on web');
}

/// Not used on web - throws error if called.
Future<String?> read(Object storage, String key) async {
  throw UnsupportedError('Secure storage not available on web');
}

/// Not used on web - throws error if called.
Future<void> delete(Object storage, String key) async {
  throw UnsupportedError('Secure storage not available on web');
}
