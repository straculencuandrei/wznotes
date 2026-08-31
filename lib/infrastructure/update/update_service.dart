import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'models/app_update_info.dart';

class UpdateService {
  static const String defaultFallbackVersion = '0.7.8';
  static const int defaultFallbackBuildNumber = 15;

  static String _currentVersion = defaultFallbackVersion;
  static int _currentBuildNumber = defaultFallbackBuildNumber;

  static String get currentVersion => _currentVersion;
  static int get currentBuildNumber => _currentBuildNumber;

  /// Loads true version and build number from platform package info at runtime
  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) {
        _currentVersion = info.version;
      }
      if (info.buildNumber.isNotEmpty) {
        _currentBuildNumber = int.tryParse(info.buildNumber) ?? _currentBuildNumber;
      }
      debugPrint('[UpdateService] Initialized runtime version: v$_currentVersion+$_currentBuildNumber');
    } catch (e) {
      debugPrint('[UpdateService] Failed to read platform package info: $e');
    }
  }

  // Default manifest URL (can be customized by user or configured via repository)
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/straculencuandrei/wznotes/main/version_manifest.json';

  /// Compares semantic versions (e.g. 0.8.0 vs 0.7.0) and build numbers
  static bool isNewerVersion({
    required String remoteVersion,
    required int remoteBuildNumber,
    String? localVersion,
    int? localBuildNumber,
  }) {
    final effectiveLocalVersion = localVersion ?? currentVersion;
    final effectiveLocalBuild = localBuildNumber ?? currentBuildNumber;

    // 1. Compare semantic version components (major.minor.patch)
    final remoteParts = remoteVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = effectiveLocalVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    // 2. If semantic versions are identical (e.g. 0.7.8 vs 0.7.8), check build number
    return remoteBuildNumber > effectiveLocalBuild;
  }

  /// Checks the remote manifest for available updates
  static Future<AppUpdateInfo?> checkForUpdate({
    String manifestUrl = defaultManifestUrl,
  }) async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final separator = manifestUrl.contains('?') ? '&' : '?';
      final uri = Uri.parse('$manifestUrl${separator}_cb=$cacheBuster');
      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonMap = json.decode(response.body) as Map<String, dynamic>;
        final updateInfo = AppUpdateInfo.fromJson(jsonMap);

        if (isNewerVersion(
          remoteVersion: updateInfo.version,
          remoteBuildNumber: updateInfo.buildNumber,
        )) {
          return updateInfo;
        }
        return null;
      } else {
        debugPrint('[UpdateService] Failed to load manifest: HTTP ${response.statusCode}');
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[UpdateService] Update check error: $e');
      rethrow;
    }
  }
}














