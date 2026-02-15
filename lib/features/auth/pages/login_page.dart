import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cumobile/features/auth/pages/webview_login_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  void _openWebViewLogin() {
    Navigator.of(context).push(
      Platform.isIOS
          ? CupertinoPageRoute(
              builder: (_) => WebViewLoginPage(onLogin: widget.onLogin),
            )
          : MaterialPageRoute(
              builder: (_) => WebViewLoginPage(onLogin: widget.onLogin),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: SvgPicture.asset(
                        'assets/icons/cuIconLogo.svg',
                        height: 96,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Авторизация',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[400],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Авторизуйтесь через браузер, мы сохраним сессию автоматически.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildSteps(isIos),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: isIos
                          ? CupertinoButton(
                              onPressed: _openWebViewLogin,
                              color: const Color(0xFF2D2D2D),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: const Text(
                                'Войти через браузер',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: _openWebViewLogin,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00E676)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Войти через браузер',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF00E676),
                                ),
                                ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Версия $_appVersion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    return isIos ? CupertinoPageScaffold(child: content) : Scaffold(body: content);
  }

  Widget _buildSteps(bool isIos) {
    final steps = [
      'Нажмите «Войти через браузер».',
      'Войдите в LMS в открывшемся окне.',
      'После входа вернёмся в приложение сами.',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIos ? CupertinoIcons.info : Icons.info_outline,
                size: 16,
                color: const Color(0xFF00E676),
              ),
              const SizedBox(width: 6),
              const Text(
                'Как войти',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${entry.key + 1}. ${entry.value}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
