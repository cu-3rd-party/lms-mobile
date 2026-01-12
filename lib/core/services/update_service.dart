import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseInfo {
  final String version;
  final Uri? pageUrl;
  final Uri? apkUrl;
  final Uri? ipaUrl;

  const ReleaseInfo({
    required this.version,
    this.pageUrl,
    this.apkUrl,
    this.ipaUrl,
  });
}

class UpdateInfo {
  final String currentVersion;
  final ReleaseInfo release;

  const UpdateInfo({
    required this.currentVersion,
    required this.release,
  });
}

class UpdateService {
  static const String githubOwner = 'cu-3rd-party';
  static const String githubRepo = 'lms-mobile';
  static const String _ignoredVersionKey = 'ignored_release_version';
  static final Logger _log = Logger('UpdateService');

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await _getCurrentVersion();
      if (currentVersion == null) return null;
      final release = await _fetchLatestRelease();
      if (release == null) return null;

      final normalizedLatest = normalizeVersion(release.version);
      final normalizedCurrent = normalizeVersion(currentVersion);
      final isNewer =
          _compareVersions(normalizedLatest, normalizedCurrent) > 0;
      if (!isNewer) return null;

      final prefs = await SharedPreferences.getInstance();
      final ignored = prefs.getString(_ignoredVersionKey);
      if (ignored == normalizedLatest) return null;

      return UpdateInfo(currentVersion: currentVersion, release: release);
    } catch (e, st) {
      _log.warning('Error checking for updates', e, st);
      return null;
    }
  }

  Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, normalizeVersion(version));
  }

  Future<ReleaseInfo?> _fetchLatestRelease() async {
    final url = Uri.parse(
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest',
    );
    final response = await http.get(
      url,
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      _log.warning(
        'Failed to fetch latest release: ${response.statusCode}',
      );
      return null;
    }
    final Map<String, dynamic> data = jsonDecode(response.body);
    final tagName = data['tag_name'];
    if (tagName is! String || tagName.isEmpty) return null;

    final assets = data['assets'];
    Uri? apkUrl;
    Uri? ipaUrl;
    if (assets is List) {
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        final name = asset['name'];
        final download = asset['browser_download_url'];
        if (name is! String || download is! String) continue;
        final lower = name.toLowerCase();
        if (apkUrl == null && lower.endsWith('.apk')) {
          apkUrl = Uri.tryParse(download);
        } else if (ipaUrl == null && lower.endsWith('.ipa')) {
          ipaUrl = Uri.tryParse(download);
        }
      }
    }

    final htmlUrl = data['html_url'];
    return ReleaseInfo(
      version: tagName,
      pageUrl: htmlUrl is String ? Uri.tryParse(htmlUrl) : null,
      apkUrl: apkUrl,
      ipaUrl: ipaUrl,
    );
  }

  Future<String?> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } on MissingPluginException {
      _log.info('PackageInfo plugin not available; skip update check');
      return null;
    }
  }

  String normalizeVersion(String version) {
    var normalized = version.trim();
    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }
    final plusIndex = normalized.indexOf('+');
    if (plusIndex != -1) {
      normalized = normalized.substring(0, plusIndex);
    }
    return normalized;
  }

  int _compareVersions(String a, String b) {
    final aParts = a.split('.');
    final bParts = b.split('.');
    final maxLen = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < maxLen; i++) {
      final aPart = i < aParts.length ? int.tryParse(aParts[i]) ?? 0 : 0;
      final bPart = i < bParts.length ? int.tryParse(bParts[i]) ?? 0 : 0;
      if (aPart != bPart) {
        return aPart.compareTo(bPart);
      }
    }
    return 0;
  }
}

final UpdateService updateService = UpdateService();
