# Implementation Plan: Web Support via Record Package 6.x Upgrade

**Generated:** 2026-01-15
**Based On:** Web Feasibility Analysis & Record Package Research
**Total Phases:** 4

---

## Plan Overview

This plan upgrades the `record` package from 5.1.2 to 6.x to enable web audio recording support while maintaining full mobile functionality. The upgrade requires handling breaking API changes, implementing platform-adaptive encoder selection, and adding web-specific path handling.

**Key Strategy:**
- Minimal disruption to existing mobile functionality
- Platform detection via `kIsWeb` for conditional behavior
- Fallback to WAV/Opus encoding on web (AAC unavailable on Chrome/Firefox)
- Progressive enhancement for web-specific features

### Phase Summary Table

| Phase | Focus Area | Key Deliverables | Est. Effort | Dependencies |
|-------|------------|------------------|-------------|--------------|
| 1 | Package Upgrade | Upgrade record 5.1.2 → 6.x, fix breaking changes | ~15K tokens | None |
| 2 | Web Audio Support | Platform-adaptive encoding, web path handling | ~25K tokens | Phase 1 |
| 3 | Database & Storage | WebDatabase support, secure storage fallback | ~30K tokens | Phase 1 |
| 4 | Web Platform Setup | Create web/ directory, build configuration | ~20K tokens | Phase 2, 3 |

---

## Phase 1: Package Upgrade & Breaking Changes

**Estimated Effort:** ~15,000 tokens (including testing/fixes)
**Dependencies:** None
**Parallelizable:** No - foundational changes required first

### Goals
- Upgrade `record` package to version 6.x
- Fix all breaking API changes
- Ensure all existing tests pass
- Maintain mobile functionality without regression

### Work Items

#### 1.1 Upgrade Package Dependencies
**Files Affected:** `pubspec.yaml`
**Description:**
Update the record package version and run `flutter pub get` to fetch new dependencies.

```yaml
# Change from:
record: ^5.1.2

# To:
record: ^6.1.0
```

**Acceptance Criteria:**
- [ ] `flutter pub get` completes successfully
- [ ] No dependency conflicts reported
- [ ] Package resolves to 6.x version

#### 1.2 Fix RecordConfig API Changes
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
The `record` 6.x package changed the configuration API. Update the `RecordConfig` instantiation in `startRecording()`.

Current code (lines 219-223):
```dart
const recordConfig = RecordConfig(
  encoder: AudioEncoder.aacLc,
  bitRate: 128000,
  sampleRate: 44100,
);
```

The API should remain similar, but verify:
- `AudioEncoder` enum values
- `RecordConfig` constructor parameters
- Any new required parameters

**Acceptance Criteria:**
- [ ] `RecordConfig` instantiation compiles without errors
- [ ] Encoder, bitRate, and sampleRate parameters work correctly
- [ ] No deprecation warnings related to record package

#### 1.3 Verify AudioRecorder Class API
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
Verify the `AudioRecorder` class API is compatible. In 6.x, the class was renamed from `Record` to `AudioRecorder` (already matches current code).

Check these methods still work:
- `hasPermission()` - line 205
- `start(config, path:)` - line 226
- `stop()` - line 256
- `pause()` - line 286
- `resume()` - line 302
- `getAmplitude()` - line 390
- `dispose()` - line 368

**Acceptance Criteria:**
- [ ] All method signatures are compatible
- [ ] `Amplitude` return type from `getAmplitude()` is unchanged
- [ ] `dispose()` method exists and works

#### 1.4 Update Tests for API Compatibility
**Files Affected:** `test/services/audio/audio_recorder_service_test.dart`
**Description:**
Ensure all unit tests pass with the new package version. The tests primarily check state logic and don't mock the actual recorder, so they should pass.

**Acceptance Criteria:**
- [ ] `flutter test test/services/audio/audio_recorder_service_test.dart` passes
- [ ] No new deprecation warnings in tests

