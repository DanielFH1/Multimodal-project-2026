import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';

/// Represents the current state of the in-app update flow.
enum UpdateStatus {
  /// No update action is occurring.
  idle,

  /// An update is available but not yet downloaded.
  updateAvailable,

  /// The flexible update is downloading in the background.
  downloading,

  /// Download complete – ready to install.
  readyToInstall,
}

/// Holds the update state exposed to the UI.
class UpdateState {
  final UpdateStatus status;
  final AppUpdateInfo? updateInfo;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    AppUpdateInfo? updateInfo,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
    );
  }
}

/// Manages the entire in-app update lifecycle.
class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  /// Check whether a new version is available on Google Play.
  Future<void> checkForUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Only offer flexible (non-blocking) updates.
        if (info.flexibleUpdateAllowed) {
          state = UpdateState(
            status: UpdateStatus.updateAvailable,
            updateInfo: info,
          );
        }
      }
    } catch (e) {
      // In-app update API is not available (e.g., debug build, sideloaded).
      // Silently ignore — the user just won't see the banner.
      debugPrint('In-app update check failed: $e');
    }
  }

  /// Start a flexible (background) update download.
  Future<void> startFlexibleUpdate() async {
    try {
      state = state.copyWith(status: UpdateStatus.downloading);
      await InAppUpdate.startFlexibleUpdate();
      state = state.copyWith(status: UpdateStatus.readyToInstall);
    } catch (e) {
      debugPrint('Flexible update failed: $e');
      // Revert to available so the user can try again.
      state = state.copyWith(status: UpdateStatus.updateAvailable);
    }
  }

  /// Install a downloaded flexible update (restarts the app).
  Future<void> completeUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Complete update failed: $e');
    }
  }

  /// User dismissed the banner — stop showing it for this session.
  void dismiss() {
    state = const UpdateState(status: UpdateStatus.idle);
  }
}

/// Global provider for the update state.
final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
