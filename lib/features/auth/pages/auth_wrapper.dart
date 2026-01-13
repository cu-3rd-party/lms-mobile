import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:cumobile/features/home/pages/home_page.dart';
import 'package:cumobile/features/auth/pages/login_page.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/core/services/update_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  StreamSubscription<void>? _authSubscription;
  bool _updatePromptShown = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _checkForUpdates();
    _authSubscription = apiService.onAuthRequired.listen((_) {
      if (mounted) {
        setState(() => _isLoggedIn = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final cookie = await apiService.getCookie();
    setState(() {
      _isLoggedIn = cookie != null && cookie.isNotEmpty;
      _isLoading = false;
    });
  }

  void _checkForUpdates() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _updatePromptShown) return;
      final updateInfo = await updateService.checkForUpdate();
      if (!mounted || updateInfo == null) return;
      _updatePromptShown = true;
      await _showUpdateDialog(updateInfo);
    });
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    final isIos = Platform.isIOS;
    final downloadUrl = isIos ? info.release.ipaUrl : info.release.apkUrl;
    final fallbackUrl = info.release.pageUrl;

    Future<void> onUpdate() async {
      final target = downloadUrl ?? fallbackUrl;
      if (target == null) return;
      await launchUrl(target, mode: LaunchMode.externalApplication);
    }

    Future<void> onLater() async {
      await updateService.ignoreVersion(info.release.version);
    }

    final title = 'Доступна новая версия';
    final currentVersion = updateService.normalizeVersion(info.currentVersion);
    final latestVersion = updateService.normalizeVersion(info.release.version);
    final message = 'Ваша версия: $currentVersion\n'
        'Новая версия: $latestVersion';

    if (isIos) {
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () async {
                Navigator.of(context).pop();
                await onLater();
              },
              child: const Text('Позже'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                Navigator.of(context).pop();
                await onUpdate();
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await onLater();
            },
            child: const Text('Позже'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await onUpdate();
            },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  void _onLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    if (_isLoading) {
      final loader = Center(
        child: isIos
            ? const CupertinoActivityIndicator(
                radius: 14,
                color: Color(0xFF00E676),
              )
            : const CircularProgressIndicator(color: Color(0xFF00E676)),
      );
      return isIos
          ? CupertinoPageScaffold(
              child: SafeArea(
                bottom: false,
                child: loader,
              ),
            )
          : Scaffold(body: loader);
    }
    return _isLoggedIn
        ? HomePage(onLogout: _onLogout)
        : LoginPage(onLogin: _onLogin);
  }
}