#### 1.5 Run Full Test Suite
**Files Affected:** All test files
**Description:**
Run the complete test suite to ensure no regressions from the package upgrade.

```bash
flutter test
```

**Acceptance Criteria:**
- [ ] All tests pass
- [ ] No new warnings or errors
- [ ] Audio providers tests pass (`test/providers/audio_providers_test.dart`)

### Phase 1 Testing Requirements
- Run `flutter analyze` - no new issues
- Run `flutter test` - all tests pass
- Manual test on iOS/Android simulator - recording works

### Phase 1 Completion Checklist
- [ ] All work items complete
- [ ] Tests passing
- [ ] No regressions on mobile platforms
- [ ] Package version confirmed as 6.x

---

## Phase 2: Web Audio Support Implementation

**Estimated Effort:** ~25,000 tokens (including testing/fixes)
**Dependencies:** Phase 1
**Parallelizable:** Yes - items 2.1-2.3 can run concurrently

### Goals
- Implement platform-adaptive encoder selection (WAV/Opus on web, AAC on mobile)
- Handle web-specific path requirements (empty string)
- Gracefully handle permission checking limitations on web
- Update transcription service to handle web audio formats

### Work Items

#### 2.1 Create Platform Detection Utility
**Files Affected:** `lib/utils/platform_utils.dart` (new file)
**Description:**
Create a utility file for platform detection that can be used across the app.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// Platform detection utilities for web/mobile conditional logic.
class PlatformUtils {
  /// Whether running on web platform.
  static bool get isWeb => kIsWeb;

  /// Whether running on iOS (false on web).
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Whether running on Android (false on web).
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Whether running on mobile (iOS or Android).
  static bool get isMobile => isIOS || isAndroid;
}
```

**Acceptance Criteria:**
- [ ] File created at `lib/utils/platform_utils.dart`
- [ ] Exports `PlatformUtils` class
- [ ] Compiles without errors on all platforms

#### 2.2 Implement Platform-Adaptive Encoder Selection
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
Modify the `startRecording()` method to select appropriate encoder based on platform.

Web codec support:
| Encoder | Chrome | Firefox | Safari |
|---------|--------|---------|--------|
| AAC | No | No | Yes |
| Opus | Yes | Yes | No |
| WAV | Yes | Yes | Yes |

Implementation approach:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

RecordConfig _getRecordConfig() {
  if (kIsWeb) {
    // Use WAV for universal web support (Opus has Safari issues)
    return const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 44100,
      numChannels: 1,  // Mono for smaller files
    );
  }
  // Mobile: use AAC-LC for compressed audio
  return const RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,
    sampleRate: 44100,
  );
}
```

**Acceptance Criteria:**
- [ ] Web uses WAV encoder
- [ ] Mobile continues using AAC-LC encoder
- [ ] No compilation errors on any platform
- [ ] Recording produces valid audio on web and mobile

#### 2.3 Implement Web Path Handling
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
On web, the `record` package requires an empty string for the path and returns a blob URL. Modify `startRecording()` to handle this.

```dart
Future<String> _getRecordingPath() async {
  if (kIsWeb) {
    // Web: record package uses blob URLs, path must be empty
    return '';
  }
  // Mobile: use temp directory
  final directory = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${directory.path}/recording_$timestamp.m4a';
}
```

