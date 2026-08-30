import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../infrastructure/update/models/app_update_info.dart';
import '../../infrastructure/update/update_service.dart';

class UpdateState {
  final bool isChecking;
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;
  final bool isDismissed;
  final bool checkedOnce;

  const UpdateState({
    this.isChecking = false,
    this.updateInfo,
    this.errorMessage,
    this.isDismissed = false,
    this.checkedOnce = false,
  });

  bool get hasUpdate => updateInfo != null && !isDismissed;

  UpdateState copyWith({
    bool? isChecking,
    AppUpdateInfo? updateInfo,
    String? errorMessage,
    bool? isDismissed,
    bool? checkedOnce,
  }) {
    return UpdateState(
      isChecking: isChecking ?? this.isChecking,
      updateInfo: updateInfo ?? this.updateInfo,
      errorMessage: errorMessage,
      isDismissed: isDismissed ?? this.isDismissed,
      checkedOnce: checkedOnce ?? this.checkedOnce,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState()) {
    // Check silently in background on app start
    check(silent: true);
  }

  Future<void> check({bool silent = false, String? customUrl}) async {
    state = state.copyWith(isChecking: true, errorMessage: null);

    try {
      final info = await UpdateService.checkForUpdate(
        manifestUrl: customUrl ?? UpdateService.defaultManifestUrl,
      );

      state = state.copyWith(
        isChecking: false,
        updateInfo: info,
        checkedOnce: true,
        isDismissed: false,
      );
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: silent ? null : e.toString(),
        checkedOnce: true,
      );
    }
  }

  void dismiss() {
    state = state.copyWith(isDismissed: true);
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
