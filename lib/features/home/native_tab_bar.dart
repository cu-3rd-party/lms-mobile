import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/core/services/theme_service.dart';

class NativeTabBarItem {
  final String icon;
  final String selectedIcon;
  final String label;

  const NativeTabBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  Map<String, String> toMap() => {
        'icon': icon,
        'selectedIcon': selectedIcon,
        'label': label,
      };
}

class NativeTabBar {
  static final Logger _log = Logger('NativeTabBar');
  static const MethodChannel _channel = MethodChannel('dev.nejok.lms/tabbar');

  static const List<NativeTabBarItem> items = [
    NativeTabBarItem(icon: 'house', selectedIcon: 'house.fill', label: 'Главная'),
    NativeTabBarItem(
      icon: 'list.bullet.rectangle',
      selectedIcon: 'list.bullet.rectangle.fill',
      label: 'Задания',
    ),
    NativeTabBarItem(icon: 'book', selectedIcon: 'book.fill', label: 'Обучение'),
    NativeTabBarItem(icon: 'folder', selectedIcon: 'folder.fill', label: 'Файлы'),
  ];

  static ValueChanged<int>? _onSelected;

  static bool get isPlatformSupported => Platform.isIOS;

  static void setOnSelected(ValueChanged<int>? handler) {
    _onSelected = handler;
    _channel.setMethodCallHandler(handler == null ? null : _onNativeCall);
  }

  static Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'tabSelected') {
      _onSelected?.call(call.arguments as int);
    }
    return null;
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

  static Future<double?> attach({required int selected}) async {
    if (!isPlatformSupported) return null;
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>('attach', {
        'items': items.map((e) => e.toMap()).toList(),
        'selected': selected,
        'theme': _encodeTheme(ThemeController.instance.mode),
      });
      final height = response?['height'];
      return height is num ? height.toDouble() : null;
    } on PlatformException catch (e) {
      _log.warning('attach failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> setSelected(int index) => _invoke('setSelected', index);

  static Future<void> setVisible({required bool visible}) =>
      _invoke('setVisible', visible);

  static Future<void> syncTheme() =>
      _invoke('setTheme', _encodeTheme(ThemeController.instance.mode));

  static Future<void> detach() => _invoke('detach', null);

  static Future<void> _invoke(String method, dynamic arguments) async {
    if (!isPlatformSupported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (e) {
      _log.warning('$method failed: ${e.message}');
    } on MissingPluginException {
      return;
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