Update the import to conditionally use `path_provider`:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for path_provider (not available on web)
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) '';
```

**Acceptance Criteria:**
- [ ] Web recordings use empty string path
- [ ] Mobile recordings use temp directory path
- [ ] Web returns valid blob URL from `stop()`
- [ ] No `dart:io` errors on web

#### 2.4 Handle Permission Checking on Web
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
The `hasPermission()` method is not available on web. The browser handles permission prompts automatically. Modify `startRecording()` to skip permission check on web.

```dart
Future<void> startRecording() async {
  // ... existing validation ...

  if (!kIsWeb) {
    // Mobile: check permission explicitly
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const AudioRecorderError(
        message: 'Microphone permission denied',
        code: 'permission_denied',
      );
    }
  }
  // Web: browser handles permission prompt automatically

  // ... rest of method ...
}
```

**Acceptance Criteria:**
- [ ] Web skips `hasPermission()` check
- [ ] Mobile continues checking permission
- [ ] Browser permission prompt appears on first web recording
- [ ] Denied permission on web throws appropriate error

#### 2.5 Handle File Deletion on Web
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
The `deleteAudioFile()` and `cancelRecording()` methods use `dart:io` File operations which don't work on web. Modify to handle web blob URLs.

```dart
Future<void> deleteAudioFile(String filePath) async {
  if (kIsWeb) {
    // Web: blob URLs are automatically garbage collected
    // Optionally revoke the blob URL to free memory immediately
    // This requires js_interop - skip for now, GC handles it
    return;
  }
  // Mobile: delete file
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore delete errors
  }
}
```

**Acceptance Criteria:**
- [ ] `deleteAudioFile()` no-ops gracefully on web
- [ ] `cancelRecording()` works on web without file errors
- [ ] Mobile file deletion unchanged

#### 2.6 Update Audio Providers for Web Compatibility
**Files Affected:** `lib/providers/audio_providers.dart`
**Description:**
The `_transcribeAudio()` method creates a `File` object which won't work on web. Update to handle web blob URLs.

```dart
// In VoiceRecordingNotifier._transcribeAudio()
Future<void> _transcribeAudio(String filePath) async {
  // ... existing code ...

  try {
    TranscriptionResult result;
    if (kIsWeb) {
      // Web: pass blob URL directly to transcription service
      result = await transcriptionService.transcribeFromUrl(filePath);
    } else {
      // Mobile: pass file
      result = await transcriptionService.transcribe(File(filePath));
    }
    // ... rest of method ...
  }
}
```

**Note:** This requires a new method in TranscriptionService - see item 2.7.

**Acceptance Criteria:**
- [ ] Web uses blob URL for transcription
- [ ] Mobile continues using File object
- [ ] No `dart:io` imports in web-critical paths

#### 2.7 Update Transcription Service for Web
**Files Affected:** `lib/services/ai/transcription_service.dart`
**Description:**
Add a method to handle web blob URLs for transcription. The Deepgram/OpenAI APIs accept audio data, so we need to fetch the blob and send the bytes.

```dart
/// Transcribes audio from a web blob URL.
/// Only available on web platform.
Future<TranscriptionResult> transcribeFromUrl(String blobUrl) async {
  // Fetch blob data using http package
  final response = await http.get(Uri.parse(blobUrl));
  if (response.statusCode != 200) {
    throw TranscriptionError(
      message: 'Failed to fetch audio blob',
      provider: _getPrimaryProvider(),
    );
  }

  return _transcribeBytes(
    response.bodyBytes,
    mimeType: 'audio/wav',  // Web recordings are WAV
  );
}
```

**Acceptance Criteria:**
- [ ] `transcribeFromUrl()` method added
- [ ] Fetches blob data correctly
- [ ] Sends to transcription API successfully
- [ ] Returns `TranscriptionResult`

#### 2.8 Add Web-Specific Audio File Extension
**Files Affected:** `lib/services/audio/audio_recorder_service.dart`
**Description:**
Update file extension logic for web WAV recordings vs mobile AAC.

```dart
String _getFileExtension() {
  if (kIsWeb) {
    return '.wav';
  }
  return '.m4a';  // AAC in M4A container
}
```

**Acceptance Criteria:**
- [ ] Web recordings identified as WAV
- [ ] Mobile recordings remain M4A
- [ ] Transcription service handles both formats

### Phase 2 Testing Requirements
- Test recording on Chrome, Firefox, Safari
- Test full voice → transcription flow on web
- Verify waveform visualization works on web
- Verify silence detection works on web
- Run mobile tests to confirm no regressions

### Phase 2 Completion Checklist
- [ ] All work items complete
- [ ] Web audio recording works in Chrome
- [ ] Web audio recording works in Firefox
- [ ] Web audio recording works in Safari (if possible)
- [ ] Mobile functionality unchanged
- [ ] Transcription works with web recordings

---

## Phase 3: Database & Storage Web Support

**Estimated Effort:** ~30,000 tokens (including testing/fixes)
**Dependencies:** Phase 1 (for stable base)
**Parallelizable:** Yes - can run in parallel with Phase 2

### Goals
- Enable Drift database on web using WebDatabase (IndexedDB)
- Handle secure storage limitations on web
- Update file-based operations for web compatibility

### Work Items

#### 3.1 Add Web Database Dependencies
**Files Affected:** `pubspec.yaml`
**Description:**
Add the `drift_web` package for web database support.

```yaml
dependencies:
  drift: ^2.14.0
  # Add for web support:
  drift_web: ^2.0.0

