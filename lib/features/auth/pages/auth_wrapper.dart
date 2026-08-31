import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/core/services/demo_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/auth/native_auth.dart';
import 'package:cumobile/features/auth/pages/login_page.dart';
import 'package:cumobile/features/home/pages/home_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _nativeSupported = false;
  bool _nativeUnavailable = false;
  bool _nativeActive = false;
  StreamSubscription<void>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _authSubscription = apiService.onAuthRequired.listen((_) {
      if (mounted) {
        setState(() => _isLoggedIn = false);
        _scheduleNativeLogin();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    if (demoService.isDemoMode) {
      setState(() {
        _isLoggedIn = true;
        _isLoading = false;
      });
      return;
    }

    _nativeSupported = await NativeAuth.isSupported();
    if (_nativeSupported) NativeAuth.bindHandlers();

    final cookie = await apiService.getCookie();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = cookie != null && cookie.isNotEmpty;
      _isLoading = false;
    });
    _scheduleNativeLogin();
  }

  void _scheduleNativeLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentNativeLogin());
  }

  Future<void> _presentNativeLogin() async {
    if (!_nativeSupported || _nativeUnavailable) return;
    if (_isLoading || _isLoggedIn || _nativeActive) return;

    _nativeActive = true;
    final result = await NativeAuth.present();
    _nativeActive = false;
    if (!mounted) return;

    switch (result.status) {
      case NativeAuthStatus.cookie:
        _onLogin();
        break;
      case NativeAuthStatus.demo:
        demoService.enableDemo();
        _onLogin();
        break;
      case NativeAuthStatus.cancelled:
        break;
      case NativeAuthStatus.unsupported:
        setState(() => _nativeUnavailable = true);
        break;
    }
  }

  void _onLogin() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() {
    demoService.exitDemo();
    setState(() {
      _isLoggedIn = false;
    });
    _scheduleNativeLogin();
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

    if (_isLoggedIn) {
      return HomePage(onLogout: _onLogout);
    }

    if (_nativeSupported && !_nativeUnavailable) {
      final background = AppColors.of(context).background;
      return isIos
          ? CupertinoPageScaffold(
              backgroundColor: background,
              child: const SizedBox.expand(),
            )
          : Scaffold(
              backgroundColor: background,
              body: const SizedBox.expand(),
            );
    }

    return LoginPage(onLogin: _onLogin);
  }
}
