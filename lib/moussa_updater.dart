
library moussa_updater;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AndroidUpdateMode { immediate, flexible }
enum InstallerSource { playStore, sideload, other, unknown }

enum MoussaAction {
  upToDate,
  forceBlocked,
  updateStarted,
  openStore,
  notSupported,
  error,
}

class MoussaupdaterResult {
  final MoussaAction action;
  final String platform; // android | ios | web | windows | macos | linux | fuchsia ...
  final String currentVersion;
  final String minVersion;
  final String? storeUrl;
  final String? reason;
  final InstallerSource? installerSource;

  MoussaupdaterResult({
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

  factory MoussaupdaterResult.fromMap(Map<dynamic, dynamic> m) {
    return MoussaupdaterResult(
      action: _parseAction(m['action']?.toString()),
      platform: (m['platform'] ?? 'unknown').toString(),
      currentVersion: (m['currentVersion'] ?? '').toString(),
      minVersion: (m['minVersion'] ?? '').toString(),
      storeUrl: m['storeUrl']?.toString(),
      reason: m['reason']?.toString(),
      installerSource: _parseSource(m['installerSource']?.toString()),
    );
  }

  factory MoussaupdaterResult.notSupported({
    required String platform,
    String? reason,
  }) {
    return MoussaupdaterResult(
      action: MoussaAction.notSupported,
      platform: platform,
      currentVersion: '',
      minVersion: '',
      storeUrl: null,
      reason: reason ?? 'PLATFORM_NOT_SUPPORTED',
      installerSource: null,
    );
  }

  factory MoussaupdaterResult.error({
    required String platform,
    String? reason,
  }) {
    return MoussaupdaterResult(
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

class Moussaupdater {
  static const MethodChannel _m = MethodChannel('moussa_updater/methods');

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android/ios/windows/macos/linux/fuchsia
  }

  /// Force update gate based ONLY on minVersion.
  ///
  /// playOnly:
  /// - true: block any non-Play install (APK/sideload) regardless of version
  /// - false: block only if current < minVersion
  ///
  /// Android behavior when current < minVersion:
  /// - if installed from Play: auto-start in-app update (immediate/flexible)
  /// - else: FORCE_BLOCKED with storeUrl
  static Future<MoussaupdaterResult> checkAndMaybeUpdate({
    required String minVersion,
    required AndroidUpdateMode androidUpdateMode,
    required String androidPackageId,
    required String iosAppId,
    required bool playOnly,
  }) async {
    // ✅ No-op on web/desktop with safe result
    if (!_isMobile) {
      return MoussaupdaterResult.notSupported(
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

      return MoussaupdaterResult.fromMap(map ?? <dynamic, dynamic>{});
    } on MissingPluginException {
      // ✅ Prevent crash if native implementation missing
      return MoussaupdaterResult.notSupported(
        platform: _platformName,
        reason: 'MISSING_NATIVE_IMPLEMENTATION',
      );
    } catch (e) {
      return MoussaupdaterResult.error(
        platform: _platformName,
        reason: e.toString(),
      );
    }
  }

  /// Explicit store open (safe no-op on unsupported platforms)
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

  /// For Android flexible updates only (safe no-op on unsupported platforms)
  static Future<void> completeFlexibleUpdate() async {
    if (!_isMobile) return;

    try {
      await _m.invokeMethod('completeFlexibleUpdate');
    } catch (_) {
      // swallow to prevent crash
    }
  }
}