# Also add dev dependency for web SQL WASM:
dev_dependencies:
  # ... existing deps ...
  wasm: ^0.1.0  # If needed for WASM builds
```

**Acceptance Criteria:**
- [ ] `drift_web` added to dependencies
- [ ] `flutter pub get` succeeds
- [ ] No version conflicts

#### 3.2 Implement Platform-Adaptive Database Connection
**Files Affected:** `lib/data/database/database.dart`
**Description:**
Modify `_openConnection()` to use `WebDatabase` on web and `NativeDatabase` on mobile.

```dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Conditional imports
import 'package:drift/native.dart' if (dart.library.html) 'package:drift/web.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) '';
import 'dart:io' if (dart.library.html) '';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (kIsWeb) {
      // Web: use IndexedDB via WebDatabase
      return WebDatabase('boardroom_journal');
    }

    // Mobile: use SQLite file
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'boardroom_journal.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

**Acceptance Criteria:**
- [ ] Web uses `WebDatabase` (IndexedDB)
- [ ] Mobile uses `NativeDatabase` (SQLite)
- [ ] Database operations work on both platforms
- [ ] Data persists across page reloads on web

#### 3.3 Create Conditional Import Stubs
**Files Affected:**
- `lib/data/database/database_native.dart` (new)
- `lib/data/database/database_web.dart` (new)
**Description:**
Create platform-specific implementation files to avoid import errors.

`database_native.dart`:
```dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

Future<QueryExecutor> openConnection() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'boardroom_journal.sqlite'));
  return NativeDatabase.createInBackground(file);
}
```

`database_web.dart`:
```dart
import 'package:drift/web.dart';

Future<QueryExecutor> openConnection() async {
  return WebDatabase('boardroom_journal');
}
```

Update `database.dart` to use conditional imports:
```dart
import 'database_stub.dart'
    if (dart.library.io) 'database_native.dart'
    if (dart.library.html) 'database_web.dart';
```

**Acceptance Criteria:**
- [ ] Conditional imports work correctly
- [ ] No compilation errors on web or mobile
- [ ] Database opens successfully on both platforms

