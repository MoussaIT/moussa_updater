library moussa_updater;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android in-app update behavior.
enum AndroidUpdateMode {
  /// Blocking update flow (immediate).
  immediate,

  /// Background download then install (flexible).
  flexible,
}

/// Where the app was installed from (Android only).
enum InstallerSource {
  /// Installed from Google Play Store.
  playStore,

  /// Installed via APK / sideload.
  sideload,

  /// Installed from another source/store.
  other,

  /// Could not be determined.
  unknown,
}

/// Possible outcomes of update checking.
enum MoussaAction {
  /// App version is acceptable.
  upToDate,

  /// App must be updated before continuing.
  forceBlocked,

  /// Android in-app update flow started successfully.
  updateStarted,

  /// Should open store page (fallback).
  openStore,

  /// Platform is not supported (Web/Desktop).
  notSupported,

  /// Unexpected error happened.
  error,
}

/// Default dialog texts (can be overridden by the caller).
class MoussaDialogTexts {
  /// Dialog title.
  final String title;

  /// Dialog message.
  final String message;

  /// Update button label.
  final String updateButton;

  const MoussaDialogTexts({
    this.title = 'Update Required',
    this.message = 'Please update the app to continue using it.',
    this.updateButton = 'Update',
  });
}

/// Result object returned by the plugin.
class MoussaUpdaterResult {
  /// Action describing what should happen next.
  final MoussaAction action;

  /// Platform name: android | ios | web | windows | macos | linux | fuchsia ...
  final String platform;

  /// Current installed version (as returned by native).
  final String currentVersion;

  /// Minimum required version.
  final String minVersion;

  /// Store URL (optional, provided by native when available).
  final String? storeUrl;

  /// Error or reasoning code (optional).
  final String? reason;

  /// Installer source (Android only, optional).
  final InstallerSource? installerSource;

  const MoussaUpdaterResult({
    required this.action,
    required this.platform,
    required this.currentVersion,
    required this.minVersion,
    this.storeUrl,
    this.reason,
    this.installerSource,
  });

  static MoussaAction _parseAction(String? s) {
    switch (s) {
      case 'UP_TO_DATE':
        return MoussaAction.upToDate;
      case 'FORCE_BLOCKED':
        return MoussaAction.forceBlocked;
      case 'UPDATE_STARTED':
        return MoussaAction.updateStarted;
      case 'OPEN_STORE':
        return MoussaAction.openStore;
      case 'NOT_SUPPORTED':
        return MoussaAction.notSupported;
      default:
        return MoussaAction.error;
    }
  }

  static InstallerSource? _parseSource(String? s) {
    switch (s) {
      case 'play_store':
        return InstallerSource.playStore;
      case 'sideload':
        return InstallerSource.sideload;
      case 'other':
        return InstallerSource.other;
      case 'unknown':
        return InstallerSource.unknown;
      default:
        return null;
    }
  }

  /// Build a result from native returned map.
  factory MoussaUpdaterResult.fromMap(Map<dynamic, dynamic> m) {
    return MoussaUpdaterResult(
      action: _parseAction(m['action']?.toString()),
      platform: (m['platform'] ?? 'unknown').toString(),
      currentVersion: (m['currentVersion'] ?? '').toString(),
      minVersion: (m['minVersion'] ?? '').toString(),
      storeUrl: m['storeUrl']?.toString(),
      reason: m['reason']?.toString(),
      installerSource: _parseSource(m['installerSource']?.toString()),
    );
  }

  /// Safe not-supported result for non-mobile platforms.
  factory MoussaUpdaterResult.notSupported({
    required String platform,
    String? reason,
  }) {
    return MoussaUpdaterResult(
      action: MoussaAction.notSupported,
      platform: platform,
      currentVersion: '',
      minVersion: '',
      storeUrl: null,
      reason: reason ?? 'PLATFORM_NOT_SUPPORTED',
      installerSource: null,
    );
  }

  /// Safe error result (prevents crashes).
  factory MoussaUpdaterResult.error({
    required String platform,
    String? reason,
  }) {
    return MoussaUpdaterResult(
      action: MoussaAction.error,
      platform: platform,
      currentVersion: '',
      minVersion: '',
      storeUrl: null,
      reason: reason ?? 'UNKNOWN_ERROR',
      installerSource: null,
    );
  }
}

/// Main API class.
class MoussaUpdater {
  static const MethodChannel _m = MethodChannel('moussa_updater/methods');

