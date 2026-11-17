/// User preferences from the settings screen.
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.showHint = true,
    this.handHint = true,
    this.languageCode,
  });

  final bool soundEnabled;
  final bool musicEnabled;

  /// Faded picture on the board while assembling.
  final bool showHint;

  /// Hand that shows where to put a piece after a pause.
  final bool handHint;

  /// App language; null follows the device.
  final String? languageCode;

  static const supportedLanguages = ['uk', 'en', 'ru'];

  AppSettings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? showHint,
    bool? handHint,
    String? Function()? languageCode,
  }) => AppSettings(
    soundEnabled: soundEnabled ?? this.soundEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    showHint: showHint ?? this.showHint,
    handHint: handHint ?? this.handHint,
    languageCode: languageCode != null ? languageCode() : this.languageCode,
  );
}