#### 3.4 Handle Secure Storage on Web
**Files Affected:** `lib/services/auth/token_storage.dart`
**Description:**
`flutter_secure_storage` has limited web support. Implement fallback to `localStorage` on web with appropriate warnings.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  final FlutterSecureStorage? _secureStorage;

  TokenStorage() : _secureStorage = kIsWeb ? null : const FlutterSecureStorage();

  Future<void> saveToken(String key, String token) async {
    if (kIsWeb) {
      // Web: use SharedPreferences (localStorage)
      // WARNING: Less secure than native secure storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, token);
    } else {
      await _secureStorage!.write(key: key, value: token);
    }
  }

  Future<String?> getToken(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return await _secureStorage!.read(key: key);
  }

  Future<void> deleteToken(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage!.delete(key: key);
    }
  }
}
```

**Acceptance Criteria:**
- [ ] Web uses SharedPreferences for token storage
- [ ] Mobile uses FlutterSecureStorage
- [ ] Tokens persist across page reloads on web
- [ ] Authentication flow works on web

#### 3.5 Update Background Task Handling for Web
**Files Affected:** `lib/services/scheduling/brief_scheduler_service.dart`
**Description:**
`workmanager` is not available on web. Disable background scheduling on web and implement on-load checking for missed briefs.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

class BriefSchedulerService {
  Future<void> scheduleWeeklyBrief(DateTime scheduledTime) async {
    if (kIsWeb) {
      // Web: Cannot schedule background tasks
      // Store scheduled time in SharedPreferences
      // Check on app load if brief was missed
      await _storeScheduledTime(scheduledTime);
      return;
    }

    // Mobile: use workmanager
    await _workmanager.registerOneOffTask(
      // ... existing implementation ...
    );
  }

  /// Call on app startup to check for missed briefs (web only)
  Future<void> checkForMissedBriefs() async {
    if (!kIsWeb) return;

    final scheduledTime = await _getScheduledTime();
    if (scheduledTime != null && DateTime.now().isAfter(scheduledTime)) {
      // Brief was scheduled but missed - trigger generation
      await _generateBriefNow();
      await _clearScheduledTime();
    }
  }
}
```

**Acceptance Criteria:**
- [ ] Web skips workmanager scheduling
- [ ] Scheduled times stored in SharedPreferences on web
- [ ] Missed briefs detected and generated on app load
- [ ] Mobile background tasks unchanged

#### 3.6 Update Export Service for Web
**Files Affected:** `lib/services/export/export_service.dart`
**Description:**
File export uses `dart:io` which is unavailable on web. Implement browser download for web.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html if (dart.library.html) '';

Future<void> exportData(String filename, String content) async {
  if (kIsWeb) {
    // Web: trigger browser download
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    return;
  }

  // Mobile: write to file and share
  // ... existing implementation ...
}
```

**Acceptance Criteria:**
- [ ] Web triggers browser download dialog
- [ ] Mobile continues using file + share
- [ ] Export data is identical on both platforms

#### 3.7 Update Tests for Web Database
**Files Affected:** `test/data/database/database_test.dart`
**Description:**
Ensure database tests work in both web and native contexts.

**Acceptance Criteria:**
- [ ] Tests use in-memory database for isolation
- [ ] Tests pass in both web and native test runners
- [ ] No platform-specific test failures

### Phase 3 Testing Requirements
- Verify database operations on web
- Test token storage persistence on web
- Verify export downloads work on web
- Run full test suite on mobile
- Test fresh install flow on web (no existing data)

### Phase 3 Completion Checklist
- [ ] All work items complete
- [ ] Database works on web (IndexedDB)
- [ ] Token storage works on web
- [ ] Background task workaround implemented
- [ ] Export works on web via download
- [ ] All tests passing

---

## Phase 4: Web Platform Setup & Configuration

**Estimated Effort:** ~20,000 tokens (including testing/fixes)
**Dependencies:** Phase 2, Phase 3
**Parallelizable:** Partially - 4.1 can start early, 4.2-4.5 require prior phases

### Goals
- Create web platform directory and configuration files
- Configure build settings for web
- Handle environment variables for web builds
- Enable PWA support for installable web app

### Work Items

#### 4.1 Create Web Platform Directory
**Files Affected:** `web/` directory (new)
**Description:**
Run Flutter command to create web platform support.

```bash
flutter create --platforms=web .
```

This creates:
- `web/index.html` - Entry point
- `web/manifest.json` - PWA metadata
- `web/favicon.png` - Icon
- `web/icons/` - PWA icons

**Acceptance Criteria:**
- [ ] `web/` directory created
- [ ] `flutter run -d chrome` launches successfully
- [ ] Basic app shell renders

#### 4.2 Configure Web Index.html
**Files Affected:** `web/index.html`
**Description:**
Update `index.html` with app-specific configuration.

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Boardroom Journal</title>
  <meta name="description" content="Voice-first career journaling with AI-powered governance">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png"/>

  <!-- PWA -->
  <link rel="manifest" href="manifest.json">
  <meta name="theme-color" content="#1a1a2e">

  <!-- iOS PWA -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Boardroom Journal">

  <script>
    // Service worker registration
    if ('serviceWorker' in navigator) {
      window.addEventListener('flutter-first-frame', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
  </script>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
```

