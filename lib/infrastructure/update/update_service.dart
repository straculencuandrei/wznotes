import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/app_update_info.dart';

class UpdateService {
  static const String currentVersion = '0.7.3';
  static const int currentBuildNumber = 10;

  // Default manifest URL (can be customized by user or configured via repository)
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/straculencuandrei/wznotes/main/version_manifest.json';

  /// Compares semantic versions (e.g. 0.8.0 vs 0.7.0) and build numbers
  static bool isNewerVersion({
    required String remoteVersion,
    required int remoteBuildNumber,
    String localVersion = currentVersion,
    int localBuildNumber = currentBuildNumber,
  }) {
    if (remoteBuildNumber > localBuildNumber) return true;

    final remoteParts = remoteVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localParts = localVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    return false;
  }

  /// Checks the remote manifest for available updates
  static Future<AppUpdateInfo?> checkForUpdate({
    String manifestUrl = defaultManifestUrl,
  }) async {
    try {
      final uri = Uri.parse(manifestUrl);
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




