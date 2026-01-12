import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/features/home/pages/home_page.dart';
import 'package:cumobile/features/auth/pages/login_page.dart';
import 'package:cumobile/data/services/api_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final cookie = await apiService.getCookie();
    setState(() {
      _isLoggedIn = cookie != null && cookie.isNotEmpty;
      _isLoading = false;
    });
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