**Acceptance Criteria:**
- [ ] App title updated
- [ ] Meta description added
- [ ] PWA configuration present
- [ ] Service worker registration enabled

#### 4.3 Configure Web Manifest for PWA
**Files Affected:** `web/manifest.json`
**Description:**
Update PWA manifest with app information.

```json
{
  "name": "Boardroom Journal",
  "short_name": "Boardroom",
  "description": "Voice-first career journaling with AI-powered governance",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#1a1a2e",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-maskable-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "icons/Icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

**Acceptance Criteria:**
- [ ] Manifest updated with app info
- [ ] Icons referenced correctly
- [ ] PWA installable on supported browsers

#### 4.4 Handle Environment Variables for Web
**Files Affected:** `lib/services/ai/ai_config.dart`, `lib/services/ai/transcription_service.dart`
**Description:**
`Platform.environment` doesn't work on web. Use `String.fromEnvironment()` for build-time injection.

```dart
class AIConfig {
  static const String anthropicApiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '',
  );

  static const String deepgramApiKey = String.fromEnvironment(
    'DEEPGRAM_API_KEY',
    defaultValue: '',
  );

  static const String openaiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      anthropicApiKey.isNotEmpty &&
      (deepgramApiKey.isNotEmpty || openaiApiKey.isNotEmpty);
}
```

Build command:
```bash
flutter build web \
  --dart-define=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --dart-define=DEEPGRAM_API_KEY=$DEEPGRAM_API_KEY \
  --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY
```

**Acceptance Criteria:**
- [ ] Environment variables work via `--dart-define`
- [ ] Fallback to empty string if not provided
- [ ] Build commands documented
- [ ] CI/CD can inject variables at build time

#### 4.5 Update Sign-In Screen for Web
**Files Affected:** `lib/ui/screens/onboarding/signin_screen.dart`
**Description:**
Hide Apple Sign-In on web (not supported) and adjust UI for web viewport.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// In build method:
if (!kIsWeb) ...[
  // Only show Apple Sign-In on native platforms
  if (Platform.isIOS || Platform.isMacOS)
    _SignInButton(
      // Apple sign-in button
    ),
],
```

**Acceptance Criteria:**
- [ ] Apple Sign-In hidden on web
- [ ] Google Sign-In works on web
- [ ] Microsoft Sign-In works on web
- [ ] UI renders properly on web viewport

#### 4.6 Add Web Build Scripts
**Files Affected:** `package.json` or build scripts
**Description:**
Create convenient scripts for web development and production builds.

Add to project documentation or create scripts:
```bash
# Development
flutter run -d chrome

# Production build
flutter build web --release \
  --dart-define=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --dart-define=DEEPGRAM_API_KEY=$DEEPGRAM_API_KEY

# Serve production build locally
cd build/web && python -m http.server 8080
```

**Acceptance Criteria:**
- [ ] Build commands documented in README or CLAUDE.md
- [ ] Production build succeeds
- [ ] Built app runs from static server

#### 4.7 Update CLAUDE.md with Web Commands
**Files Affected:** `CLAUDE.md`
**Description:**
Add web build and run commands to project documentation.

