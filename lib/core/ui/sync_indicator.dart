import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/theme/app_colors.dart';

class SyncIndicator extends StatelessWidget {
  final bool visible;
  final double size;

  const SyncIndicator({super.key, required this.visible, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: SizedBox(
          width: size,
          height: size,
          child: visible
              ? (Platform.isIOS
                  ? CupertinoActivityIndicator(radius: size / 2, color: c.textTertiary)
                  : CircularProgressIndicator(strokeWidth: 2, color: c.textTertiary))
              : null,
        ),
      ),
    );
  }
}

mixin SyncTracker<T extends StatefulWidget> on State<T> {
  int _syncCount = 0;

  bool get isSyncing => _syncCount > 0;

  Future<R> trackSync<R>(Future<R> future) async {
    if (mounted) setState(() => _syncCount++);
    try {
      return await future;
    } finally {
      if (mounted) {
        setState(() => _syncCount--);
      } else {
        _syncCount--;
      }
    }
  }
}
