import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cumobile/core/services/analytics_service.dart';
import 'package:cumobile/core/services/theme_service.dart';
import 'package:cumobile/data/services/api_service.dart';

enum NativeAuthStatus { cookie, demo, cancelled, unsupported }

class NativeAuthResult {
  final NativeAuthStatus status;

  const NativeAuthResult(this.status);
}

class NativeAuth {
  static final Logger _log = Logger('NativeAuth');
  static const MethodChannel _channel = MethodChannel('dev.nejok.lms/auth');

  static bool _handlerBound = false;

  static bool get isPlatformSupported => Platform.isIOS;

  static void bindHandlers() {
    if (_handlerBound || !isPlatformSupported) return;
    _handlerBound = true;
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'verifyCookie':
        return _verifyCookie(call.arguments as String);
      case 'analytics':
        _reportEvent(call.arguments as String);
        return null;
      default:
        return null;
    }
  }

  static Future<bool> _verifyCookie(String cookie) async {
    _log.info('Verifying cookie from native auth');
    await apiService.setCookie(cookie);
    final profile = await apiService.fetchProfile();
    if (profile != null) {
      _log.info('Native auth successful for: ${profile.fullName}');
      Analytics.authLoginSuccess();
      return true;
    }
    _log.warning('Cookie from native auth failed profile check');
    await apiService.clearCookie();
    return false;
  }

  static void _reportEvent(String event) {
    switch (event) {
      case 'auth.login.buttonPressed':
        Analytics.authLoginButtonPressed();
        break;
      case 'auth.demo.buttonPressed':
        Analytics.authDemoButtonPressed();
        break;
    }
  }

  static Future<bool> isSupported() async {
    if (!isPlatformSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      _log.warning('isSupported failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<NativeAuthResult> present() async {
    if (!isPlatformSupported) {
      return const NativeAuthResult(NativeAuthStatus.unsupported);
    }
    bindHandlers();

    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'present',
        {'theme': _encodeTheme(ThemeController.instance.mode), 'version': version},
      );
      return NativeAuthResult(_decodeStatus(response?['status'] as String?));
    } on PlatformException catch (e) {
      _log.warning('Native auth present failed: ${e.message}');
      return const NativeAuthResult(NativeAuthStatus.unsupported);
    } on MissingPluginException {
      return const NativeAuthResult(NativeAuthStatus.unsupported);
    }
  }

  static NativeAuthStatus _decodeStatus(String? value) {
    switch (value) {
      case 'cookie':
        return NativeAuthStatus.cookie;
      case 'demo':
        return NativeAuthStatus.demo;
      case 'cancelled':
        return NativeAuthStatus.cancelled;
      default:
        return NativeAuthStatus.unsupported;
    }
  }

  static String _encodeTheme(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
