/// How a daily entry was created.
///
/// Per PRD Section 3.1 and Section 4.1:
/// - Voice: Captured via voice recording, then transcribed
/// - Text: Typed directly (first-class alternative to voice)
enum EntryType {
  /// Entry created via voice recording and transcription.
  voice,

  /// Entry created by typing directly.
  text,
}

extension EntryTypeExtension on EntryType {
  String get displayName {
    switch (this) {
      case EntryType.voice:
        return 'Voice';
      case EntryType.text:
        return 'Text';
    }
  }
}