  static bool _dialogShown = false;

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform
        .name; // android/ios/windows/macos/linux/fuchsia
  }

  /// Checks the current app version against [minVersion] and enforces update when needed.
  ///
  /// - [playOnly] (Android):
  ///   - true: blocks any non-Play install (APK/sideload) regardless of version.
  ///   - false: blocks only if current < minVersion.
  ///
  /// Android behavior when current < minVersion:
  /// - if installed from Play: auto-start in-app update (immediate/flexible).
  /// - else: returns FORCE_BLOCKED / OPEN_STORE.
  ///
  /// UI behavior:
  /// - If [autoDialog] is true (default) and [context] is provided,
  ///   a blocking dialog is shown automatically for FORCE_BLOCKED / OPEN_STORE.
  /// - If [autoDialog] is false, the caller fully controls navigation/UI.
  static Future<MoussaUpdaterResult> checkAndMaybeUpdate({
    required String minVersion,
    required AndroidUpdateMode androidUpdateMode,
    required String androidPackageId,
    required String iosAppId,
    bool playOnly = false,

    /// If true, show a blocking dialog automatically (when possible).
    bool autoDialog = true,

    /// Required for autoDialog to show UI. If null, returns result without UI.
    BuildContext? context,

    /// Customize default dialog texts.
    MoussaDialogTexts dialogTexts = const MoussaDialogTexts(),
  }) async {
    // ✅ No-op on web/desktop with safe result
    if (!_isMobile) {
      return MoussaUpdaterResult.notSupported(
        platform: _platformName,
        reason: 'SUPPORTED_ONLY_ON_ANDROID_IOS',
      );
    }

    try {
      final map = await _m.invokeMapMethod<dynamic, dynamic>(
        'checkAndMaybeUpdate',
        {
          'minVersion': minVersion,
          'androidUpdateMode': androidUpdateMode.name, // immediate|flexible
          'androidPackageId': androidPackageId,
          'iosAppId': iosAppId,
          'playOnly': playOnly,
        },
      );

      final result = MoussaUpdaterResult.fromMap(map ?? <dynamic, dynamic>{});

      // ✅ If Android started native update UI, do nothing else.
      if (result.action == MoussaAction.updateStarted) {
        return result;
      }

      // ✅ Auto dialog (default) for force block / open store, only if context exists.
      if (autoDialog &&
          context != null &&
          !_dialogShown &&
          (result.action == MoussaAction.forceBlocked ||
              result.action == MoussaAction.openStore)) {
        // ✅ Don't use context if widget got disposed while awaiting native call.
        if (!context.mounted) return result;

        _dialogShown = true;
        await _showBlockingUpdateDialog(
          context: context,
          texts: dialogTexts,
          onUpdate: () async {
            await openStore(
              androidPackageId: androidPackageId,
              iosAppId: iosAppId,
            );
          },
        );
      }

      return result;
    } on MissingPluginException {
      // ✅ Prevent crash if native implementation missing
      return MoussaUpdaterResult.notSupported(
        platform: _platformName,
        reason: 'MISSING_NATIVE_IMPLEMENTATION',
      );
    } catch (e) {
      return MoussaUpdaterResult.error(
        platform: _platformName,
        reason: e.toString(),
      );
    }
  }

  static Future<void> _showBlockingUpdateDialog({
    required BuildContext context,
    required MoussaDialogTexts texts,
    required Future<void> Function() onUpdate,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(texts.title),
            content: Text(texts.message),
            actions: [
              TextButton(
                onPressed: () async {
                  await onUpdate();
                },
                child: Text(texts.updateButton),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens store page (safe no-op on unsupported platforms).
  static Future<void> openStore({
    required String androidPackageId,
    required String iosAppId,
  }) async {
    if (!_isMobile) return;

    try {
      await _m.invokeMethod('openStore', {
        'androidPackageId': androidPackageId,
        'iosAppId': iosAppId,
      });
    } catch (_) {
      // swallow to prevent crash
    }
  }

  /// Completes Android flexible update if downloaded (safe no-op on unsupported platforms).
  static Future<void> completeFlexibleUpdate() async {
    if (!_isMobile) return;

    try {
      await _m.invokeMethod('completeFlexibleUpdate');
    } catch (_) {
      // swallow to prevent crash
    }
  }
}

/* -------------------------------------------------------------------------- */
/* Backward compatibility (to avoid breaking existing users in v1.x)           */
/* -------------------------------------------------------------------------- */

@Deprecated('Use MoussaUpdaterResult instead.')
typedef MoussaupdaterResult = MoussaUpdaterResult;

@Deprecated('Use MoussaUpdater instead.')
class Moussaupdater {
  /// Backward compatible wrapper.
  static Future<MoussaUpdaterResult> checkAndMaybeUpdate({
    required String minVersion,
    required AndroidUpdateMode androidUpdateMode,
    required String androidPackageId,
    required String iosAppId,
    required bool playOnly,
    bool autoDialog = true,
    BuildContext? context,
    MoussaDialogTexts dialogTexts = const MoussaDialogTexts(),
  }) {
    return MoussaUpdater.checkAndMaybeUpdate(
      minVersion: minVersion,
      androidUpdateMode: androidUpdateMode,
      androidPackageId: androidPackageId,
      iosAppId: iosAppId,
      playOnly: playOnly,
      autoDialog: autoDialog,
      context: context,
      dialogTexts: dialogTexts,
    );
  }

  static Future<void> openStore({
    required String androidPackageId,
    required String iosAppId,
  }) =>
      MoussaUpdater.openStore(
        androidPackageId: androidPackageId,
        iosAppId: iosAppId,
      );

  static Future<void> completeFlexibleUpdate() =>
      MoussaUpdater.completeFlexibleUpdate();
}
