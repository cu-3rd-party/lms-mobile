import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:cumobile/data/services/api_service.dart';
import 'package:cumobile/features/auth/pages/webview_login_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _cookieController = TextEditingController();
  bool _isLoading = false;
  String? _error;

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

  Future<void> _login() async {
    final cookie = _cookieController.text.trim();
    if (cookie.isEmpty) {
      setState(() => _error = 'Введите значение bff.cookie');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    await apiService.setCookie(cookie);
    final profile = await apiService.fetchProfile();

    if (profile != null) {
      widget.onLogin();
    } else {
      await apiService.clearCookie();
      setState(() {
        _isLoading = false;
        _error = 'Не удалось авторизоваться. Проверьте Cookie.';
      });
    }
  }

  @override
  void dispose() {
    _cookieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIos = Platform.isIOS;
    final content = SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CU Mobile',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E676),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Авторизация',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Text(
              'Вставьте значение bff.cookie с сайта my.centraluniversity.ru',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 12),
            isIos
                ? CupertinoTextField(
                    controller: _cookieController,
                    placeholder: 'Значение bff.cookie...',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    style: const TextStyle(fontSize: 14),
                    placeholderStyle: TextStyle(color: Colors.grey[600]),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                : TextField(
                    controller: _cookieController,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Значение bff.cookie...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00E676)),
                      ),
                    ),
                  ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: isIos
                  ? CupertinoButton.filled(
                      onPressed: _isLoading ? null : _login,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isLoading
                          ? const CupertinoActivityIndicator(
                              radius: 12,
                              color: CupertinoColors.black,
                            )
                          : const Text(
                              'Войти',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    )
                  : ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Войти',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[700])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'или',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            Text(
              'Или вставьте cookie вручную:\nDevTools (F12) → Application → Cookies → bff.cookie',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return isIos ? CupertinoPageScaffold(child: content) : Scaffold(body: content);
  }
}
