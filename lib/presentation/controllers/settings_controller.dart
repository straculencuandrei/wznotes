import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  AppSettingsNotifier() : super(const AppSettingsState());

  void toggleBiometrics(bool enabled) {
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  void setPin(String newPin) {
    state = state.copyWith(appPin: newPin);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
  }

  void toggleSmoothCaret(bool enabled) {
    state = state.copyWith(smoothCaretEnabled: enabled);
  }

  void toggleWordCount(bool enabled) {
    state = state.copyWith(showWordCount: enabled);
  }
}

final settingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  return AppSettingsNotifier();
});
