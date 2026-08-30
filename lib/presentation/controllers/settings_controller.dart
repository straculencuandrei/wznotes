import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppSettingsState {
  final bool isBiometricEnabled;
  final String appPin;
  final double fontSize;
  final bool smoothCaretEnabled;
  final bool showWordCount;
  final bool autoSaveEnabled;

  const AppSettingsState({
    this.isBiometricEnabled = false,
    this.appPin = '1234',
    this.fontSize = 17.0,
    this.smoothCaretEnabled = true,
    this.showWordCount = true,
    this.autoSaveEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'isBiometricEnabled': isBiometricEnabled,
        'appPin': appPin,
        'fontSize': fontSize,
        'smoothCaretEnabled': smoothCaretEnabled,
        'showWordCount': showWordCount,
        'autoSaveEnabled': autoSaveEnabled,
      };

  factory AppSettingsState.fromJson(Map<String, dynamic> json) {
    return AppSettingsState(
      isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
      appPin: json['appPin'] as String? ?? '1234',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 17.0,
      smoothCaretEnabled: json['smoothCaretEnabled'] as bool? ?? true,
      showWordCount: json['showWordCount'] as bool? ?? true,
      autoSaveEnabled: json['autoSaveEnabled'] as bool? ?? true,
    );
  }

  AppSettingsState copyWith({
    bool? isBiometricEnabled,
    String? appPin,
    double? fontSize,
    bool? smoothCaretEnabled,
    bool? showWordCount,
    bool? autoSaveEnabled,
  }) {
    return AppSettingsState(
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      appPin: appPin ?? this.appPin,
      fontSize: fontSize ?? this.fontSize,
      smoothCaretEnabled: smoothCaretEnabled ?? this.smoothCaretEnabled,
      showWordCount: showWordCount ?? this.showWordCount,
      autoSaveEnabled: autoSaveEnabled ?? this.autoSaveEnabled,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState()) {
    _loadSettings();
  }

  Future<File> _getSettingsFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'wznotes_data'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'settings.json'));
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = json.decode(content) as Map<String, dynamic>;
        state = AppSettingsState.fromJson(map);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final file = await _getSettingsFile();
      await file.writeAsString(json.encode(state.toJson()));
    } catch (_) {}
  }

  void toggleBiometrics(bool enabled) {
    state = state.copyWith(isBiometricEnabled: enabled);
    _persist();
  }

  void setPin(String newPin) {
    state = state.copyWith(appPin: newPin);
    _persist();
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _persist();
  }

  void toggleSmoothCaret(bool enabled) {
    state = state.copyWith(smoothCaretEnabled: enabled);
    _persist();
  }

  void toggleWordCount(bool enabled) {
    state = state.copyWith(showWordCount: enabled);
    _persist();
  }
}

final settingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});
