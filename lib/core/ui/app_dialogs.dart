import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:cumobile/core/services/theme_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';

enum AppDialogActionStyle { normal, cancel, destructive }

class AppDialogAction {
  final String title;
  final AppDialogActionStyle style;

  const AppDialogAction(
    this.title, {
    this.style = AppDialogActionStyle.normal,
  });

  Map<String, String> toMap() => {
        'title': title,
        'style': switch (style) {
          AppDialogActionStyle.cancel => 'cancel',
          AppDialogActionStyle.destructive => 'destructive',
          AppDialogActionStyle.normal => 'default',
        },
      };
}

class AppDialogs {
  static final Logger _log = Logger('AppDialogs');
  static const MethodChannel _channel = MethodChannel('dev.nejok.lms/ui');

  static bool? _supported;

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    if (_supported != null) return _supported!;
    try {
      _supported = await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException catch (e) {
      _log.warning('isSupported failed: ${e.message}');
      _supported = false;
    } on MissingPluginException {
      _supported = false;
    }
    return _supported!;
  }

  static Future<int?> _nativeActions(
    String method, {
    String? title,
    String? message,
    required List<AppDialogAction> actions,
  }) async {
    try {
      return await _channel.invokeMethod<int>(method, {
        'title': title,
        'message': message,
        'actions': actions.map((e) => e.toMap()).toList(),
      });
    } on PlatformException catch (e) {
      _log.warning('$method failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> message(
    BuildContext context, {
    String? title,
    required String message,
    String okLabel = 'OK',
  }) async {
    if (await isSupported()) {
      await _nativeActions(
        'alert',
        title: title,
        message: message,
        actions: [AppDialogAction(okLabel, style: AppDialogActionStyle.cancel)],
      );
      return;
    }
    if (!context.mounted) return;
    await _fallbackAlert(
      context,
      title: title,
      message: message,
      actions: [AppDialogAction(okLabel, style: AppDialogActionStyle.cancel)],
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    String? title,
    String? message,
    required String confirmLabel,
    String cancelLabel = 'Отмена',
    bool destructive = false,
  }) async {
    final actions = [
      AppDialogAction(cancelLabel, style: AppDialogActionStyle.cancel),
      AppDialogAction(
        confirmLabel,
        style: destructive
            ? AppDialogActionStyle.destructive
            : AppDialogActionStyle.normal,
      ),
    ];

    if (await isSupported()) {
      final index = await _nativeActions(
        'alert',
        title: title,
        message: message,
        actions: actions,
      );
      return index == 1;
    }
    if (!context.mounted) return false;
    final index = await _fallbackAlert(
      context,
      title: title,
      message: message,
      actions: actions,
    );
    return index == 1;
  }

  static Future<int?> actionSheet(
    BuildContext context, {
    String? title,
    String? message,
    required List<AppDialogAction> actions,
  }) async {
    if (await isSupported()) {
      return _nativeActions(
        'actionSheet',
        title: title,
        message: message,
        actions: actions,
      );
    }
    if (!context.mounted) return null;
    return _fallbackActionSheet(
      context,
      title: title,
      message: message,
      actions: actions,
    );
  }

  static Future<String?> prompt(
    BuildContext context, {
    String? title,
    String? message,
    String? value,
    String? placeholder,
    String confirmLabel = 'Готово',
    String cancelLabel = 'Отмена',
  }) async {
    if (await isSupported()) {
      try {
        return await _channel.invokeMethod<String>('prompt', {
          'title': title,
          'message': message,
          'value': value,
          'placeholder': placeholder,
          'confirmTitle': confirmLabel,
          'cancelTitle': cancelLabel,
        });
      } on PlatformException catch (e) {
        _log.warning('prompt failed: ${e.message}');
        return null;
      } on MissingPluginException {
        return null;
      }
    }
    if (!context.mounted) return null;
    return _fallbackPrompt(
      context,
      title: title,
      message: message,
      value: value,
      placeholder: placeholder,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    );
  }

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initial,
    DateTime? minimum,
    DateTime? maximum,
    String title = 'Выберите дату',
  }) async {
    if (await isSupported()) {
      try {
        final millis = await _channel.invokeMethod<int>('datePicker', {
          'initial': initial.millisecondsSinceEpoch,
          'minimum': minimum?.millisecondsSinceEpoch,
          'maximum': maximum?.millisecondsSinceEpoch,
          'title': title,
          'theme': _encodeTheme(ThemeController.instance.mode),
        });
        return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
      } on PlatformException catch (e) {
        _log.warning('datePicker failed: ${e.message}');
        return null;
      } on MissingPluginException {
        return null;
      }
    }
    if (!context.mounted) return null;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minimum ?? DateTime(2000),
      lastDate: maximum ?? DateTime(2100),
    );
  }

  static Future<int?> _fallbackAlert(
    BuildContext context, {
    String? title,
    String? message,
    required List<AppDialogAction> actions,
  }) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);

    if (isIos) {
      return showCupertinoDialog<int>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: title == null ? null : Text(title),
          content: message == null ? null : Text(message),
          actions: [
            for (var i = 0; i < actions.length; i++)
              CupertinoDialogAction(
                isDestructiveAction:
                    actions[i].style == AppDialogActionStyle.destructive,
                isDefaultAction: actions[i].style == AppDialogActionStyle.cancel,
                onPressed: () => Navigator.of(ctx).pop(i),
                child: Text(actions[i].title),
              ),
          ],
        ),
      );
    }

    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: title == null ? null : Text(title, style: TextStyle(color: c.textPrimary)),
        content: message == null ? null : Text(message, style: TextStyle(color: c.textPrimary)),
        actions: [
          for (var i = 0; i < actions.length; i++)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(i),
              child: Text(
                actions[i].title,
                style: TextStyle(
                  color: actions[i].style == AppDialogActionStyle.destructive
                      ? c.danger
                      : c.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Future<int?> _fallbackActionSheet(
    BuildContext context, {
    String? title,
    String? message,
    required List<AppDialogAction> actions,
  }) {
    final c = AppColors.of(context);
    final cancelIndex =
        actions.indexWhere((a) => a.style == AppDialogActionStyle.cancel);

    if (Platform.isIOS) {
      return showCupertinoModalPopup<int>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: title == null ? null : Text(title),
          message: message == null ? null : Text(message),
          actions: [
            for (var i = 0; i < actions.length; i++)
              if (i != cancelIndex)
                CupertinoActionSheetAction(
                  isDestructiveAction:
                      actions[i].style == AppDialogActionStyle.destructive,
                  onPressed: () => Navigator.of(ctx).pop(i),
                  child: Text(actions[i].title),
                ),
          ],
          cancelButton: cancelIndex < 0
              ? null
              : CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(ctx).pop(cancelIndex),
                  child: Text(actions[cancelIndex].title),
                ),
        ),
      );
    }

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
              ),
            for (var i = 0; i < actions.length; i++)
              ListTile(
                title: Text(
                  actions[i].title,
                  style: TextStyle(
                    color: actions[i].style == AppDialogActionStyle.destructive
                        ? c.danger
                        : c.textPrimary,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _fallbackPrompt(
    BuildContext context, {
    String? title,
    String? message,
    String? value,
    String? placeholder,
    required String confirmLabel,
    required String cancelLabel,
  }) {
    final controller = TextEditingController(text: value);
    final c = AppColors.of(context);

    if (Platform.isIOS) {
      return showCupertinoDialog<String>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: title == null ? null : Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(confirmLabel),
            ),
          ],
        ),
      );
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: title == null ? null : Text(title, style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: placeholder),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
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