```markdown
## Web Development

```bash
# Run web version locally
flutter run -d chrome

# Build for production (with API keys)
flutter build web --release \
  --dart-define=ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  --dart-define=DEEPGRAM_API_KEY=$DEEPGRAM_API_KEY \
  --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY

# Test production build locally
cd build/web && python -m http.server 8080
```

## Web Limitations

- Voice recording uses WAV format (larger files than mobile AAC)
- Background tasks not available (weekly briefs checked on app load)
- Token storage uses localStorage (less secure than mobile Keychain/Keystore)
- Apple Sign-In not available on web
```

**Acceptance Criteria:**
- [ ] CLAUDE.md updated with web commands
- [ ] Web limitations documented
- [ ] Build process clearly explained

### Phase 4 Testing Requirements
- Test `flutter run -d chrome` works
- Test production build and serving
- Verify PWA installation works
- Test on Chrome, Firefox, Safari, Edge
- Verify environment variables are injected correctly

### Phase 4 Completion Checklist
- [ ] All work items complete
- [ ] Web platform runs in development mode
- [ ] Production build succeeds
- [ ] PWA installable
- [ ] Documentation updated
- [ ] Environment variables work

---

## Parallel Work Opportunities

| Work Item A | Can Run With | Notes |
|-------------|--------------|-------|
| Phase 2 (Audio) | Phase 3 (Database) | Independent platform adaptations |
| 2.1 (Platform Utils) | 2.2, 2.3, 2.4 | Utility file can be created first |
| 3.1 (Dependencies) | 3.4 (Secure Storage) | Different subsystems |
| 4.1 (Create Web Dir) | 2.x, 3.x | Can start early |

**Recommended Parallel Execution:**
1. Start Phase 1 (sequential - foundational)
2. After Phase 1: Run Phase 2 and Phase 3 in parallel
3. After Phase 2 & 3: Complete Phase 4

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Record 6.x has breaking changes | Medium | Medium | Review changelog before upgrade; test thoroughly |
| WAV files too large for transcription | Low | High | Implement client-side compression or server transcoding |
| Safari Web Audio issues | Medium | Medium | Test early; have WAV fallback for Safari |
| IndexedDB quota exceeded | Low | High | Implement data cleanup; warn users when approaching limit |
| CORS issues with transcription API | Medium | Medium | Use backend proxy; configure API for web origins |
| Browser permission handling varies | Medium | Low | Test across browsers; add error handling |

---

## Success Metrics

1. **Functional Completeness**
   - [ ] Voice recording works on Chrome, Firefox, Safari
   - [ ] Transcription flow completes successfully
   - [ ] Data persists in IndexedDB
   - [ ] Authentication works via Google/Microsoft

2. **Performance**
   - [ ] Initial page load < 5 seconds
   - [ ] Recording starts within 1 second of permission grant
   - [ ] Waveform visualization runs at 60fps

3. **Quality**
   - [ ] All existing tests pass
   - [ ] No console errors in production build
   - [ ] `flutter analyze` reports no issues

4. **User Experience**
   - [ ] Mobile users unaffected by changes
   - [ ] Web users can complete full journaling flow
   - [ ] PWA installable and works offline (for viewing)

---

## Post-Implementation Tasks

After all phases complete:

1. **Cross-Browser Testing**
   - Test on Chrome (Windows, macOS, Linux)
   - Test on Firefox (Windows, macOS, Linux)
   - Test on Safari (macOS, iOS)
   - Test on Edge (Windows)

2. **Performance Optimization**
   - Analyze bundle size
   - Implement code splitting if needed
   - Optimize asset loading

3. **Security Audit**
   - Review localStorage token storage
   - Verify CORS configuration
   - Check CSP headers for deployment

4. **Documentation**
   - Update README with web deployment instructions
   - Document browser requirements
   - Add troubleshooting guide for web-specific issues

---

*Implementation plan generated by Claude on 2026-01-15*
