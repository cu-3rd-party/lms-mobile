import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cumobile/core/services/demo_service.dart';
import 'package:cumobile/core/theme/app_colors.dart';
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

  void _startDemo() {
    demoService.enableDemo();
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final c = AppColors.of(context);
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
                        'assets/icons/logo.svg',
                        height: 96,
                        colorFilter: c.brightness == Brightness.light
                            ? ColorFilter.mode(c.textPrimary, BlendMode.srcIn)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Авторизация',
                      style: TextStyle(
                        fontSize: 18,
                        color: c.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Авторизуйтесь через браузер, мы сохраним сессию автоматически.',
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textTertiary,
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
                              color: c.surfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Войти через браузер',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                            )
                          : OutlinedButton(
                              onPressed: _openWebViewLogin,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: c.accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Войти через браузер',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: c.accent,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: isIos
                          ? CupertinoButton(
                              onPressed: _startDemo,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Попробовать без входа',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: c.textTertiary,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: _startDemo,
                              child: Text(
                                'Попробовать без входа',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: c.textTertiary,
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
                color: c.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    return isIos
        ? CupertinoPageScaffold(backgroundColor: c.background, child: content)
        : Scaffold(backgroundColor: c.background, body: content);
  }

  Widget _buildSteps(bool isIos) {
    final c = AppColors.of(context);
    final steps = [
      'Нажмите «Войти через браузер».',
      'Войдите в LMS в открывшемся окне.',
      'После входа вернёмся в приложение сами.',
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
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
                color: c.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Как войти',
                style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${entry.key + 1}. ${entry.value}',
                    style: TextStyle(color: c.textSecondary, fontSize: 13),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
