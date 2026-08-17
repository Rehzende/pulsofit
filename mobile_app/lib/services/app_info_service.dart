import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Service to get app version and other info
class AppInfoService {
  static String? _cachedVersion;
  static String? _cachedBuildNumber;

  /// Get current app version (e.g., "1.0.28")
  static Future<String> getVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;

    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = info.version;
      return info.version;
    } catch (e) {
      debugPrint('Error getting app version: $e');
      return 'Unknown';
    }
  }

  /// Get current build number (e.g., "33")
  static Future<String> getBuildNumber() async {
    if (_cachedBuildNumber != null) return _cachedBuildNumber!;

    try {
      final info = await PackageInfo.fromPlatform();
      _cachedBuildNumber = info.buildNumber;
      return info.buildNumber;
    } catch (e) {
      debugPrint('Error getting build number: $e');
      return 'Unknown';
    }
  }

  /// Get full version string (e.g., "1.0.28+33")
  static Future<String> getFullVersion() async {
    final version = await getVersion();
    final buildNumber = await getBuildNumber();
    return '$version+$buildNumber';
  }

  /// Get app name
  static Future<String> getAppName() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.appName;
    } catch (e) {
      debugPrint('Error getting app name: $e');
      return 'Pulso';
    }
  }

  /// Clear cache (useful for testing)
  static void clearCache() {
    _cachedVersion = null;
    _cachedBuildNumber = null;
  }
}
